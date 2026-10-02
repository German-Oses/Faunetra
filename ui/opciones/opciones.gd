extends VentanaModal

## Pausa y opciones: volumen, pantalla completa, volver al mapa de mundos y salir.
## Mientras está abierta, el juego queda en pausa (el terreno, la fauna y el guardado se detienen).

signal ir_a_mundos

var _volumen: HSlider
var _volumen_texto: Label
var _pantalla_completa: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_titulo("Pausa y opciones")
	visibility_changed.connect(_on_visibilidad)

	var fila_volumen := HBoxContainer.new()
	fila_volumen.add_theme_constant_override("separation", 12)
	var icono := TextureRect.new()
	icono.texture = TemaFaunetra.icono("sonido")
	icono.custom_minimum_size = Vector2(32, 32)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fila_volumen.add_child(icono)
	var etiqueta := Label.new()
	etiqueta.text = "Volumen"
	etiqueta.custom_minimum_size.x = 180
	fila_volumen.add_child(etiqueta)
	_volumen = HSlider.new()
	_volumen.min_value = 0.0
	_volumen.max_value = 1.0
	_volumen.step = 0.05
	_volumen.custom_minimum_size = Vector2(260, 32)
	_volumen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volumen.value_changed.connect(_on_volumen)
	fila_volumen.add_child(_volumen)
	_volumen_texto = Label.new()
	fila_volumen.add_child(_volumen_texto)
	contenido.add_child(fila_volumen)

	_pantalla_completa = CheckButton.new()
	_pantalla_completa.text = "Pantalla completa"
	_pantalla_completa.add_theme_color_override("font_color", TemaFaunetra.TEXTO)
	_pantalla_completa.add_theme_color_override("font_pressed_color", TemaFaunetra.TEXTO)
	_pantalla_completa.add_theme_color_override("font_hover_color", TemaFaunetra.TEXTO)
	_pantalla_completa.add_theme_color_override("font_hover_pressed_color", TemaFaunetra.TEXTO)
	_pantalla_completa.toggled.connect(_on_pantalla_completa)
	contenido.add_child(_pantalla_completa)

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(espacio)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 12)
	contenido.add_child(botones)
	var continuar := Button.new()
	continuar.text = "Continuar"
	continuar.icon = TemaFaunetra.icono("play")
	continuar.custom_minimum_size = Vector2(180, 48)
	continuar.pressed.connect(hide)
	botones.add_child(continuar)
	var mundos := Button.new()
	mundos.text = "Mapa de mundos"
	mundos.icon = TemaFaunetra.icono("casa")
	mundos.custom_minimum_size = Vector2(200, 48)
	mundos.pressed.connect(_on_mundos)
	botones.add_child(mundos)
	# En el navegador no se "sale" de una página: el botón solo existe en PC.
	if not OS.has_feature("web"):
		var salir := Button.new()
		salir.text = "Guardar y salir"
		salir.custom_minimum_size = Vector2(180, 48)
		salir.add_theme_stylebox_override("normal", TemaFaunetra.caja(Color("#B5553F"), Color("#8E3A2A"), 10, 2, 8))
		salir.add_theme_stylebox_override("hover", TemaFaunetra.caja(Color("#C8634C"), Color("#8E3A2A"), 10, 2, 8))
		salir.pressed.connect(_salir)
		botones.add_child(salir)


func abrir() -> void:
	_volumen.set_value_no_signal(float(GameState.opciones.get("volumen", 0.8)))
	_volumen_texto.text = "%d%%" % int(_volumen.value * 100)
	var completa := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	_pantalla_completa.set_pressed_no_signal(completa)
	show()
	move_to_front()


func _on_visibilidad() -> void:
	get_tree().paused = visible
	if not visible:
		GameState.guardar()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _on_volumen(valor: float) -> void:
	GameState.opciones["volumen"] = valor
	_volumen_texto.text = "%d%%" % int(valor * 100)
	GameState.aplicar_volumen()


func _on_pantalla_completa(activa: bool) -> void:
	GameState.opciones["pantalla_completa"] = activa
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if activa else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_mundos() -> void:
	hide()
	ir_a_mundos.emit()


func _salir() -> void:
	get_tree().paused = false
	GameState.guardar()
	get_tree().quit()
