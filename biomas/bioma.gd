class_name Bioma
extends Node2D

## Base de todos los biomas. Cada escena de bioma tiene un TileMapLayer isométrico y un nodo
## "Especies"; aquí se monta el TerrenoRefugio (grilla interactiva) y la cámara.
## Las especies ya no aparecen solas: la flora la planta el jugador y la fauna llega
## cuando el refugio cumple sus requisitos (ver data/ecosistema/reglas_ecosistema.json).

const ZOOM_MIN := 0.4
const ZOOM_MAX := 3.0
## Espacio de pantalla que ocupan las barras del HUD (arriba y abajo), en horizontal y en
## vertical (en vertical la barra superior tiene dos filas y las herramientas son más altas).
const MARGEN_HUD_SUPERIOR := 56.0
const MARGEN_HUD_INFERIOR := 120.0
const MARGEN_HUD_SUPERIOR_VERTICAL := 92.0
const MARGEN_HUD_INFERIOR_VERTICAL := 140.0
## Al entrar, la cámara encuadra el claro y su entorno (radio en parcelas), no el mapa completo:
## el paisaje llena la pantalla y se puede alejar con la rueda o pellizcando.
## En un teléfono vertical el encuadre es más estrecho para que las parcelas no queden diminutas.
const RADIO_VISTA_INICIAL := 5
const RADIO_VISTA_INICIAL_VERTICAL := 4

var id_bioma: int = -1
## Si es true, el mapa se arma con GeneradorMapa (río, montañas, caseta…) en lugar del
## TileMapLayer dibujado a mano en la escena.
@export var generar_mapa := true
var terreno: TerrenoRefugio
var camara: Camera2D

@onready var contenedor_especies: Node2D = $Especies

var _arrastrando := false
## Marca compartida: true mientras el gesto actual es un arrastre o pellizco (no un toque).
static var arrastrando := false
## Cuánto hay que moverse (px de pantalla) para que el gesto deje de ser un toque y pase a mover
## la cámara. El dedo tiembla más que el mouse: con el mismo umbral, tocar una parcela movía el
## mapa o el arrastre se volvía una acción sin querer.
const UMBRAL_ARRASTRE := 8.0
const UMBRAL_ARRASTRE_TACTIL := 22.0
## Zoom por muesca de la rueda (se aplica una vez por muesca, al presionar).
const PASO_ZOOM_RUEDA := 1.15
## Desplazamiento por evento del gesto de dos dedos del trackpad.
const VELOCIDAD_PAN_TRACKPAD := 8.0
var _boton_izquierdo := false
var _inicio_presion := Vector2.ZERO
var _umbral_actual := UMBRAL_ARRASTRE
var _toques: Dictionary = {}       # índice del dedo -> posición
var _distancia_pellizco := 0.0
var _centro_pellizco := Vector2.ZERO


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
	if generar_mapa:
		var paisaje := PaisajeVivo.new()
		paisaje.name = "PaisajeVivo"
		add_child(paisaje)
		paisaje.configurar(id_bioma, tilemap, mapa)
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
	_encuadrar()
	camara.make_current()
	# Al girar el teléfono cambia el área visible: se vuelve a encuadrar el claro.
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _encuadrar.call_deferred())


func _encuadrar() -> void:
	var vertical := Pantalla.vertical
	var arriba := MARGEN_HUD_SUPERIOR_VERTICAL if vertical else MARGEN_HUD_SUPERIOR
	var abajo := MARGEN_HUD_INFERIOR_VERTICAL if vertical else MARGEN_HUD_INFERIOR
	var radio := RADIO_VISTA_INICIAL_VERTICAL if vertical else RADIO_VISTA_INICIAL
	var tilemap := terreno.tilemap
	var tam := Vector2(tilemap.tile_set.tile_size) * (radio * 2 + 1)
	var rect := Rect2(tilemap.to_global(tilemap.map_to_local(Vector2i.ZERO)) - tam * 0.5, tam)
	var vista := get_viewport_rect().size
	var alto_util := maxf(100.0, vista.y - arriba - abajo)
	var zoom := clampf(minf(vista.x / rect.size.x, alto_util / rect.size.y), ZOOM_MIN, ZOOM_MAX)
	camara.zoom = Vector2(zoom, zoom)
	# Desplazamos el encuadre para compensar que el HUD inferior es más alto que el superior.
	camara.global_position = rect.get_center() + Vector2(0, (abajo - arriba) * 0.5 / zoom)


## Controles de cámara para mouse, trackpad y pantallas táctiles:
## - Arrastrar con un dedo o con el botón izquierdo (también derecho/central) mueve la cámara.
## - Pellizcar con dos dedos, la rueda del mouse o el gesto de pellizco del trackpad hacen zoom
##   hacia el punto que se señala (los dedos o el cursor), no hacia el centro de la pantalla.
##   Mientras se pellizca, mover los dos dedos también desplaza el mapa.
## Un toque solo cuenta como "clic" si no hubo arrastre (ver Bioma.arrastrando); el umbral es más
## amplio para el dedo (los eventos emulados desde el táctil traen DEVICE_ID_EMULATION).
## Soltar un botón o levantar un dedo se atiende aquí, antes que la interfaz y el terreno: si no,
## cuando el terreno usaba una herramienta (o el botón se soltaba sobre el HUD) se quedaba con el
## evento, la cámara creía que el botón seguía apretado y el mapa quedaba "agarrado" al mouse.
## Presionar sí se atiende en _unhandled_input, para que tocar un botón del HUD no mueva el mapa.
func _input(event: InputEvent) -> void:
	if camara == null:
		return
	if event is InputEventScreenTouch and not event.pressed:
		_toques.erase(event.index)
		if _toques.is_empty():
			_terminar_arrastre.call_deferred()
	elif event is InputEventMouseButton and not event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_arrastrando = false
			MOUSE_BUTTON_LEFT:
				_boton_izquierdo = false
				# Se limpia al final del cuadro: el terreno y las especies leen la marca al soltar.
				_terminar_arrastre.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if camara == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_toques[event.index] = event.position
		if _toques.size() >= 2:
			arrastrando = true
			_distancia_pellizco = _distancia_entre_toques()
			_centro_pellizco = _centro_toques()
	elif event is InputEventScreenDrag:
		_toques[event.index] = event.position
		if _toques.size() >= 2:
			var d := _distancia_entre_toques()
			var centro := _centro_toques()
			if _distancia_pellizco > 0.0:
				_mover(-(centro - _centro_pellizco) / camara.zoom)
				_zoom(d / _distancia_pellizco, centro)
			_distancia_pellizco = d
			_centro_pellizco = centro
	elif event is InputEventMagnifyGesture:
		_zoom(event.factor, event.position)
	elif event is InputEventPanGesture:
		_mover(event.delta * VELOCIDAD_PAN_TRACKPAD / camara.zoom.x)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(PASO_ZOOM_RUEDA, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(1.0 / PASO_ZOOM_RUEDA, event.position)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_arrastrando = true
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_boton_izquierdo = true
					_inicio_presion = event.position
					_umbral_actual = UMBRAL_ARRASTRE_TACTIL if event.device == InputEvent.DEVICE_ID_EMULATION \
						else UMBRAL_ARRASTRE
					arrastrando = false
	elif event is InputEventMouseMotion:
		# Si el botón se soltó encima del HUD (o fuera de la ventana), ese evento se lo queda la
		# interfaz y no llega aquí: el mapa quedaba "agarrado" siguiendo al mouse. Cada movimiento
		# trae el estado real de los botones, así que se corrige con él.
		if _boton_izquierdo and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_soltar_mouse()
		if _arrastrando and not (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
			_arrastrando = false
		if _arrastrando:
			_mover(-event.relative / camara.zoom)
		elif _boton_izquierdo and _toques.size() < 2:
			if not arrastrando and event.position.distance_to(_inicio_presion) > _umbral_actual:
				arrastrando = true
			if arrastrando:
				_mover(-event.relative / camara.zoom)


## Al perder el foco o salir el mouse de la ventana no llega el evento de soltar: se suelta todo.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_soltar_mouse()
		_arrastrando = false
		_toques.clear()


func _soltar_mouse() -> void:
	_boton_izquierdo = false
	arrastrando = false
	_distancia_pellizco = 0.0


func _terminar_arrastre() -> void:
	if _toques.size() < 2:
		arrastrando = false
		_distancia_pellizco = 0.0


func _distancia_entre_toques() -> float:
	var puntos := _toques.values()
	return (puntos[0] as Vector2).distance_to(puntos[1])


func _centro_toques() -> Vector2:
	var puntos := _toques.values()
	return ((puntos[0] as Vector2) + (puntos[1] as Vector2)) * 0.5


## Mueve la cámara sin dejar que el refugio salga de la pantalla.
func _mover(desplazamiento: Vector2) -> void:
	var limite := terreno.rect_global().grow(200) if terreno else Rect2(camara.position - Vector2.ONE * 2000, Vector2.ONE * 4000)
	camara.position = (camara.position + desplazamiento).clamp(limite.position, limite.end)


## Zoom manteniendo fijo el punto del mundo que está bajo `foco` (posición de pantalla); sin foco,
## hacia el centro de la pantalla.
func _zoom(factor: float, foco := Vector2(-1, -1)) -> void:
	var antes := camara.zoom.x
	var nuevo := clampf(antes * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(nuevo, antes):
		return
	camara.zoom = Vector2(nuevo, nuevo)
	if foco.x < 0.0:
		return
	var desde_centro := foco - get_viewport_rect().size * 0.5
	_mover(desde_centro / antes - desde_centro / nuevo)
