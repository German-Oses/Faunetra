class_name VentanaModal
extends Control

## Ventana modal a pantalla completa con fondo oscurecido, título y botón Cerrar.
## Las subclases agregan su interfaz dentro de `contenido`.
## En vertical (teléfono) los márgenes se angostan para aprovechar el ancho.

var contenido: VBoxContainer
var _titulo: Label
var _margen: MarginContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	_margen = MarginContainer.new()
	_margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margen)
	_ajustar_margenes(Pantalla.vertical)
	Pantalla.orientacion_cambiada.connect(_ajustar_margenes)

	var panel := PanelContainer.new()
	_margen.add_child(panel)
	var interior := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		interior.add_theme_constant_override("margin_" + lado, 14)
	panel.add_child(interior)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 10)
	interior.add_child(raiz)

	var cabecera := HBoxContainer.new()
	raiz.add_child(cabecera)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 22)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # un título largo no empuja «Cerrar» fuera
	cabecera.add_child(_titulo)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.pressed.connect(hide)
	cabecera.add_child(cerrar)

	contenido = VBoxContainer.new()
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 10)
	raiz.add_child(contenido)
	hide()


func _ajustar_margenes(vertical: bool) -> void:
	for lado in ["left", "right"]:
		_margen.add_theme_constant_override("margin_" + lado, 8 if vertical else 48)
	for lado in ["top", "bottom"]:
		_margen.add_theme_constant_override("margin_" + lado, 12 if vertical else 28)


func set_titulo(texto: String) -> void:
	_titulo.text = texto
