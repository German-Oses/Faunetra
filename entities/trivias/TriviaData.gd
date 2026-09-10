class_name TriviaData
extends Resource

enum Dificultad { FACIL, MEDIO, DIFICIL }

@export var id_trivia: String = ""
@export var id_especie: int = 0
@export var nombre_especie: String = ""
@export var id_bioma: int = 0
@export var dificultad: Dificultad = Dificultad.FACIL

@export var titulo_narrativo: String = ""
@export_multiline var situacion_narrativa: String = ""
@export_multiline var pregunta: String = ""
@export_multiline var pista_narrativa: String = ""

@export var opciones: Array[TriviaOption] = []
@export var recompensa_xp: int = 50
@export var insignia_id: String = ""
