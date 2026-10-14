extends Node

## GameState - Estado persistente de Faunetra.
## - Economía local: los Puntos de Restauración (PR) se guardan y gastan por bioma.
## - Modo de juego (Explorador / Guardaparques / Científico) que fija la presión del refugio
##   y el punto de partida del DDA de trivias (ver MODOS y ajuste()).
## - Salud 0-100% por bioma y desbloqueo secuencial al superar umbral_desbloqueo().
## - Estado de la grilla de cada refugio (niebla, bloqueadores, plantas, fauna presente).
## - Biopedia (especies descubiertas) y validaciones de repetición espaciada (24 h, 3 y 7 días).
## - Degradación por abandono calculada con timestamps entre sesiones.

signal pr_actualizado(id_bioma: int, nuevo_total: int)
signal salud_actualizada(id_bioma: int, salud: float)
signal bioma_desbloqueado(id_bioma: int)
signal herramienta_cambiada(herramienta: String)
signal especie_descubierta(data: EspecieData)
signal repasos_actualizados
signal modo_cambiado(id_modo: String)

const RUTA_GUARDADO := "user://faunetra_guardado.json"
const RUTA_RESPALDO := "user://faunetra_guardado.json.bak"
const VERSION_GUARDADO := 1
## Orden de desbloqueo. El prototipo comienza en el Bosque Templado (id 3), que tiene todas
## sus especies animadas; luego sigue de norte a sur y finalmente las islas.
const ORDEN_BIOMAS: Array[int] = [3, 2, 1, 4, 5]
const NOMBRES_BIOMAS := {
	1: "Zona Central Mediterránea",
	2: "Norte Árido",
	3: "Bosques Templados del Sur",
	4: "Patagonia",
	5: "Territorios Insulares",
}
const SEGUNDOS_DIA := 86400
const MAX_SEVERIDAD := 7
const INTERVALOS_REPASO_DIAS: Array[int] = [1, 3, 7]
## Repaso rápido en la misma sesión, unos minutos después del descubrimiento: el espaciado
## funciona mejor si antes hubo alguna recuperación temprana. No cuenta como validación.
const SEGUNDOS_REPASO_RAPIDO := 240.0
const INTERVALO_REVISION_REPASOS := 10.0
const SEGUNDOS_ENTRE_GUARDADOS := 3.0

# Pesos del indicador de salud (suman 100).
const PESO_DESPEJE := 30.0
const PESO_LIMPIEZA := 20.0
const PESO_FLORA := 30.0
const PESO_FAUNA := 20.0

## Modos de juego. El modo fija la presión de gestión del refugio y desde dónde parte el DDA;
## la dificultad del contenido la sigue ajustando TriviaManager según el desempeño.
## - pr_inicial: PR con que comienza cada bioma.
## - costo_mult: multiplica los costos en PR del terreno (niebla, limpiar, plantar, sanar).
## - tiempo_crecimiento: segundos para que una planta madure sin bonificaciones.
## - umbral_desbloqueo: salud (%) que abre el siguiente bioma.
## - dias_gracia: días sin jugar tolerados antes de degradarse; severidad_mult escala la degradación.
## - nivel_inicial_dda: 0 Fácil, 1 Medio, 2 Difícil. racha_para_subir: aciertos seguidos para subir.
## - distractores: opciones incorrectas en las preguntas generadas desde las fichas.
## - pista_inmediata: la pista se muestra siempre. pr_con_pista: factor de PR si se pidió la pista.
const MODO_POR_DEFECTO := "guardaparques"
const MODOS := {
	"explorador": {
		"nombre": "Explorador", "icono": "brujula",
		"descripcion": "Para conocer Chile con calma: más PR, costos bajos, plantas que crecen rápido y pistas siempre visibles.",
		"pr_inicial": 200, "costo_mult": 0.75, "tiempo_crecimiento": 30.0, "umbral_desbloqueo": 65.0,
		"dias_gracia": 3, "severidad_mult": 0.5,
		"nivel_inicial_dda": 0, "racha_para_subir": 3, "distractores": 2,
		"pista_inmediata": true, "pr_con_pista": 1.0,
	},
	"guardaparques": {
		"nombre": "Guardaparques", "icono": "hoja",
		"descripcion": "La experiencia equilibrada: el refugio exige cuidado constante y las trivias se adaptan a ti.",
		"pr_inicial": 150, "costo_mult": 1.0, "tiempo_crecimiento": 40.0, "umbral_desbloqueo": 75.0,
		"dias_gracia": 1, "severidad_mult": 1.0,
		"nivel_inicial_dda": 0, "racha_para_subir": 2, "distractores": 2,
		"pista_inmediata": false, "pr_con_pista": 1.0,
	},
	"cientifico": {
		"nombre": "Científico", "icono": "libro",
		"descripcion": "Para expertos: menos PR, costos altos, preguntas desde nivel Medio con más opciones y pistas que restan PR.",
		"pr_inicial": 100, "costo_mult": 1.25, "tiempo_crecimiento": 55.0, "umbral_desbloqueo": 85.0,
		"dias_gracia": 1, "severidad_mult": 1.3,
		"nivel_inicial_dda": 1, "racha_para_subir": 2, "distractores": 3,
		"pista_inmediata": false, "pr_con_pista": 0.5,
	},
}

var bioma_actual_id: int = -1
var herramienta_activa: String = "identificar":
	set(valor):
		herramienta_activa = valor
		herramienta_cambiada.emit(valor)
var especie_para_plantar: EspecieData

var biomas: Dictionary = {}        # "id_bioma" -> estado del bioma (ver estado_bioma)
var descubiertas: Dictionary = {}  # "id_especie" -> timestamp del primer avistamiento
var validaciones: Dictionary = {}  # "id_especie" -> {etapa, proxima, sesion_bloqueada}
var desbloqueados: Array[int] = []
var ultimo_bioma: int = -1
var sesion: int = 0
var primera_partida := true
## Modo de juego de la partida (clave de MODOS). Se elige al comenzar y no cambia hasta una partida nueva.
var modo: String = MODO_POR_DEFECTO
var modo_elegido := false
## Paso actual del tutorial guiado (ver ui/hud/tutorial.gd); al completarlo queda en el total de pasos.
var tutorial_paso := 0
## Opciones del jugador (se aplican al cargar).
var opciones: Dictionary = {"volumen": 0.8, "pantalla_completa": false}
## Código anónimo para cruzar el registro con instrumentos externos (pre/post test).
var codigo_participante := ""
## Registro de aprendizaje para la investigación (ver registrar() y registro_csv()).
var registro: Array = []
var datos_trivia: Dictionary = {}

## Resumen de lo que ocurrió mientras el jugador no estuvo (se muestra al iniciar).
var informe_degradacion: Array[String] = []
var dias_inactivo: int = 0

var _ultima_sesion: float = 0.0
var _inicio_sesion_ms := 0
var _revision_repasos := 0.0
var _rapidos_avisados: Dictionary = {}   # id_especie -> true (ya se avisó en esta sesión)
## Avistamientos en la vida real que el jugador marcó en la Biopedia: "id_especie" -> timestamp.
var avistamientos_reales: Dictionary = {}
var _cambios_pendientes := false
var _tiempo_sin_guardar := 0.0


func _ready() -> void:
	_inicio_sesion_ms = Time.get_ticks_msec()
	cargar()
	sesion += 1
	_aplicar_degradacion_por_inactividad(Time.get_unix_time_from_system())
	aplicar_opciones()
	registrar({"tipo": "inicio_sesion", "detalle": "dias_inactivo=%d" % dias_inactivo})
	guardar()
	# Acciones en el terreno, para medir el recorrido del jugador (p. ej. tiempo hasta la primera planta).
	EventBus.accion_terreno.connect(func(accion: String) -> void:
		var e := {"tipo": "accion", "detalle": accion}
		if accion == "plantar" and especie_para_plantar:
			e["id_especie"] = especie_para_plantar.id_especie
			e["especie"] = especie_para_plantar.nombre_comun
		registrar(e))
	EventBus.accion_rechazada.connect(func(motivo: String) -> void:
		registrar({"tipo": "accion_rechazada", "detalle": "%s: %s" % [herramienta_activa, motivo]}))


func _process(delta: float) -> void:
	_revision_repasos += delta
	if _revision_repasos >= INTERVALO_REVISION_REPASOS:
		_revision_repasos = 0.0
		_avisar_repasos_rapidos()
	if not _cambios_pendientes:
		return
	_tiempo_sin_guardar += delta
	if _tiempo_sin_guardar >= SEGUNDOS_ENTRE_GUARDADOS:
		guardar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		registrar({"tipo": "fin_sesion"})
		guardar()


# --- Biomas -------------------------------------------------------------------

func estado_bioma(id_bioma: int) -> Dictionary:
	var clave := str(id_bioma)
	if not biomas.has(clave):
		biomas[clave] = {
			"pr": int(ajuste("pr_inicial")),
			"salud": 0.0,
			"celdas": {},
			"fauna": [],
			"bloqueadores_iniciales": 0,
			"fauna_total": 0,
			"niebla_pendiente": 0,
		}
	return biomas[clave]


# --- Modo de juego -----------------------------------------------------------------------

## Valor de un parámetro del modo actual (ver MODOS).
func ajuste(parametro: String) -> Variant:
	return MODOS.get(modo, MODOS[MODO_POR_DEFECTO])[parametro]


func nombre_modo(id_modo: String = "") -> String:
	return str(MODOS.get(id_modo if id_modo != "" else modo, MODOS[MODO_POR_DEFECTO])["nombre"])


func umbral_desbloqueo() -> float:
	return float(ajuste("umbral_desbloqueo"))


## Costo en PR ajustado al modo, redondeado a múltiplos de 5.
func costo(base: int) -> int:
	return maxi(5, roundi(base * float(ajuste("costo_mult")) / 5.0) * 5)


## Elección del modo al comenzar la partida. Los biomas aún intactos reciben los PR iniciales del nuevo modo.
## En la primera elección el bioma inicial ya tiene algo de salud (el claro inicial sin niebla),
## así que basta con que no se hayan gastado PR.
func elegir_modo(id_modo: String) -> void:
	if not MODOS.has(id_modo):
		return
	var pr_anterior := int(ajuste("pr_inicial"))
	var primera_eleccion := not modo_elegido
	modo = id_modo
	modo_elegido = true
	for clave in biomas:
		var estado: Dictionary = biomas[clave]
		if int(estado.get("pr", 0)) == pr_anterior and (primera_eleccion or float(estado.get("salud", 0.0)) <= 0.0):
			agregar_pr(int(ajuste("pr_inicial")) - pr_anterior, int(clave))
	var trivia := get_node_or_null("/root/TriviaManager")
	if trivia and trivia.total_trivias_respondidas == 0:
		trivia.reiniciar()
	registrar({"tipo": "eleccion_modo", "detalle": id_modo})
	marcar_cambios()
	modo_cambiado.emit(id_modo)


func nombre_bioma(id_bioma: int) -> String:
	return NOMBRES_BIOMAS.get(id_bioma, "Bioma %d" % id_bioma)


func esta_desbloqueado(id_bioma: int) -> bool:
	return desbloqueados.has(id_bioma)


func bioma_anterior(id_bioma: int) -> int:
	var i := ORDEN_BIOMAS.find(id_bioma)
	return ORDEN_BIOMAS[i - 1] if i > 0 else -1


func salud(id_bioma: int) -> float:
	return float(estado_bioma(id_bioma).get("salud", 0.0))


## Salud 0-100 derivada del estado de la grilla: niebla despejada, bloqueadores retirados,
## vitalidad de la flora plantada y fauna presente.
func calcular_salud(id_bioma: int) -> float:
	var estado := estado_bioma(id_bioma)
	var celdas: Dictionary = estado["celdas"]
	var total := celdas.size()
	if total == 0:
		return 0.0

	var con_niebla := 0
	var bloqueos := 0
	var vitalidad := 0.0
	for clave in celdas:
		var c: Dictionary = celdas[clave]
		if str(c.get("b", "")) != "":
			bloqueos += 1
		if c.get("n", false):
			con_niebla += 1
			continue
		if int(c.get("e", 0)) > 0:
			vitalidad += float(c.get("c", 0.0)) * (0.3 if c.get("m", false) else 1.0)
	con_niebla = mini(total, con_niebla + int(estado.get("niebla_pendiente", 0)))

	var despeje := 1.0 - float(con_niebla) / total
	var iniciales := int(estado.get("bloqueadores_iniciales", 0))
	var limpieza := 1.0 if iniciales == 0 else clampf(1.0 - float(bloqueos) / iniciales, 0.0, 1.0)
	var flora := clampf(vitalidad / meta_flora(total), 0.0, 1.0)
	var fauna_total := int(estado.get("fauna_total", 0))
	var peso_flora := PESO_FLORA
	var fauna := 0.0
	if fauna_total > 0:
		fauna = clampf(float((estado["fauna"] as Array).size()) / fauna_total, 0.0, 1.0)
	else:
		peso_flora += PESO_FAUNA
	var resultado := despeje * PESO_DESPEJE + limpieza * PESO_LIMPIEZA + flora * peso_flora
	if fauna_total > 0:
		resultado += fauna * PESO_FAUNA
	return clampf(resultado, 0.0, 100.0)


## Cantidad de plantas adultas sanas para completar el componente de flora de la salud.
func meta_flora(total_celdas: int) -> float:
	return clampf(total_celdas * 0.05, 6.0, 14.0)


func actualizar_salud(id_bioma: int) -> float:
	var valor := calcular_salud(id_bioma)
	var estado := estado_bioma(id_bioma)
	if absf(valor - float(estado.get("salud", 0.0))) > 0.01:
		estado["salud"] = valor
		marcar_cambios()
	salud_actualizada.emit(id_bioma, valor)
	if valor >= umbral_desbloqueo():
		_desbloquear_siguiente(id_bioma)
	return valor


func _desbloquear_siguiente(id_bioma: int) -> void:
	var i := ORDEN_BIOMAS.find(id_bioma)
	if i < 0 or i + 1 >= ORDEN_BIOMAS.size():
		return
	var siguiente := ORDEN_BIOMAS[i + 1]
	if desbloqueados.has(siguiente):
		return
	desbloqueados.append(siguiente)
	marcar_cambios()
	bioma_desbloqueado.emit(siguiente)


# --- Economía (PR locales por bioma) -----------------------------------------------

func obtener_pr(id_bioma: int = -1) -> int:
	if id_bioma < 0:
		id_bioma = bioma_actual_id
	return int(estado_bioma(id_bioma).get("pr", 0))


func agregar_pr(cantidad: int, id_bioma: int = -1) -> void:
	if id_bioma < 0:
		id_bioma = bioma_actual_id
	if id_bioma < 0:
		return
	var estado := estado_bioma(id_bioma)
	estado["pr"] = obtener_pr(id_bioma) + cantidad
	marcar_cambios()
	pr_actualizado.emit(id_bioma, int(estado["pr"]))


func gastar_pr(cantidad: int, id_bioma: int = -1) -> bool:
	if id_bioma < 0:
		id_bioma = bioma_actual_id
	if obtener_pr(id_bioma) < cantidad:
		return false
	agregar_pr(-cantidad, id_bioma)
	return true


# --- Biopedia y repetición espaciada -------------------------------------------------

func esta_descubierta(id_especie: int) -> bool:
	return descubiertas.has(str(id_especie))


## Registra el primer avistamiento y programa las validaciones de 24 h, 3 y 7 días.
func descubrir_especie(data: EspecieData) -> bool:
	if data == null or esta_descubierta(data.id_especie):
		return false
	var clave := str(data.id_especie)
	var ahora := Time.get_unix_time_from_system()
	descubiertas[clave] = ahora
	validaciones[clave] = {
		"etapa": 0,
		"proxima": ahora + INTERVALOS_REPASO_DIAS[0] * SEGUNDOS_DIA,
		"sesion_bloqueada": -1,
		"rapido": ahora + SEGUNDOS_REPASO_RAPIDO,
	}
	marcar_cambios()
	especie_descubierta.emit(data)
	repasos_actualizados.emit()
	registrar({"tipo": "descubrimiento", "id_especie": data.id_especie, "especie": data.nombre_comun, "id_bioma": data.id_bioma})
	return true


func etapa_validacion(id_especie: int) -> int:
	return int(validaciones.get(str(id_especie), {}).get("etapa", 0))


func proximo_repaso(id_especie: int) -> float:
	return float(validaciones.get(str(id_especie), {}).get("proxima", 0.0))


func repasos_pendientes() -> Array[int]:
	var resultado: Array[int] = []
	var ahora := Time.get_unix_time_from_system()
	for clave in validaciones:
		var v: Dictionary = validaciones[clave]
		if es_repaso_rapido(int(clave)):
			resultado.append(int(clave))
			continue
		if int(v["etapa"]) >= INTERVALOS_REPASO_DIAS.size():
			continue
		if ahora >= float(v["proxima"]) and int(v.get("sesion_bloqueada", -1)) < sesion:
			resultado.append(int(clave))
	# Los repasos rápidos van primero: son los que más conviene hacer ahora.
	resultado.sort_custom(func(a: int, b: int) -> bool:
		if es_repaso_rapido(a) != es_repaso_rapido(b):
			return es_repaso_rapido(a)
		return a < b)
	return resultado


## true si a la especie le toca ahora su repaso rápido (el de minutos después de descubrirla).
func es_repaso_rapido(id_especie: int) -> bool:
	var rapido := float(validaciones.get(str(id_especie), {}).get("rapido", 0.0))
	return rapido > 0.0 and Time.get_unix_time_from_system() >= rapido


## Avisa en pantalla cuando vence un repaso rápido (una vez por especie y sesión).
func _avisar_repasos_rapidos() -> void:
	var nuevos: Array[String] = []
	for clave in validaciones:
		var id := int(clave)
		if es_repaso_rapido(id) and not _rapidos_avisados.has(id):
			_rapidos_avisados[id] = true
			var data := EspecieLoader.por_id(id)
			if data:
				nuevos.append(data.nombre_comun)
	if nuevos.is_empty():
		return
	repasos_actualizados.emit()
	EventBus.mensaje.emit("Repaso rápido: ¿recuerdas a %s? Lo encuentras en la Tableta, pestaña «Repasos»." % " y ".join(PackedStringArray(nuevos)))


## Acierto: avanza la validación. Error: sin castigo, se reprograma para la próxima sesión.
## El repaso rápido no avanza etapas: acertarlo lo cierra y fallarlo lo repite unos minutos después.
func registrar_repaso(id_especie: int, correcta: bool) -> void:
	var clave := str(id_especie)
	if not validaciones.has(clave):
		return
	var v: Dictionary = validaciones[clave]
	if es_repaso_rapido(id_especie):
		v["rapido"] = 0.0 if correcta else Time.get_unix_time_from_system() + SEGUNDOS_REPASO_RAPIDO
		_rapidos_avisados.erase(id_especie)
		marcar_cambios()
		repasos_actualizados.emit()
		return
	if correcta:
		var etapa := int(v["etapa"]) + 1
		v["etapa"] = etapa
		if etapa < INTERVALOS_REPASO_DIAS.size():
			var ahora := Time.get_unix_time_from_system()
			var desde_avistamiento := float(descubiertas.get(clave, ahora)) + INTERVALOS_REPASO_DIAS[etapa] * SEGUNDOS_DIA
			var espera_minima := (INTERVALOS_REPASO_DIAS[etapa] - INTERVALOS_REPASO_DIAS[etapa - 1]) * SEGUNDOS_DIA
			v["proxima"] = maxf(desde_avistamiento, ahora + espera_minima)
	else:
		v["sesion_bloqueada"] = sesion
	marcar_cambios()
	repasos_actualizados.emit()


## «La vi en la vida real» (Biopedia): queda en el registro para la investigación.
func marcar_avistamiento_real(data: EspecieData) -> void:
	var clave := str(data.id_especie)
	if avistamientos_reales.has(clave):
		return
	avistamientos_reales[clave] = Time.get_unix_time_from_system()
	registrar({"tipo": "avistamiento_real", "id_especie": data.id_especie, "especie": data.nombre_comun, "id_bioma": data.id_bioma})


func vio_en_la_vida_real(id_especie: int) -> bool:
	return avistamientos_reales.has(str(id_especie))


# --- Degradación por abandono ---------------------------------------------------------

func _aplicar_degradacion_por_inactividad(ahora: float) -> void:
	informe_degradacion.clear()
	dias_inactivo = 0
	if _ultima_sesion <= 0.0:
		return
	dias_inactivo = int((ahora - _ultima_sesion) / SEGUNDOS_DIA)
	var dias_gracia := int(ajuste("dias_gracia"))
	if dias_inactivo <= dias_gracia:
		return

	var severidad := mini(dias_inactivo - dias_gracia, MAX_SEVERIDAD)
	var factor := float(ajuste("severidad_mult"))
	var prob_marchitar := minf(0.9, 0.25 * severidad * factor)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for clave in biomas:
		var estado: Dictionary = biomas[clave]
		var celdas: Dictionary = estado.get("celdas", {})
		if celdas.is_empty():
			continue
		var marchitas := 0
		for k in celdas:
			var c: Dictionary = celdas[k]
			if int(c.get("e", 0)) > 0 and not c.get("m", false) and rng.randf() < prob_marchitar:
				c["m"] = true
				marchitas += 1
		var fauna: Array = estado.get("fauna", [])
		var se_fueron := fauna.size()
		fauna.clear()
		var niebla := roundi(3 * severidad * factor)
		estado["niebla_pendiente"] = int(estado.get("niebla_pendiente", 0)) + niebla
		var antes := float(estado.get("salud", 0.0))
		estado["salud"] = calcular_salud(int(clave))

		var partes: Array[String] = []
		if marchitas > 0:
			partes.append("%d plantas se marchitaron" % marchitas)
		if se_fueron > 0:
			partes.append("%d especies de fauna abandonaron el refugio" % se_fueron)
		partes.append("la Niebla del Olvido avanzó sobre %d parcelas" % niebla)
		informe_degradacion.append("• %s: %s (salud %d%% → %d%%)." % [
			nombre_bioma(int(clave)), ", ".join(PackedStringArray(partes)), int(antes), int(estado["salud"])])
	marcar_cambios()


## Herramienta de desarrollo: simula que pasaron `dias` sin jugar (degradación y repasos vencidos).
func simular_inactividad(dias: int) -> void:
	var desplazamiento := float(dias * SEGUNDOS_DIA)
	for clave in descubiertas:
		descubiertas[clave] = float(descubiertas[clave]) - desplazamiento
	for clave in validaciones:
		var v: Dictionary = validaciones[clave]
		v["proxima"] = float(v.get("proxima", 0.0)) - desplazamiento
		if float(v.get("rapido", 0.0)) > 0.0:
			v["rapido"] = float(v["rapido"]) - desplazamiento
	var ahora := Time.get_unix_time_from_system()
	_ultima_sesion = ahora - desplazamiento
	sesion += 1
	_aplicar_degradacion_por_inactividad(ahora)
	repasos_actualizados.emit()
	guardar()


# --- Opciones ---------------------------------------------------------------------

func aplicar_opciones() -> void:
	aplicar_volumen()
	# En la web la pantalla completa solo puede pedirse tras un toque del jugador (desde Opciones).
	if not OS.has_feature("web"):
		var completa := bool(opciones.get("pantalla_completa", false))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if completa else DisplayServer.WINDOW_MODE_WINDOWED)


func aplicar_volumen() -> void:
	var volumen := clampf(float(opciones.get("volumen", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volumen, 0.0001)))
	AudioServer.set_bus_mute(0, volumen <= 0.001)


# --- Registro de aprendizaje (para la tesis) ------------------------------------------

const COLUMNAS_REGISTRO: Array[String] = ["fecha_hora", "participante", "sesion", "t_sesion_s", "modo_juego", "tipo", "id_bioma", "bioma",
	"id_especie", "especie", "id_trivia", "dificultad", "modo", "correcta", "tiempo_s", "uso_pista",
	"apoyo_tutor", "nivel_dda", "pr", "detalle", "ficha_visible", "imagen_apoyo"]


## Agrega un evento al registro. Se completan fecha, sesión, participante y bioma.
func registrar(evento: Dictionary) -> void:
	var e := evento.duplicate()
	e["fecha_hora"] = Time.get_datetime_string_from_system(false, true)
	e["participante"] = codigo_participante
	e["sesion"] = sesion
	# Segundos desde que se abrió el juego: permite medir, por ejemplo, el tiempo hasta la primera planta.
	e["t_sesion_s"] = snappedf((Time.get_ticks_msec() - _inicio_sesion_ms) / 1000.0, 0.1)
	e["modo_juego"] = modo
	if not e.has("id_bioma"):
		e["id_bioma"] = bioma_actual_id
	e["bioma"] = nombre_bioma(int(e["id_bioma"])) if int(e["id_bioma"]) > 0 else ""
	registro.append(e)
	marcar_cambios()


func registro_csv() -> String:
	var lineas: PackedStringArray = [",".join(PackedStringArray(COLUMNAS_REGISTRO))]
	for e in registro:
		var campos: PackedStringArray = []
		for col in COLUMNAS_REGISTRO:
			var v = e.get(col, "")
			if v is bool:
				v = 1 if v else 0
			var texto := str(v).replace("\"", "\"\"")
			campos.append("\"%s\"" % texto if ("," in texto or "\"" in texto or "\n" in texto) else texto)
		lineas.append(",".join(campos))
	# BOM para que Excel reconozca los acentos (UTF-8).
	return "\ufeff" + "\n".join(lineas) + "\n"


# --- Persistencia -------------------------------------------------------------------

## Borra todo el progreso y vuelve a cargar la escena principal desde cero con el modo indicado.
func reiniciar_partida(id_modo: String = "") -> void:
	modo = id_modo if MODOS.has(id_modo) else modo
	modo_elegido = MODOS.has(id_modo)
	biomas = {}
	descubiertas = {}
	validaciones = {}
	avistamientos_reales = {}
	_rapidos_avisados.clear()
	desbloqueados = [ORDEN_BIOMAS[0]]
	ultimo_bioma = -1
	bioma_actual_id = -1
	especie_para_plantar = null
	herramienta_activa = "identificar"
	sesion = 1
	primera_partida = true
	tutorial_paso = 0
	registro.clear()
	# El reloj de sesión vuelve a cero: t_sesion_s no debe incluir el tiempo de la partida anterior.
	# El código de participante se conserva a propósito (es la misma persona).
	_inicio_sesion_ms = Time.get_ticks_msec()
	registrar({"tipo": "nueva_partida"})
	informe_degradacion.clear()
	dias_inactivo = 0
	var trivia := get_node_or_null("/root/TriviaManager")
	if trivia:
		trivia.reiniciar()
	datos_trivia = {}
	guardar()
	get_tree().reload_current_scene()


func marcar_cambios() -> void:
	_cambios_pendientes = true


func guardar() -> void:
	var trivia := get_node_or_null("/root/TriviaManager")
	if trivia:
		datos_trivia = trivia.exportar()
	_ultima_sesion = Time.get_unix_time_from_system()
	var datos := {
		"version": VERSION_GUARDADO,
		"ultima_sesion": _ultima_sesion,
		"sesion": sesion,
		"primera_partida": primera_partida,
		"tutorial_paso": tutorial_paso,
		"modo": modo,
		"modo_elegido": modo_elegido,
		"opciones": opciones,
		"codigo_participante": codigo_participante,
		"registro": registro,
		"ultimo_bioma": ultimo_bioma,
		"desbloqueados": desbloqueados,
		"biomas": biomas,
		"descubiertas": descubiertas,
		"validaciones": validaciones,
		"avistamientos_reales": avistamientos_reales,
		"trivia": datos_trivia,
	}
	# Escritura segura: primero un archivo temporal, se comprueba que se puede leer de vuelta y recién
	# entonces reemplaza al principal; la versión anterior queda como respaldo (.bak). Si el juego se
	# cierra a mitad de la escritura, la partida anterior sigue intacta.
	var texto := JSON.stringify(datos)
	var temporal := RUTA_GUARDADO + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		push_error("[GameState] No se pudo guardar la partida: %s" % error_string(FileAccess.get_open_error()))
		return
	archivo.store_string(texto)
	archivo.close()
	if FileAccess.get_file_as_string(temporal) != texto:
		push_error("[GameState] El guardado no se escribió completo; se conserva la partida anterior.")
		return
	var principal := ProjectSettings.globalize_path(RUTA_GUARDADO)
	var respaldo := ProjectSettings.globalize_path(RUTA_RESPALDO)
	if FileAccess.file_exists(RUTA_GUARDADO):
		if FileAccess.file_exists(RUTA_RESPALDO):
			DirAccess.remove_absolute(respaldo)
		DirAccess.rename_absolute(principal, respaldo)
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporal), principal)
	if error != OK:
		push_error("[GameState] No se pudo reemplazar el guardado: %s" % error_string(error))
		return
	_cambios_pendientes = false
	_tiempo_sin_guardar = 0.0


## El proyecto se llamó "New Game Project" durante el prototipo; Godot guarda los datos en una
## carpeta con el nombre del proyecto, así que traemos la partida antigua si existe.
func _migrar_guardado_antiguo() -> void:
	if FileAccess.file_exists(RUTA_GUARDADO):
		return
	var antiguo := OS.get_user_data_dir().get_base_dir().path_join("New Game Project/faunetra_guardado.json")
	if FileAccess.file_exists(antiguo):
		DirAccess.copy_absolute(antiguo, ProjectSettings.globalize_path(RUTA_GUARDADO))


## Lee y parsea un archivo de guardado; null si no existe o no es un diccionario JSON.
func _leer_guardado(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return datos if datos is Dictionary else null


func _dic(datos: Dictionary, clave: String) -> Dictionary:
	var v = datos.get(clave, {})
	return v if v is Dictionary else {}


func _lista(datos: Dictionary, clave: String) -> Array:
	var v = datos.get(clave, [])
	return v if v is Array else []


func cargar() -> void:
	desbloqueados = [ORDEN_BIOMAS[0]]
	_migrar_guardado_antiguo()
	if not FileAccess.file_exists(RUTA_GUARDADO) and not FileAccess.file_exists(RUTA_RESPALDO):
		return
	var datos = _leer_guardado(RUTA_GUARDADO)
	if datos == null:
		datos = _leer_guardado(RUTA_RESPALDO)
		if FileAccess.file_exists(RUTA_GUARDADO):
			# No se sobrescribe a ciegas una partida que no se pudo leer: se aparta para revisarla.
			DirAccess.rename_absolute(ProjectSettings.globalize_path(RUTA_GUARDADO),
				ProjectSettings.globalize_path(RUTA_GUARDADO + ".ilegible"))
		if datos == null:
			push_warning("[GameState] Guardado ilegible y sin respaldo válido, se inicia una partida nueva.")
			return
		push_warning("[GameState] Guardado ilegible: se recuperó la partida desde el respaldo.")
	if int(datos.get("version", 1)) > VERSION_GUARDADO:
		push_warning("[GameState] El guardado viene de una versión más nueva del juego (%s)." % datos.get("version"))

	_ultima_sesion = float(datos.get("ultima_sesion", 0.0))
	sesion = int(datos.get("sesion", 0))
	primera_partida = bool(datos.get("primera_partida", true))
	tutorial_paso = int(datos.get("tutorial_paso", 0))
	modo = str(datos.get("modo", MODO_POR_DEFECTO))
	if not MODOS.has(modo):
		modo = MODO_POR_DEFECTO
	# Las partidas anteriores a los modos siguen en Guardaparques sin volver a preguntar.
	modo_elegido = bool(datos.get("modo_elegido", not primera_partida))
	opciones.merge(_dic(datos, "opciones"), true)
	codigo_participante = str(datos.get("codigo_participante", ""))
	# Cada estructura se valida por tipo: un JSON válido pero con otra forma no debe romper la carga.
	registro = _lista(datos, "registro")
	ultimo_bioma = int(datos.get("ultimo_bioma", -1))
	for id in _lista(datos, "desbloqueados"):
		if not desbloqueados.has(int(id)):
			desbloqueados.append(int(id))
	biomas = _dic(datos, "biomas")
	descubiertas = _dic(datos, "descubiertas")
	validaciones = _dic(datos, "validaciones")
	avistamientos_reales = _dic(datos, "avistamientos_reales")
	datos_trivia = _dic(datos, "trivia")
	for clave in biomas.keys():
		if not (biomas[clave] is Dictionary):
			biomas.erase(clave)
	for clave in validaciones.keys():
		if not (validaciones[clave] is Dictionary):
			validaciones.erase(clave)
	registro = registro.filter(func(e) -> bool: return e is Dictionary)

	# JSON guarda todos los números como float: normalizamos los que se usan como enteros.
	# Guardados incompletos o de versiones anteriores: completamos las claves que faltan.
	for clave in biomas:
		var estado: Dictionary = biomas[clave]
		if not (estado.get("celdas") is Dictionary):
			estado["celdas"] = {}
		if not (estado.get("fauna") is Array):
			estado["fauna"] = []
		estado["salud"] = float(estado.get("salud", 0.0))
		estado["bloqueadores_iniciales"] = int(estado.get("bloqueadores_iniciales", 0))
		estado["fauna_total"] = int(estado.get("fauna_total", 0))
		estado["niebla_pendiente"] = int(estado.get("niebla_pendiente", 0))
		var fauna: Array = []
		for id in estado.get("fauna", []):
			fauna.append(int(id))
		estado["fauna"] = fauna
		if estado.has("fauna_identificada"):
			var identificadas: Array = []
			for id in estado["fauna_identificada"]:
				identificadas.append(int(id))
			estado["fauna_identificada"] = identificadas
		estado["pr"] = int(estado.get("pr", ajuste("pr_inicial")))
		for k in estado.get("celdas", {}):
			var c: Dictionary = estado["celdas"][k]
			c["e"] = int(c.get("e", 0))
	for clave in validaciones:
		var v: Dictionary = validaciones[clave]
		v["etapa"] = int(v.get("etapa", 0))
		v["sesion_bloqueada"] = int(v.get("sesion_bloqueada", -1))
		v["proxima"] = float(v.get("proxima", float(descubiertas.get(clave, 0.0)) + INTERVALOS_REPASO_DIAS[0] * SEGUNDOS_DIA))
		v["rapido"] = float(v.get("rapido", 0.0))
