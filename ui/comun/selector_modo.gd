class_name SelectorModo
extends HFlowContainer

## Tarjetas para elegir el modo de juego (ver GameState.MODOS). Se reparten en filas
## en pantallas angostas. Emite `cambiado` al tocar una tarjeta.

signal cambiado(id_modo: String)

var seleccionado: String = GameState.MODO_POR_DEFECTO
var _grupo := ButtonGroup.new()
var _botones: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 10)
	for id_modo in GameState.MODOS:
		var info: Dictionary = GameState.MODOS[id_modo]
		var tarjeta := Button.new()
		tarjeta.toggle_mode = true
		tarjeta.button_group = _grupo
		tarjeta.custom_minimum_size = Vector2(240, 150)
		tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var normal := TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 12, 2, 10)
		var elegida := TemaFaunetra.caja(TemaFaunetra.VERDE_CLARO, TemaFaunetra.VERDE, 12, 4, 10)
		for estado in ["normal", "hover", "focus"]:
			tarjeta.add_theme_stylebox_override(estado, normal)
		for estado in ["pressed", "hover_pressed"]:
			tarjeta.add_theme_stylebox_override(estado, elegida)

		var margen := MarginContainer.new()
		margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for lado in ["left", "right", "top", "bottom"]:
			margen.add_theme_constant_override("margin_" + lado, 12)
		tarjeta.add_child(margen)
		var columna := VBoxContainer.new()
		columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margen.add_child(columna)
		var cabecera := HBoxContainer.new()
		cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
		columna.add_child(cabecera)
		var icono := TextureRect.new()
		icono.texture = TemaFaunetra.icono(info["icono"])
		icono.custom_minimum_size = Vector2(28, 28)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cabecera.add_child(icono)
		var nombre := Label.new()
		nombre.text = info["nombre"]
		nombre.add_theme_font_size_override("font_size", 19)
		nombre.add_theme_color_override("font_color", TemaFaunetra.VERDE)
		cabecera.add_child(nombre)
		var descripcion := Label.new()
		descripcion.text = info["descripcion"]
		descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		descripcion.add_theme_color_override("font_color", TemaFaunetra.TEXTO)
		descripcion.add_theme_font_size_override("font_size", 14)
		columna.add_child(descripcion)
		tarjeta.pressed.connect(_elegir.bind(id_modo))
		add_child(tarjeta)
		_botones[id_modo] = tarjeta
	seleccionar(seleccionado)


func seleccionar(id_modo: String) -> void:
	seleccionado = id_modo
	if _botones.has(id_modo):
		(_botones[id_modo] as Button).set_pressed_no_signal(true)


func _elegir(id_modo: String) -> void:
	seleccionado = id_modo
	cambiado.emit(id_modo)
