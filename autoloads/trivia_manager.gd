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

## Trivias ya respondidas en esta sesión, para no repetirlas mientras queden otras.
## Solo se marcan al responder: cerrar sin responder no permite saltarse una pregunta.
var _mostradas: Dictionary = {}
## Opciones incorrectas del banco agrupadas por su primera palabra ("porque", "para", "es"...),
## para completar con un distractor del mismo estilo las trivias que tengan menos opciones de las
## que pide el modo (Científico usa 4).
var _distractores_banco: Dictionary = {}


func _ready() -> void:
	cargar_banco_trivias()
	importar(GameState.datos_trivia)


func cargar_banco_trivias() -> void:
	trivias_cargadas.clear()
	_distractores_banco.clear()
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
			if not op.es_correcta and op.texto.strip_edges() != "":
				var clave := _primera_palabra(op.texto)
				if not _distractores_banco.has(clave):
					_distractores_banco[clave] = []
				_distractores_banco[clave].append({"op": op, "id_especie": trivia.id_especie})

		# En el JSON la opción correcta suele venir primero; el orden real se baraja
		# cada vez que la trivia se muestra (ver _preparar_para_mostrar).
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
		elegida = _preparar_para_mostrar(elegida)
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
		elegida = _preparar_para_mostrar(elegida)
		trivia_iniciada.emit(elegida)
	return elegida


## Copia de la trivia lista para mostrarse: ajusta la cantidad de opciones al modo de juego
## (una correcta + "distractores") y baraja su orden en cada presentación, para que la
## respuesta no se pueda memorizar por posición. El banco original no se modifica.
func _preparar_para_mostrar(base: TriviaData) -> TriviaData:
	var t: TriviaData = base.duplicate()
	var objetivo := int(GameState.ajuste("distractores")) + 1
	var correctas: Array[TriviaOption] = []
	var incorrectas: Array[TriviaOption] = []
	for op in base.opciones:
		if op.es_correcta:
			correctas.append(op)
		else:
			incorrectas.append(op)
	incorrectas.shuffle()
	var opciones: Array[TriviaOption] = []
	opciones.append_array(correctas)
	# Si el banco trae más opciones de las que pide el modo, se recortan distractores.
	for op in incorrectas:
		if opciones.size() >= objetivo:
			break
		opciones.append(op)
	# Si trae menos (p. ej. Científico pide 4 y el banco tiene 3), se completa con
	# distractores de otras trivias del banco del mismo estilo de respuesta.
	if opciones.size() < objetivo and correctas.size() == 1 and not base.id_trivia.begins_with("gen_"):
		for extra in _distractores_extra(base, opciones, objetivo - opciones.size()):
			opciones.append(extra)
	opciones.shuffle()
	t.opciones = opciones
	return t


## Distractores adicionales para una trivia del banco. Se toman solo opciones que el banco ya
## marca como incorrectas y que empiezan igual que alguna de sus opciones (mismo estilo:
## "Porque…", "Para…", "Es…"). Primero las de la misma especie (son afirmaciones falsas sobre
## ella); luego las de otras especies que no la mencionen, para no crear otra opción correcta.
func _distractores_extra(base: TriviaData, actuales: Array[TriviaOption], cantidad: int) -> Array[TriviaOption]:
	var correcta: TriviaOption = null
	var textos: Array[String] = []
	for op in actuales:
		textos.append(op.texto)
		if op.es_correcta:
			correcta = op
	var resultado: Array[TriviaOption] = []
	if correcta == null:
		return resultado
	var nombres: Array[String] = []
	for parte in base.nombre_especie.split("/"):
		if parte.strip_edges().length() >= 3:
			nombres.append(parte.strip_edges().to_lower())
	var claves: Array[String] = []
	for op in base.opciones:
		var clave := _primera_palabra(op.texto)
		if not claves.has(clave):
			claves.append(clave)
	var candidatos: Array = []
	for clave in claves:
		candidatos.append_array(_distractores_banco.get(clave, []))
	var misma: Array[TriviaOption] = []
	var otras: Array[TriviaOption] = []
	for item in candidatos:
		var op: TriviaOption = item["op"]
		if base.opciones.has(op) or textos.has(op.texto):
			continue
		if int(item["id_especie"]) == base.id_especie:
			misma.append(op)
		elif not nombres.any(func(n: String) -> bool: return op.texto.to_lower().contains(n)):
			# La retroalimentación original habla de otra pregunta: se reemplaza por una neutra.
			var copia := TriviaOption.new()
			copia.texto = op.texto
			copia.retroalimentacion_narrativa = "Esa opción no responde a esta pregunta. La respuesta correcta era: «%s»" % correcta.texto
			otras.append(copia)
	misma.shuffle()
	otras.shuffle()
	misma.append_array(otras)
	for op in misma:
		if resultado.size() >= cantidad:
			break
		resultado.append(op)
	return resultado


func _primera_palabra(texto: String) -> String:
	var limpio := texto.strip_edges().to_lower()
	var corte := limpio.find(" ")
	return limpio if corte < 0 else limpio.left(corte)


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
	# Recién al responder la trivia cuenta como vista (cerrar sin responder la deja disponible).
	if not es_repaso:
		_mostradas[trivia.id_trivia] = true
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
		pr = pr_por_acierto(trivia, es_repaso, bool(meta.get("uso_pista", false)) and not apoyo)
		GameState.agregar_pr(pr)
		# Resolver una pista conceptual sobre una especie la registra en la Biopedia.
		descubierta = GameState.descubrir_especie(EspecieLoader.por_id(trivia.id_especie))
	else:
		racha_errores += 1
		racha_aciertos = 0
		reg["errores"] = int(reg.get("errores", 0)) + 1
	desempeno_por_categoria[categoria] = reg

	var rapido: bool = es_repaso and GameState.es_repaso_rapido(trivia.id_especie)
	if es_repaso:
		GameState.registrar_repaso(trivia.id_especie, es_correcta)
	GameState.registrar({
		"tipo": ("repaso_rapido" if rapido else "repaso") if es_repaso else "trivia",
		"id_bioma": trivia.id_bioma, "id_especie": trivia.id_especie, "especie": trivia.nombre_especie,
		"id_trivia": trivia.id_trivia, "dificultad": NOMBRES_DIFICULTAD[trivia.dificultad],
		"modo": meta.get("modo", ""), "correcta": es_correcta, "tiempo_s": snappedf(float(meta.get("tiempo_s", 0.0)), 0.1),
		"uso_pista": bool(meta.get("uso_pista", false)), "apoyo_tutor": apoyo,
		"nivel_dda": NOMBRES_DIFICULTAD[nivel_antes], "pr": pr,
		# Apoyos visibles al responder: separan aciertos asistidos de la recuperación autónoma.
		"ficha_visible": bool(meta.get("ficha_visible", false)), "imagen_apoyo": bool(meta.get("imagen_apoyo", false)),
	})

	_ajustar_dificultad_adaptativa()
	GameState.marcar_cambios()
	respuesta_evaluada.emit(es_correcta, opcion.retroalimentacion_narrativa, xp)
	return {"correcta": es_correcta, "pr": pr, "xp": xp, "descubierta": descubierta, "rapido": rapido}


## PR de un acierto. En el modo Científico, pedir la pista reduce la recompensa
## (salvo cuando la ofrece el tutor por detectar dificultades).
func pr_por_acierto(trivia: TriviaData, es_repaso: bool, pidio_pista: bool) -> int:
	var pr := PR_POR_DIFICULTAD[trivia.dificultad]
	if pidio_pista:
		pr = roundi(pr * float(GameState.ajuste("pr_con_pista")))
	return pr + (PR_BONO_REPASO if es_repaso else 0)


## Algoritmo DDA (Dynamic Difficulty Adaptivity - Chen 2006). El modo de juego fija
## cuántos aciertos seguidos hacen falta para subir de nivel.
func _ajustar_dificultad_adaptativa() -> void:
	if racha_aciertos >= int(GameState.ajuste("racha_para_subir")) and nivel_actual_jugador < TriviaData.Dificultad.DIFICIL:
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
	var cantidad := int(GameState.ajuste("distractores"))
	var bioma: String = GameState.nombre_bioma(data.id_bioma)
	match nivel:
		TriviaData.Dificultad.FACIL:
			t.titulo_narrativo = "Reconocimiento en terreno"
			t.situacion_narrativa = "Tu Tableta de Campo detecta una especie de %s. Su ficha dice: «%s»" % [bioma, data.rol_ecologico]
			t.pregunta = "¿Qué especie tiene el nombre científico %s?" % data.nombre_cientifico
			t.pista_narrativa = "Es de tipo «%s» y su estado de conservación es %s." % [data.tipo, _estado(data)]
			correcta = data.nombre_comun
			distractores = _valores(otras, func(d: EspecieData) -> String: return d.nombre_comun, correcta, cantidad)
		TriviaData.Dificultad.MEDIO:
			t.titulo_narrativo = "Nomenclatura científica"
			t.situacion_narrativa = "Para registrar tu avistamiento de %s en la Biopedia necesitas su nombre científico." % data.nombre_comun
			t.pregunta = "¿Cuál es el nombre científico de %s?" % data.nombre_comun
			t.pista_narrativa = "Su nombre científico comienza con «%s…»." % data.nombre_cientifico.left(3)
			correcta = data.nombre_cientifico
			distractores = _valores(otras, func(d: EspecieData) -> String: return d.nombre_cientifico, correcta, cantidad)
		_:
			t.titulo_narrativo = "Rol en la trama ecológica"
			t.situacion_narrativa = "Observas a %s interactuar con su entorno en %s." % [data.nombre_comun, bioma]
			t.pregunta = "¿Qué rol ecológico cumple %s en su ecosistema?" % data.nombre_comun
			t.pista_narrativa = "Es de tipo «%s» y está clasificada como %s." % [data.tipo, _estado(data)]
			correcta = data.rol_ecologico
			distractores = _valores(otras, func(d: EspecieData) -> String: return d.rol_ecologico, correcta, cantidad)

	if distractores.is_empty():
		# Sin especies suficientes para distractores: preguntamos por el tipo de organismo.
		t.pregunta = "¿Qué tipo de organismo es %s?" % data.nombre_comun
		correcta = data.tipo
		for tipo in ["vertebrado", "ave", "planta", "hongo", "invertebrado"]:
			if tipo != correcta and distractores.size() < cantidad:
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


func _valores(especies: Array[EspecieData], campo: Callable, excluir: String, cantidad: int) -> Array[String]:
	var resultado: Array[String] = []
	for d in especies:
		var valor: String = campo.call(d)
		if valor.strip_edges() == "" or valor == excluir or resultado.has(valor):
			continue
		resultado.append(valor)
		if resultado.size() >= cantidad:
			break
	return resultado


func _estado(data: EspecieData) -> String:
	return "%s (%s)" % [EspecieData.NOMBRES_ESTADO.get(data.estado_conservacion, "sin evaluar"), data.estado_conservacion]


# --- Persistencia ---------------------------------------------------------------------

func reiniciar() -> void:
	nivel_actual_jugador = int(GameState.ajuste("nivel_inicial_dda")) as TriviaData.Dificultad
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


## GameState ya valida la forma del guardado; aquí, además, cada campo se lee con su tipo y un
## valor por defecto, para que un dato extraño nunca deje al gestor a medio importar.
func importar(datos: Dictionary) -> void:
	if datos.is_empty():
		return
	nivel_actual_jugador = clampi(_entero(datos, "nivel"), 0, TriviaData.Dificultad.DIFICIL) as TriviaData.Dificultad
	racha_aciertos = maxi(0, _entero(datos, "racha_aciertos"))
	racha_errores = maxi(0, _entero(datos, "racha_errores"))
	total_trivias_respondidas = maxi(0, _entero(datos, "total"))
	xp_acumulada = maxi(0, _entero(datos, "xp"))
	var insignias = datos.get("insignias", [])
	insignias_desbloqueadas.assign((insignias as Array).filter(func(i) -> bool: return i is String) if insignias is Array else [])
	var desempeno = datos.get("desempeno", {})
	desempeno_por_categoria = desempeno if desempeno is Dictionary else {}


func _entero(datos: Dictionary, clave: String) -> int:
	var v = datos.get(clave, 0)
	return int(v) if (v is int or v is float) else 0
