extends VentanaModal

## Elección del modo de juego al comenzar una partida. Si se cierra sin confirmar,
## queda el modo por defecto (Guardaparques). Emite `terminado` en ambos casos.

signal terminado

var _selector: SelectorModo


func _ready() -> void:
	set_titulo("Elige tu modo de juego")
	var intro := Label.new()
	intro.text = "El modo define cuántos recursos tienes y qué tan exigente es cuidar los refugios. Las trivias se seguirán adaptando a tus respuestas en cualquier modo. Podrás cambiarlo solo comenzando una partida nueva."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(scroll)
	_selector = SelectorModo.new()
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_selector)

	var comenzar := Button.new()
	comenzar.text = "Comenzar"
	comenzar.icon = TemaFaunetra.icono("play")
	comenzar.custom_minimum_size = Vector2(200, 48)
	comenzar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	comenzar.pressed.connect(hide)
	contenido.add_child(comenzar)
	visibility_changed.connect(_on_visibilidad)


func abrir() -> void:
	_selector.seleccionar(GameState.modo)
	show()
	move_to_front()


func _on_visibilidad() -> void:
	if visible:
		return
	GameState.elegir_modo(_selector.seleccionado)
	terminado.emit()
	queue_free()
