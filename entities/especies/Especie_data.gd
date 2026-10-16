class_name EspecieData
extends Resource

const NOMBRES_ESTADO := {
	"CR": "En Peligro Crítico",
	"EN": "En Peligro",
	"VU": "Vulnerable",
	"NT": "Casi Amenazada",
	"LC": "Preocupación Menor",
	"EW": "Extinta en Estado Silvestre",
	"EX": "Extinta",
}

@export var id_especie: int
@export var nombre_cientifico: String
@export var nombre_comun: String
@export_enum("vertebrado", "ave", "planta", "hongo", "invertebrado") var tipo: String
@export_enum("CR", "EN", "VU", "NT", "LC", "EW", "EX") var estado_conservacion: String
@export_multiline var rol_ecologico: String
@export var umbral_desbloqueo: int = 0
@export var id_bioma: int
@export var textura: Texture2D
@export var escala: Vector2 = Vector2(0.1, 0.1)
## Escena propia (heredada de especie.tscn) para especies animadas. Si está vacía se usa el molde genérico con la textura.
@export var escena: PackedScene
@export var audio_canto: AudioStream
## Grupo biológico de la fauna, asignado por taxonomía (no se deduce del nombre ni del rol, que
## mencionan presas y otras especies). Define la firma del sonido simulado y qué animales se
## parecen entre sí en los minijuegos. Vacío en flora y hongos. Valores en GRUPOS.
@export var grupo: String = ""

## Grupos biológicos válidos de la fauna (ver `grupo`).
const GRUPOS: Array[String] = ["ave", "mamifero", "mamifero_marino", "anfibio", "reptil", "reptil_marino",
	"insecto", "aracnido", "crustaceo", "caracol_acuatico", "caracol_terrestre"]
