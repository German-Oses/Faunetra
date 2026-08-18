class_name EspecieData
extends Resource

@export var id_especie: int
@export var nombre_cientifico: String
@export var nombre_comun: String
@export_enum("vertebrado", "ave", "planta", "hongo", "invertebrado") var tipo: String
@export_enum("CR", "EN", "VU", "NT", "LC", "EW", "EX") var estado_conservacion: String
@export_multiline var rol_ecologico: String
@export var umbral_desbloqueo: int = 0
@export var id_bioma: int
@export var textura: Texture2D
@export var audio_canto: AudioStream
