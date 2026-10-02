extends Node

## TriviaManager - Gestor de trivias adaptativas (DDA y Flow Theory) y Tutor Inteligente (ITS).
## Carga el banco de trivias narrativas, gestiona el nivel de dificultad adaptativo del jugador,
## detecta dificultades por categoría (flora/fauna) para ofrecer apoyo, genera preguntas a partir
## de las fichas de especies cuando el banco no alcanza y entrega las recompensas (PR, XP e Insignias).

signal trivia_iniciada(trivia: TriviaData)
signal respuesta_evaluada(es_correcta: bool, retroalimentacion: String, recompensa_xp: int)
signal nivel_dificultad_cambiado(nuevo_nivel: TriviaData.Dificultad)

const RUTA_BANCO_JSON := "res://data/trivias/banco_trivias.json"
## PR (Esencia Vital) que entrega una respuesta correcta según su dificultad.
const PR_POR_DIFICULTAD: Array[int] = [60, 90, 130]
const XP_GENERADA: Array[int] = [30, 50, 75]
const PR_BONO_REPASO := 30
const NOMBRES_DIFICULTAD: Array[String] = ["Fácil", "Medio", "Difícil"]

var trivias_cargadas: Array[TriviaData] = []
var nivel_actual_jugador: TriviaData.Dificultad = TriviaData.Dificultad.FACIL

# Métricas para Dynamic Difficulty Adaptivity (DDA - Chen 2006)
var racha_aciertos: int = 0
var racha_errores: int = 0
var total_trivias_respondidas: int = 0
var xp_acumulada: int = 0
var insignias_desbloqueadas: Array[String] = []
## Modelo del estudiante del ITS: "flora"/"fauna" -> {"aciertos": int, "errores": int}
var desempeno_por_categoria: Dictionary = {}

## Trivias ya mostradas en esta sesión, para no repetirlas mientras queden otras.
var _mostradas: Dictionary = {}


func _ready() -> void:
	cargar_banco_trivias()
	importar(GameState.datos_trivia)


func cargar_banco_trivias() -> void:
	trivias_cargadas.clear()
	if not FileAccess.file_exists(RUTA_BANCO_JSON):
		print_debug("[TriviaManager] No se encontró el archivo del banco de trivias: ", RUTA_BANCO_JSON)
		return

	var file := FileAccess.open(RUTA_BANCO_JSON, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var json = JSON.parse_string(content)
	if typeof(json) != TYPE_ARRAY:
		print_debug("[TriviaManager] Formato inválido en banco_trivias.json")
		return

	for item in json:
		var trivia := TriviaData.new()
		trivia.id_trivia = item.get("id_trivia", "")
		trivia.id_especie = item.get("id_especie", 0)
		trivia.nombre_especie = item.get("nombre_especie", "")
		trivia.id_bioma = item.get("id_bioma", 0)

		match item.get("dificultad", "FACIL"):
			"MEDIO":
				trivia.dificultad = TriviaData.Dificultad.MEDIO
			"DIFICIL":
				trivia.dificultad = TriviaData.Dificultad.DIFICIL
			_:
				trivia.dificultad = TriviaData.Dificultad.FACIL

		trivia.titulo_narrativo = item.get("titulo_narrativo", "")
		trivia.situacion_narrativa = item.get("situacion_narrativa", "")
		trivia.pregunta = item.get("pregunta", "")
		trivia.pista_narrativa = item.get("pista_narrativa", "")
		trivia.recompensa_xp = item.get("recompensa_xp", 50)
		trivia.insignia_id = item.get("insignia_id", "")

		var ops_data: Array = item.get("opciones", [])
		var ops_list: Array[TriviaOption] = []
		for op_json in ops_data:
			var op := TriviaOption.new()
			op.texto = op_json.get("texto", "")
			op.es_correcta = op_json.get("es_correcta", false)
			op.retroalimentacion_narrativa = op_json.get("retroalimentacion_narrativa", "")
			ops_list.append(op)

		trivia.opciones = ops_list
		trivias_cargadas.append(trivia)

	print("[TriviaManager] Banco cargado exitosamente. Total trivias: ", trivias_cargadas.size())


## Selecciona una trivia de forma adaptativa para la especie o el bioma solicitado.
## Prioridad: narrativas no vistas del nivel adecuado → narrativas no vistas de otro nivel
## (salvo que el tutor detecte dificultades) → pregunta generada desde la ficha de una especie.
func obtener_trivia_adaptativa(id_especie: int = 0, id_bioma: int = 0) -> TriviaData:
	var nivel := nivel_objetivo(id_especie)
	var candidatas: Array[TriviaData] = []
	for t in trivias_cargadas:
		if (id_especie == 0 or t.id_especie == id_especie) and (id_bioma == 0 or t.id_bioma == id_bioma):
			candidatas.append(t)
	var nuevas := candidatas.filter(func(t: TriviaData) -> bool: return not _mostradas.has(t.id_trivia))
	var del_nivel := nuevas.filter(func(t: TriviaData) -> bool: return t.dificultad == nivel)

	var elegida: TriviaData = null
	if not del_nivel.is_empty():
		elegida = del_nivel.pick_random()
	elif not nuevas.is_empty() and not necesita_apoyo(id_especie):
		elegida = nuevas.pick_random()
	else:
		elegida = _generar_para(id_especie, id_bioma, nivel)
	if elegida == null and not candidatas.is_empty():
		elegida = candidatas.pick_random()

	if elegida:
		_mostradas[elegida.id_trivia] = true
		trivia_iniciada.emit(elegida)
	return elegida


## Trivia para una validación de repetición espaciada de una especie ya descubierta.
func trivia_para_repaso(id_especie: int) -> TriviaData:
	var del_banco := trivias_cargadas.filter(func(t: TriviaData) -> bool: return t.id_especie == id_especie)
	var elegida: TriviaData = null
	if not del_banco.is_empty() and randf() < 0.5:
		elegida = del_banco.pick_random()
	else:
		elegida = _generar_para(id_especie, 0, nivel_objetivo(id_especie))
	if elegida == null and not del_banco.is_empty():
		elegida = del_banco.pick_random()
	if elegida:
		trivia_iniciada.emit(elegida)
	return elegida


## Nivel que conviene ofrecer: el del DDA, salvo que el tutor detecte dificultades.
func nivel_objetivo(id_especie: int = 0) -> TriviaData.Dificultad:
	if necesita_apoyo(id_especie):
		return TriviaData.Dificultad.FACIL
	return nivel_actual_jugador


## ITS: el jugador muestra dificultades si falla seguido o si en la categoría de la especie
## (flora o fauna) acumula más errores que aciertos.
func necesita_apoyo(id_especie: int = 0) -> bool:
	if racha_errores >= 2:
		return true
	if id_especie == 0:
		return false
	var reg: Dictionary = desempeno_por_categoria.get(_categoria(id_especie), {})
	var errores := int(reg.get("errores", 0))
	return errores >= 2 and errores > int(reg.get("aciertos", 0))


## Evalúa la respuesta elegida, entrega recompensas y ajusta la curva de dificultad (DDA).
## Fallar nunca descuenta PR ni salud.
## `meta` (opcional): {"tiempo_s": float, "uso_pista": bool, "modo": String} para el registro de aprendizaje.
func responder_trivia(trivia: TriviaData, opcion: TriviaOption, es_repaso: bool = false, meta: Dictionary = {}) -> Dictionary:
	var apoyo := necesita_apoyo(trivia.id_especie)
	var nivel_antes := int(nivel_actual_jugador)
	total_trivias_respondidas += 1
	var es_correcta := opcion.es_correcta
	var pr := 0
	var xp := 0
	var descubierta := false

	var categoria := _categoria(trivia.id_especie)
	var reg: Dictionary = desempeno_por_categoria.get(categoria, {"aciertos": 0, "errores": 0})

	if es_correcta:
		racha_aciertos += 1
		racha_errores = 0
		xp = trivia.recompensa_xp
		xp_acumulada += xp
		reg["aciertos"] = int(reg.get("aciertos", 0)) + 1
		if trivia.insignia_id != "" and not insignias_desbloqueadas.has(trivia.insignia_id):
			insignias_desbloqueadas.append(trivia.insignia_id)
		pr = PR_POR_DIFICULTAD[trivia.dificultad] + (PR_BONO_REPASO if es_repaso else 0)
		GameState.agregar_pr(pr)
		# Resolver una pista conceptual sobre una especie la registra en la Biopedia.
		descubierta = GameState.descubrir_especie(EspecieLoader.por_id(trivia.id_especie))
	else:
		racha_errores += 1
		racha_aciertos = 0
		reg["errores"] = int(reg.get("errores", 0)) + 1
	desempeno_por_categoria[categoria] = reg

	if es_repaso:
		GameState.registrar_repaso(trivia.id_especie, es_correcta)
	GameState.registrar({
		"tipo": "repaso" if es_repaso else "trivia",
		"id_bioma": trivia.id_bioma, "id_especie": trivia.id_especie, "especie": trivia.nombre_especie,
		"id_trivia": trivia.id_trivia, "dificultad": NOMBRES_DIFICULTAD[trivia.dificultad],
		"modo": meta.get("modo", ""), "correcta": es_correcta, "tiempo_s": snappedf(float(meta.get("tiempo_s", 0.0)), 0.1),
		"uso_pista": bool(meta.get("uso_pista", false)), "apoyo_tutor": apoyo,
		"nivel_dda": NOMBRES_DIFICULTAD[nivel_antes], "pr": pr,
	})

	_ajustar_dificultad_adaptativa()
	GameState.marcar_cambios()
	respuesta_evaluada.emit(es_correcta, opcion.retroalimentacion_narrativa, xp)
	return {"correcta": es_correcta, "pr": pr, "xp": xp, "descubierta": descubierta}


## Algoritmo DDA (Dynamic Difficulty Adaptivity - Chen 2006)
func _ajustar_dificultad_adaptativa() -> void:
	if racha_aciertos >= 2 and nivel_actual_jugador < TriviaData.Dificultad.DIFICIL:
		nivel_actual_jugador = (nivel_actual_jugador + 1) as TriviaData.Dificultad
		racha_aciertos = 0
		nivel_dificultad_cambiado.emit(nivel_actual_jugador)
		print("[DDA] Nivel incrementado a: ", nivel_actual_jugador)
	elif racha_errores >= 2 and nivel_actual_jugador > TriviaData.Dificultad.FACIL:
		nivel_actual_jugador = (nivel_actual_jugador - 1) as TriviaData.Dificultad
		racha_errores = 0
		nivel_dificultad_cambiado.emit(nivel_actual_jugador)
		print("[DDA] Nivel reducido a: ", nivel_actual_jugador)


func _categoria(id_especie: int) -> String:
	var data := EspecieLoader.por_id(id_especie)
	if data == null:
		return "general"
	return "flora" if EspecieLoader.es_flora(data) else "fauna"


# --- Generación de trivias desde la Biopedia ------------------------------------------

func _generar_para(id_especie: int, id_bioma: int, nivel: TriviaData.Dificultad) -> TriviaData:
	var data: EspecieData = null
	if id_especie != 0:
		data = EspecieLoader.por_id(id_especie)
	elif id_bioma != 0:
		# Preferimos una especie cuya pregunta generada de este nivel aún no se haya mostrado.
		var especies := EspecieLoader.cargar_especies_del_bioma(id_bioma)
		especies.shuffle()
		for d in especies:
			if not _mostradas.has("gen_%d_%d" % [d.id_especie, nivel]):
				data = d
				break
		if data == null and not especies.is_empty():
			data = especies[0]
	if data == null:
		return null
	return generar_trivia(data, nivel)


## Crea una pregunta de opción múltiple usando las fichas de especies:
## FÁCIL = reconocer la especie por su nombre científico, MEDIO = nomenclatura científica,
## DIFÍCIL = rol en la trama ecológica (relaciones y cadenas tróficas).
func generar_trivia(data: EspecieData, nivel: TriviaData.Dificultad) -> TriviaData:
	var t := TriviaData.new()
	t.id_trivia = "gen_%d_%d" % [data.id_especie, nivel]
	t.id_especie = data.id_especie
	t.nombre_especie = data.nombre_comun
	t.id_bioma = data.id_bioma
	t.dificultad = nivel
	t.recompensa_xp = XP_GENERADA[nivel]

	var otras := _otras_especies(data)
	var correcta := ""
	var distractores: Array[String] = []
	var bioma := GameState.nombre_bioma(data.id_bioma)
	match nivel:
		TriviaData.Dificultad.FACIL:
			t.titulo_narrativo = "Reconocimiento en terreno"
			t.situacion_narrativa = "Tu Tableta de Campo detecta una especie de %s. Su ficha dice: «%s»" % [bioma, data.rol_ecologico]
			t.pregunta = "¿Qué especie tiene el nombre científico %s?" % data.nombre_cientifico
			t.pista_narrativa = "Es de tipo «%s» y su estado de conservación es %s." % [data.tipo, _estado(data)]
			correcta = data.nombre_comun
			distractores = _valores(otras, func(d: EspecieData) -> String: return d.nombre_comun, correcta)
		TriviaData.Dificultad.MEDIO:
			t.titulo_narrativo = "Nomenclatura científica"
			t.situacion_narrativa = "Para registrar tu avistamiento de %s en la Biopedia necesitas su nombre científico." % data.nombre_comun
			t.pregunta = "¿Cuál es el nombre científico de %s?" % data.nombre_comun
			t.pista_narrativa = "Su nombre científico comienza con «%s…»." % data.nombre_cientifico.left(3)
			correcta = data.nombre_cientifico
			distractores = _valores(otras, func(d: EspecieData) -> String: return d.nombre_cientifico, correcta)
		_:
			t.titulo_narrativo = "Rol en la trama ecológica"
			t.situacion_narrativa = "Observas a %s interactuar con su entorno en %s." % [data.nombre_comun, bioma]
			t.pregunta = "¿Qué rol ecológico cumple %s en su ecosistema?" % data.nombre_comun
			t.pista_narrativa = "Es de tipo «%s» y está clasificada como %s." % [data.tipo, _estado(data)]
			correcta = data.rol_ecologico
			distractores = _valores(otras, func(d: EspecieData) -> String: return d.rol_ecologico, correcta)

	if distractores.is_empty():
		# Sin especies suficientes para distractores: preguntamos por el tipo de organismo.
		t.pregunta = "¿Qué tipo de organismo es %s?" % data.nombre_comun
		correcta = data.tipo
		for tipo in ["vertebrado", "ave", "planta", "hongo", "invertebrado"]:
			if tipo != correcta and distractores.size() < 2:
				distractores.append(tipo)

	var ficha := "%s (%s) — %s: %s" % [data.nombre_comun, data.nombre_cientifico, _estado(data), data.rol_ecologico]
	var opciones: Array[TriviaOption] = []
	var op_correcta := TriviaOption.new()
	op_correcta.texto = correcta
	op_correcta.es_correcta = true
	op_correcta.retroalimentacion_narrativa = "¡Correcto! " + ficha
	opciones.append(op_correcta)
	for texto in distractores:
		var op := TriviaOption.new()
		op.texto = texto
		op.retroalimentacion_narrativa = "No corresponde. Recuerda: " + ficha
		opciones.append(op)
	opciones.shuffle()
	t.opciones = opciones
	return t


## Otras especies para usar como distractores: primero del mismo bioma y del mismo reino.
func _otras_especies(data: EspecieData) -> Array[EspecieData]:
	var mismo_bioma: Array[EspecieData] = []
	var resto: Array[EspecieData] = []
	for d in EspecieLoader.cargar_todas():
		if d.id_especie == data.id_especie:
			continue
		if d.id_bioma == data.id_bioma and EspecieLoader.es_flora(d) == EspecieLoader.es_flora(data):
			mismo_bioma.append(d)
		else:
			resto.append(d)
	mismo_bioma.shuffle()
	resto.shuffle()
	mismo_bioma.append_array(resto)
	return mismo_bioma


func _valores(especies: Array[EspecieData], campo: Callable, excluir: String) -> Array[String]:
	var resultado: Array[String] = []
	for d in especies:
		var valor: String = campo.call(d)
		if valor.strip_edges() == "" or valor == excluir or resultado.has(valor):
			continue
		resultado.append(valor)
		if resultado.size() >= 2:
			break
	return resultado


func _estado(data: EspecieData) -> String:
	return "%s (%s)" % [EspecieData.NOMBRES_ESTADO.get(data.estado_conservacion, "sin evaluar"), data.estado_conservacion]


# --- Persistencia ---------------------------------------------------------------------

func reiniciar() -> void:
	nivel_actual_jugador = TriviaData.Dificultad.FACIL
	racha_aciertos = 0
	racha_errores = 0
	total_trivias_respondidas = 0
	xp_acumulada = 0
	insignias_desbloqueadas.clear()
	desempeno_por_categoria = {}
	_mostradas.clear()


func exportar() -> Dictionary:
	return {
		"nivel": int(nivel_actual_jugador),
		"racha_aciertos": racha_aciertos,
		"racha_errores": racha_errores,
		"total": total_trivias_respondidas,
		"xp": xp_acumulada,
		"insignias": insignias_desbloqueadas,
		"desempeno": desempeno_por_categoria,
	}


func importar(datos: Dictionary) -> void:
	if datos.is_empty():
		return
	nivel_actual_jugador = clampi(int(datos.get("nivel", 0)), 0, TriviaData.Dificultad.DIFICIL) as TriviaData.Dificultad
	racha_aciertos = int(datos.get("racha_aciertos", 0))
	racha_errores = int(datos.get("racha_errores", 0))
	total_trivias_respondidas = int(datos.get("total", 0))
	xp_acumulada = int(datos.get("xp", 0))
	insignias_desbloqueadas.assign(datos.get("insignias", []))
	desempeno_por_categoria = datos.get("desempeno", {})
