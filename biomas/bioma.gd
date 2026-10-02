class_name Bioma
extends Node2D

## Base de todos los biomas. Cada escena de bioma tiene un TileMapLayer isométrico y un nodo
## "Especies"; aquí se monta el TerrenoRefugio (grilla interactiva) y la cámara.
## Las especies ya no aparecen solas: la flora la planta el jugador y la fauna llega
## cuando el refugio cumple sus requisitos (ver data/ecosistema/reglas_ecosistema.json).

const ZOOM_MIN := 0.4
const ZOOM_MAX := 3.0
## Espacio de pantalla que ocupan las barras del HUD (arriba y abajo).
const MARGEN_HUD_SUPERIOR := 56.0
const MARGEN_HUD_INFERIOR := 120.0

var id_bioma: int = -1
## Si es true, el mapa se arma con GeneradorMapa (río, montañas, caseta…) en lugar del
## TileMapLayer dibujado a mano en la escena.
@export var generar_mapa := true
var terreno: TerrenoRefugio
var camara: Camera2D

@onready var contenedor_especies: Node2D = $Especies

var _arrastrando := false


func _ready() -> void:
	GameState.bioma_actual_id = id_bioma
	GameState.especie_para_plantar = null
	get_viewport().physics_object_picking = true

	var tilemap := _buscar_tilemap()
	if tilemap == null:
		push_error("El bioma %d no tiene TileMapLayer." % id_bioma)
		return
	_crear_fondo()
	var mapa: Dictionary = {}
	if generar_mapa:
		mapa = GeneradorMapa.generar(id_bioma, tilemap, contenedor_especies)
	terreno = TerrenoRefugio.new()
	terreno.name = "TerrenoRefugio"
	add_child(terreno)
	terreno.configurar(id_bioma, tilemap, contenedor_especies, mapa)
	_configurar_camara()
	EventBus.bioma_cargado.emit(id_bioma)


## Fondo de cielo y tierra lejana, para que el mapa y la cordillera no floten en el vacío.
const COLORES_FONDO := {
	1: [Color("#A4D4EC"), Color("#F2EAD0"), Color("#B8A65A"), Color("#8E7A38")],
	2: [Color("#8FC8E8"), Color("#F2E2C2"), Color("#D4A672"), Color("#A8784A")],
	3: [Color("#9FD3E6"), Color("#D8EEE8"), Color("#4E7E46"), Color("#2E5230")],
	4: [Color("#B4D8EC"), Color("#E8F0F4"), Color("#7E9A6E"), Color("#5A6E52")],
	5: [Color("#8ECFEA"), Color("#E6F6F4"), Color("#3A9AC0"), Color("#1E6A8E")],
}


func _crear_fondo() -> void:
	var colores: Array = COLORES_FONDO.get(id_bioma, COLORES_FONDO[3])
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.3, 0.42, 1.0])
	degradado.colors = PackedColorArray(colores)
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)
	var capa := CanvasLayer.new()
	capa.layer = -10
	add_child(capa)
	var rect := TextureRect.new()
	rect.texture = textura
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(rect)


func _buscar_tilemap() -> TileMapLayer:
	for hijo in get_children():
		if hijo is TileMapLayer:
			return hijo
	return null


func _configurar_camara() -> void:
	camara = Camera2D.new()
	add_child(camara)
	var rect := terreno.rect_global()
	var vista := get_viewport_rect().size
	var alto_util := maxf(100.0, vista.y - MARGEN_HUD_SUPERIOR - MARGEN_HUD_INFERIOR)
	var zoom := clampf(minf(vista.x / rect.size.x, alto_util / rect.size.y), ZOOM_MIN, ZOOM_MAX)
	camara.zoom = Vector2(zoom, zoom)
	# Desplazamos el encuadre para compensar que el HUD inferior es más alto que el superior.
	camara.global_position = rect.get_center() + Vector2(0, (MARGEN_HUD_INFERIOR - MARGEN_HUD_SUPERIOR) * 0.5 / zoom)
	camara.make_current()


## Rueda del mouse: zoom. Botón derecho o central arrastrando: mover la cámara.
func _unhandled_input(event: InputEvent) -> void:
	if camara == null:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.0 / 1.1)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_arrastrando = event.pressed
	elif event is InputEventMouseMotion and _arrastrando:
		camara.position -= event.relative / camara.zoom


func _zoom(factor: float) -> void:
	var nuevo := clampf(camara.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	camara.zoom = Vector2(nuevo, nuevo)
