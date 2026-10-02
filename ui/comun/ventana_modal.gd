class_name VentanaModal
extends Control

## Ventana modal a pantalla completa con fondo oscurecido, título y botón Cerrar.
## Las subclases agregan su interfaz dentro de `contenido`.

var contenido: VBoxContainer
var _titulo: Label


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 48)
	for lado in ["top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 28)
	add_child(margen)

	var panel := PanelContainer.new()
	margen.add_child(panel)
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


func set_titulo(texto: String) -> void:
	_titulo.text = texto
