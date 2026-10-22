extends VBoxContainer

## Rompecabezas de especies: la imagen de una especie nativa sobre el paisaje de su bioma, cortada
## en piezas desordenadas. Se juega tocando dos piezas para intercambiarlas (cómodo en celular y
## con mouse). Al completarlo se muestra su ficha: nombre común, nombre científico y rol ecológico.
## El tamaño depende del modo: Explorador 3×3, Guardaparques 4×4 y Científico 5×5.
##
## Recompensa: armar por primera vez (en la sesión) una especie da RECOMPENSA_PR[lado]; repetirla
## da RECOMPENSA_REPETIDA, para que no convenga armar siempre la misma.

const LADO_POR_MODO := {"explorador": 3, "guardaparques": 4, "cientifico": 5}
const RECOMPENSA_PR := {3: 20, 4: 30, 5: 40}
const RECOMPENSA_REPETIDA := 5
## Px de cada pieza en la imagen armada (el dibujo se escala con filtro nítido al mostrarse).
const PX_PIEZA := 32
const COLOR_ELEGIDA := Color(1.25, 1.25, 0.8)

var _instrucciones: Label
var _tablero: GridContainer
var _resultado: Label
var _objetivo: EspecieData
var _textura: ImageTexture
var _lado := 3
## _orden[casilla] = pieza que hay en esa casilla; está resuelto cuando _orden[i] == i.
var _orden: Array[int] = []
var _elegida := -1
var _movimientos := 0
var _resuelto := false
var _inicio_ms := 0
## Especies ya armadas en esta sesión (id_especie -> true).
var _armadas: Dictionary = {}


func _ready() -> void:
	name = "Rompecabezas"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_instrucciones = Label.new()
	_instrucciones.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_instrucciones)

	# El tablero es cuadrado y ocupa el espacio disponible.
	var marco := AspectRatioContainer.new()
	marco.ratio = 1.0
	marco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(marco)
	_tablero = GridContainer.new()
	_tablero.add_theme_constant_override("h_separation", 2)
	_tablero.add_theme_constant_override("v_separation", 2)
	marco.add_child(_tablero)

	_resultado = Label.new()
	_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_resultado)

	var nuevo := Button.new()
	nuevo.text = "Nuevo rompecabezas"
	nuevo.size_flags_horizontal = Control.SIZE_SHRINK_END
	nuevo.pressed.connect(nueva_ronda)
	add_child(nuevo)


## Al abrir: conserva el rompecabezas en curso y solo empieza otro si no hay uno pendiente.
func al_mostrar() -> void:
	if _objetivo == null or _resuelto:
		nueva_ronda()


func nueva_ronda() -> void:
	_lado = LADO_POR_MODO.get(GameState.modo, 4)
	_objetivo = _elegir_especie()
	_resultado.text = ""
	_resuelto = false
	_elegida = -1
	_movimientos = 0
	if _objetivo == null:
		_instrucciones.text = "Este bioma todavía no tiene especies con imagen."
		_limpiar_tablero()
		return
	_textura = ImageTexture.create_from_image(_componer(_objetivo, _lado * PX_PIEZA))
	_orden.clear()
	for i in _lado * _lado:
		_orden.append(i)
	# Desordenado de verdad: ninguna ronda empieza resuelta ni casi resuelta.
	while _correctas() > _lado:
		_orden.shuffle()
	_instrucciones.text = "Arma la especie escondida: toca dos piezas para intercambiarlas. (%d×%d · +%d PR la primera vez que la armes)" % [
		_lado, _lado, RECOMPENSA_PR.get(_lado, 20)]
	_inicio_ms = Time.get_ticks_msec()
	_dibujar()


## Una especie del bioma actual con imagen, prefiriendo las que aún no se armaron en la sesión.
func _elegir_especie() -> EspecieData:
	var id_bioma := GameState.bioma_actual_id if GameState.bioma_actual_id > 0 else GameState.ORDEN_BIOMAS[0]
	var candidatas := EspecieLoader.cargar_especies_del_bioma(id_bioma).filter(
		func(d: EspecieData) -> bool: return EspecieLoader.textura_de(d) != null)
	if candidatas.is_empty():
		return null
	var nuevas := candidatas.filter(func(d: EspecieData) -> bool: return not _armadas.has(d.id_especie))
	return (nuevas if not nuevas.is_empty() else candidatas).pick_random()


## La especie sobre un recorte cuadrado del paisaje de su bioma, a `lado` px.
func _componer(data: EspecieData, lado: int) -> Image:
	var fondo: Image = load("res://Assets/UI/escenas/escena_%d.png" % data.id_bioma).get_image()
	fondo.decompress()
	fondo.convert(Image.FORMAT_RGBA8)
	var corte := mini(fondo.get_width(), fondo.get_height())
	var imagen := fondo.get_region(Rect2i((fondo.get_width() - corte) / 2, (fondo.get_height() - corte) / 2, corte, corte))
	imagen.resize(lado, lado, Image.INTERPOLATE_NEAREST)
	var sprite := EspecieLoader.textura_de(data).get_image()
	sprite.decompress()
	sprite.convert(Image.FORMAT_RGBA8)
	var usado := sprite.get_used_rect()
	if usado.size.x > 0 and usado.size.y > 0:
		sprite = sprite.get_region(usado)
	# Escala entera (pixel art nítido) para que la especie ocupe cerca de tres cuartos del cuadro.
	var factor := maxi(1, int(lado * 0.75 / maxf(sprite.get_width(), sprite.get_height())))
	sprite.resize(sprite.get_width() * factor, sprite.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var destino := Vector2i((lado - sprite.get_width()) / 2, int(lado * 0.94) - sprite.get_height())
	imagen.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), destino.max(Vector2i.ZERO))
	return imagen


func _limpiar_tablero() -> void:
	for hijo in _tablero.get_children():
		_tablero.remove_child(hijo)
		hijo.queue_free()


func _dibujar() -> void:
	_limpiar_tablero()
	_tablero.columns = _lado
	_tablero.add_theme_constant_override("h_separation", 0 if _resuelto else 2)
	_tablero.add_theme_constant_override("v_separation", 0 if _resuelto else 2)
	for casilla in _orden.size():
		var pieza := _orden[casilla]
		var atlas := AtlasTexture.new()
		atlas.atlas = _textura
		atlas.region = Rect2((pieza % _lado) * PX_PIEZA, (pieza / _lado) * PX_PIEZA, PX_PIEZA, PX_PIEZA)
		var boton := TextureButton.new()
		boton.texture_normal = atlas
		boton.ignore_texture_size = true
		boton.stretch_mode = TextureButton.STRETCH_SCALE
		boton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.size_flags_vertical = Control.SIZE_EXPAND_FILL
		boton.disabled = _resuelto
		if casilla == _elegida:
			boton.modulate = COLOR_ELEGIDA
		boton.pressed.connect(_on_pieza.bind(casilla))
		_tablero.add_child(boton)


func _on_pieza(casilla: int) -> void:
	if _resuelto:
		return
	if _elegida < 0:
		_elegida = casilla
		Sonidos.reproducir("clic")
	elif _elegida == casilla:
		_elegida = -1
	else:
		var a := _orden[_elegida]
		_orden[_elegida] = _orden[casilla]
		_orden[casilla] = a
		_elegida = -1
		_movimientos += 1
		Sonidos.reproducir("pestana")
		if _correctas() == _orden.size():
			_completar()
	_dibujar()


func _correctas() -> int:
	var n := 0
	for i in _orden.size():
		if _orden[i] == i:
			n += 1
	return n


func _completar() -> void:
	_resuelto = true
	var repetida := _armadas.has(_objetivo.id_especie)
	var pr: int = RECOMPENSA_REPETIDA if repetida else RECOMPENSA_PR.get(_lado, 20)
	_armadas[_objetivo.id_especie] = true
	GameState.agregar_pr(pr)
	GameState.registrar({"tipo": "rompecabezas", "id_especie": _objetivo.id_especie, "especie": _objetivo.nombre_comun,
		"correcta": true, "tiempo_s": snappedf((Time.get_ticks_msec() - _inicio_ms) / 1000.0, 0.1), "pr": pr,
		"detalle": "piezas=%d;movimientos=%d%s" % [_lado * _lado, _movimientos, ";repetida" if repetida else ""]})
	Sonidos.reproducir("correcta")
	var registro := "" if GameState.esta_descubierta(_objetivo.id_especie) \
		else " Todavía no está en tu Biopedia: resuelve su pista conceptual para registrarla."
	_resultado.text = "¡Completado en %d movimientos! Es %s (%s). %s +%d PR.%s" % [
		_movimientos, _objetivo.nombre_comun, _objetivo.nombre_cientifico, _objetivo.rol_ecologico, pr, registro]
