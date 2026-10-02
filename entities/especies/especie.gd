class_name especie 
extends Node2D

signal especie_tocada(data: EspecieData)

const COLOR_MARCHITA := Color(0.62, 0.48, 0.3)
const ESCALA_BROTE := 0.3
const ESCALA_ADULTA := 0.75

@export var data: EspecieData:
	set(value):
		data = value
		_actualizar_visual()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D
@onready var colision: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	area.input_event.connect(_on_input_event)
	_actualizar_visual()


## Refleja en pantalla el crecimiento (0..1) y si la planta está marchita.
func aplicar_estado_planta(crecimiento: float, marchita: bool) -> void:
	scale = Vector2.ONE * lerpf(ESCALA_BROTE, ESCALA_ADULTA, clampf(crecimiento, 0.0, 1.0))
	if sprite:
		sprite.modulate = COLOR_MARCHITA if marchita else Color.WHITE


func interactuar() -> void:
	EventBus.especie_seleccionada.emit(data)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interactuar()


func _actualizar_visual() -> void:
	if data == null or sprite == null:
		return
	# Las especies con escena propia configuran su sprite y colisión en esa escena.
	if data.escena != null:
		return
	var frames := SpriteFrames.new()
	if data.textura:
		frames.add_frame("default", data.textura)
		sprite.scale = data.escala
	else:
		# Sin arte todavía: cuadro de color según el tipo, para que se vea y se pueda clickear.
		frames.add_frame("default", _generar_textura_placeholder())
		sprite.scale = Vector2(0.5, 0.5)
		modulate = _color_placeholder_por_tipo(data.tipo)
	sprite.sprite_frames = frames
	area.scale = Vector2(2.0, 2.0) # To ensure it's clickable


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
