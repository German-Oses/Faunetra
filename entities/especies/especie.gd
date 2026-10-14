class_name especie 
extends Node2D

signal especie_tocada(data: EspecieData)

const COLOR_MARCHITA := Color(0.62, 0.48, 0.3)
const ESCALA_BROTE := 0.3
const ESCALA_ADULTA := 0.75
## Etapas de crecimiento de las plantas: brote, plántula y joven tienen dibujo propio
## (Assets/Plantas/etapas/, ver herramientas/aseprite/plantas_etapas.lua), siempre a la escala de
## la adulta para que el píxel mida lo mismo; la adulta es el sprite animado de la especie.
## Límites de cada etapa (fracción de crecimiento):
enum Etapa { BROTE, PLANTULA, JOVEN, ADULTA }
const HASTA_BROTE := 0.25
const HASTA_PLANTULA := 0.6
## Solo si la especie no tiene dibujo joven: el adulto achicado, al entrar y al salir de la etapa.
const ESCALA_JOVEN_SIN_DIBUJO := Vector2(0.45, 0.65)
const RUTA_ETAPAS := "res://Assets/Plantas/etapas/%s_%s.png"
## Una planta marchita se inclina y se aplasta un poco, además de perder color.
const INCLINACION_MARCHITA := 0.14

@export var data: EspecieData:
	set(value):
		data = value
		_actualizar_visual()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D
@onready var colision: CollisionShape2D = $Area2D/CollisionShape2D

var _etapa := -1
var _texturas_etapa: Array[Texture2D] = []   # [brote, plántula, joven?] o vacío si la especie no tiene
var _alto_especie := 32.0
var _sprite_etapa: Sprite2D
var _escala_sprite := Vector2.ONE
var _marcador: Node2D


func _ready() -> void:
	area.input_event.connect(_on_input_event)
	_actualizar_visual()


## Refleja en pantalla el crecimiento (0..1) y si la planta está marchita.
func aplicar_estado_planta(crecimiento: float, marchita: bool) -> void:
	crecimiento = clampf(crecimiento, 0.0, 1.0)
	if not _preparar_etapas():
		# Sin dibujos de etapas: la especie solo crece de tamaño.
		scale = Vector2.ONE * lerpf(ESCALA_BROTE, ESCALA_ADULTA, crecimiento)
		if sprite:
			sprite.modulate = COLOR_MARCHITA if marchita else Color.WHITE
		return
	var etapa := Etapa.ADULTA
	if crecimiento < HASTA_BROTE:
		etapa = Etapa.BROTE
	elif crecimiento < HASTA_PLANTULA:
		etapa = Etapa.PLANTULA
	elif crecimiento < 1.0:
		etapa = Etapa.JOVEN
	var dibujada := etapa < _texturas_etapa.size()
	if etapa == Etapa.JOVEN and not dibujada:
		var t := (crecimiento - HASTA_PLANTULA) / (1.0 - HASTA_PLANTULA)
		scale = Vector2.ONE * lerpf(ESCALA_JOVEN_SIN_DIBUJO.x, ESCALA_JOVEN_SIN_DIBUJO.y, t)
	else:
		scale = Vector2.ONE * ESCALA_ADULTA
	if etapa != _etapa:
		var anterior := _etapa
		_etapa = etapa
		_sprite_etapa.visible = dibujada
		sprite.visible = not dibujada
		if dibujada:
			_mostrar_dibujo_etapa(_texturas_etapa[etapa])
		if anterior >= 0 and etapa > anterior:
			_celebrar_etapa()
	var visual: CanvasItem = _sprite_etapa if _sprite_etapa.visible else sprite
	visual.modulate = COLOR_MARCHITA if marchita else Color.WHITE
	_inclinar(marchita)


## La planta marchita se inclina desde el pie: como los sprites están centrados, se corre su
## posición para que la base no se mueva al girar.
func _inclinar(marchita: bool) -> void:
	var angulo := INCLINACION_MARCHITA if marchita else 0.0
	for s: Node2D in [sprite, _sprite_etapa]:
		if is_equal_approx(s.rotation, angulo):
			continue
		var base: Vector2 = s.get_meta("posicion_base", s.position)
		s.set_meta("posicion_base", base)
		var tex_alto := _alto_especie
		if s == _sprite_etapa and _sprite_etapa.texture:
			tex_alto = float(_sprite_etapa.texture.get_height())
		var mitad := tex_alto * 0.5 * _escala_sprite.y
		s.rotation = angulo
		s.position = base + Vector2(sin(angulo) * mitad, mitad - cos(angulo) * mitad)


## Busca los dibujos de etapas de la especie y crea el sprite que los muestra. Brote y plántula
## son obligatorios; la joven es opcional (sin ella se usa el adulto achicado).
func _preparar_etapas() -> bool:
	if _sprite_etapa:
		return true
	if sprite == null or sprite.sprite_frames == null or not _texturas_etapa.is_empty():
		return false
	var nombre := sprite.sprite_frames.resource_path.get_file().get_basename()
	for etapa in ["brote", "plantula", "joven"]:
		var ruta := RUTA_ETAPAS % [nombre, etapa]
		if not ResourceLoader.exists(ruta):
			if etapa == "joven":
				break
			_texturas_etapa.clear()
			return false
		_texturas_etapa.append(load(ruta))
	_escala_sprite = sprite.scale
	_sprite_etapa = Sprite2D.new()
	_sprite_etapa.name = "Etapa"
	_sprite_etapa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_etapa.scale = sprite.scale
	var cuadro := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	_alto_especie = float(cuadro.get_height()) if cuadro else 32.0
	add_child(_sprite_etapa)
	move_child(_sprite_etapa, sprite.get_index() + 1)
	return true


## Cambia el dibujo de la etapa apoyándolo en el mismo pie que el sprite de la especie
## (ambos están centrados y pueden medir distinto: 32 px las etapas tempranas, lo mismo que la
## especie la joven). La inclinación de marchita se recalcula desde esa posición.
func _mostrar_dibujo_etapa(textura: Texture2D) -> void:
	_sprite_etapa.texture = textura
	_sprite_etapa.rotation = 0.0
	_sprite_etapa.remove_meta("posicion_base")
	var pie: Vector2 = sprite.get_meta("posicion_base", sprite.position)   # sin la inclinación del adulto
	_sprite_etapa.position = pie + Vector2(0, (_alto_especie - textura.get_height()) * 0.5 * _escala_sprite.y)


## Al pasar a una etapa mayor: un pequeño estirón y unas hojitas que saltan.
func _celebrar_etapa() -> void:
	var visual: Node2D = _sprite_etapa if _sprite_etapa.visible else sprite
	var base := _escala_sprite
	visual.scale = base * Vector2(1.25, 0.75)
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", base, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hojas := CPUParticles2D.new()
	hojas.one_shot = true
	hojas.emitting = true
	hojas.amount = 8
	hojas.lifetime = 0.8
	hojas.explosiveness = 1.0
	hojas.direction = Vector2(0, -1)
	hojas.spread = 70.0
	hojas.gravity = Vector2(0, 120)
	hojas.initial_velocity_min = 50.0
	hojas.initial_velocity_max = 90.0
	hojas.scale_amount_min = 2.0
	hojas.scale_amount_max = 3.0
	hojas.color = Color("#7DBE5A")
	hojas.position = _sprite_etapa.position + Vector2(0, 8 * _escala_sprite.y)
	add_child(hojas)
	hojas.finished.connect(hojas.queue_free)


func interactuar() -> void:
	# Un animal recién llegado se identifica antes de conocer su ficha.
	if _marcador:
		EventBus.identificacion_solicitada.emit(data)
		return
	EventBus.especie_seleccionada.emit(data)


## Burbuja con «?» sobre un animal que llegó al refugio y aún no se identifica.
func marcar_sin_identificar(activo: bool) -> void:
	if not activo:
		if _marcador:
			_marcador.queue_free()
			_marcador = null
		return
	if _marcador:
		return
	_marcador = Node2D.new()
	_marcador.name = "SinIdentificar"
	_marcador.z_index = 5
	var alto := 32.0
	if sprite and sprite.sprite_frames:
		var cuadro := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if cuadro:
			alto = cuadro.get_height() * sprite.scale.y
	_marcador.position = Vector2(0, -alto * 0.5 - 18)
	_marcador.draw.connect(func() -> void:
		_marcador.draw_circle(Vector2.ZERO, 15, Color("#2E5A3A"))
		_marcador.draw_circle(Vector2.ZERO, 12, Color("#F6F0DC"))
		var fuente := ThemeDB.fallback_font
		_marcador.draw_string(fuente, Vector2(-6, 8), "?", HORIZONTAL_ALIGNMENT_CENTER, 12, 22, Color("#2E5A3A")))
	add_child(_marcador)
	var tween := _marcador.create_tween().set_loops()
	tween.tween_property(_marcador, "position:y", _marcador.position.y - 6, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_marcador, "position:y", _marcador.position.y, 0.5).set_trans(Tween.TRANS_SINE)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not Bioma.arrastrando:
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
