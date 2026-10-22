extends VBoxContainer

## Pestaña "Juegos" de la Tableta: agrupa los minijuegos de percepción y memoria (Paisaje Sonoro,
## Rompecabezas y Memorice) bajo un selector, para que la barra de pestañas siga cabiendo en un
## celular en vertical. Cada juego conserva su partida en curso al cambiar de uno a otro.

const AsociacionAcustica := preload("res://ui/minijuegos/asociacion_acustica.gd")
const Rompecabezas := preload("res://ui/minijuegos/rompecabezas.gd")
const Memorice := preload("res://ui/minijuegos/memorice.gd")

enum Juego { SONIDO, ROMPECABEZAS, MEMORICE }
const NOMBRES := ["Paisaje Sonoro", "Rompecabezas", "Memorice"]
const NOMBRES_CORTOS := ["Sonidos", "Puzzle", "Memorice"]
const ICONOS := ["sonido", "rompecabezas", "cartas"]

var sonido: AsociacionAcustica
var _juegos: Array[Control] = []
var _botones: Array[Button] = []
var _actual := Juego.SONIDO


func _ready() -> void:
	name = "Juegos"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 6)
	add_child(selector)
	var grupo := ButtonGroup.new()
	for i in NOMBRES.size():
		var boton := Button.new()
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.icon = TemaFaunetra.icono(ICONOS[i])
		boton.expand_icon = false
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# El texto no fija un ancho mínimo: en un celular la Tableta no debe crecer más que la pantalla.
		boton.clip_text = true
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.pressed.connect(mostrar.bind(i))
		selector.add_child(boton)
		_botones.append(boton)

	sonido = AsociacionAcustica.new()
	for juego: Control in [sonido, Rompecabezas.new(), Memorice.new()]:
		juego.visible = false
		add_child(juego)
		_juegos.append(juego)
	Pantalla.orientacion_cambiada.connect(_titular)
	_titular(Pantalla.vertical)
	_botones[_actual].set_pressed_no_signal(true)
	_juegos[_actual].visible = true


func _titular(vertical: bool) -> void:
	for i in _botones.size():
		_botones[i].text = NOMBRES_CORTOS[i] if vertical else NOMBRES[i]
		_botones[i].add_theme_font_size_override("font_size", 13 if vertical else 16)


## Muestra un juego (y lo prepara si no tiene una partida en curso).
func mostrar(juego: int) -> void:
	_actual = juego
	for i in _juegos.size():
		_juegos[i].visible = i == juego
		_botones[i].set_pressed_no_signal(i == juego)
	_juegos[juego].al_mostrar()


## Al abrir la pestaña: retoma el juego que estaba elegido.
func al_mostrar() -> void:
	mostrar(_actual)
