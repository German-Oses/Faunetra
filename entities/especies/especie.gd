class_name especie 
extends Node2D

signal especie_tocada(data: EspecieData)

@export var data: EspecieData:
	set(value):
		data = value
		_actualizar_visual()

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D


func _ready() -> void:
	area.input_event.connect(_on_input_event)
	_actualizar_visual()


func interactuar() -> void:
	especie_tocada.emit(data)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interactuar()


func _actualizar_visual() -> void:
	if data == null:
		return
	if data.textura:
		sprite.texture = data.textura
		
	else:
		
		modulate = _color_placeholder_por_tipo(data.tipo)


func _generar_textura_placeholder() -> ImageTexture:
	var imagen:= Image.create(64, 64, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.WHITE)
	return ImageTexture.create_from_image(imagen)

func _color_placeholder_por_tipo(tipo: String) -> Color:
	match tipo:
		"vertebrado": return Color.LIGHT_GREEN
		"ave": return Color.SKY_BLUE
		"planta": return Color.FOREST_GREEN
		"hongo": return Color.SANDY_BROWN
		"invertebrado": return Color.ORANGE
		_: return Color.WHITE
