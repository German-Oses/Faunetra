extends Node

## TriviaManager - Gestor de trivias adaptativas (DDA y Flow Theory)
## Carga el banco de trivias narrativas, gestiona el nivel de dificultad adaptativo del jugador,
## registra la retroalimentación formativa y administra las recompensas (XP e Insignias).

signal trivia_iniciada(trivia: TriviaData)
signal respuesta_evaluada(es_correcta: bool, retroalimentacion: String, recompensa_xp: int)
signal nivel_dificultad_cambiado(nuevo_nivel: TriviaData.Dificultad)

const RUTA_BANCO_JSON := "res://data/trivias/banco_trivias.json"

var trivias_cargadas: Array[TriviaData] = []
var nivel_actual_jugador: TriviaData.Dificultad = TriviaData.Dificultad.FACIL

# Métricas para Dynamic Difficulty Adaptivity (DDA - Chen 2006)
var racha_aciertos: int = 0
var racha_errores: int = 0
var total_trivias_respondidas: int = 0
var xp_acumulada: int = 0
var insignias_desbloqueadas: Array[String] = []

func _ready() -> void:
	cargar_banco_trivias()

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

## Selecciona una trivia de forma adaptativa para la especie o bioma solicitado
func obtener_trivia_adaptativa(id_especie: int = 0) -> TriviaData:
	var candidatas: Array[TriviaData] = []

	# Filtrar trivias que correspondan a la especie o bioma
	for t in trivias_cargadas:
		if id_especie == 0 or t.id_especie == id_especie:
			candidatas.append(t)

	if candidatas.is_empty():
		# Fallback: devolver cualquiera si no coincide especie específica
		candidatas = trivias_cargadas

	if candidatas.is_empty():
		return null

	# Filtrar por nivel de dificultad adaptativo
	var adaptadas: Array[TriviaData] = []
	for t in candidatas:
		if t.dificultad == nivel_actual_jugador:
			adaptadas.append(t)

	if not adaptadas.is_empty():
		return adaptadas.pick_random()
	
	# Si no hay del nivel exacto, devolver cualquiera de las candidatas
	return candidatas.pick_random()

## Evalúa la respuesta elegida y ajusta la curva de dificultad (DDA)
func responder_trivia(trivia: TriviaData, opcion: TriviaOption) -> void:
	total_trivias_respondidas += 1
	var es_correcta := opcion.es_correcta

	if es_correcta:
		racha_aciertos += 1
		racha_errores = 0
		xp_acumulada += trivia.recompensa_xp
		if trivia.insignia_id != "" and not insignias_desbloqueadas.has(trivia.insignia_id):
			insignias_desbloqueadas.append(trivia.insignia_id)
	else:
		racha_errores += 1
		racha_aciertos = 0

	_ajustar_dificultad_adaptativa()
	respuesta_evaluada.emit(es_correcta, opcion.retroalimentacion_narrativa, trivia.recompensa_xp if es_correcta else 0)

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
