class_name TemaFaunetra
extends RefCounted

## Estética de la interfaz: paneles crema con bordes suaves, botones verde bosque y
## texto verde oscuro (según los mockups de Faunetra). Úsalo con `control.theme = TemaFaunetra.obtener()`.

const CREMA := Color("#F6F0DC")
const CREMA_OSCURA := Color("#ECE3C8")
const BORDE := Color("#D5C9A6")
const VERDE := Color("#2F6B4A")
const VERDE_HOVER := Color("#3B805A")
const VERDE_PRESIONADO := Color("#24543A")
const VERDE_CLARO := Color("#DCEBCF")
const TEXTO := Color("#24382B")
const TEXTO_SUAVE := Color("#5E6E5F")
const OCEANO := Color("#7CC3D3")
const OCEANO_PROFUNDO := Color("#5AA6BE")

const COLOR_ESTADO := {
	"LC": Color("#4E9A47"),
	"NT": Color("#8DB23E"),
	"VU": Color("#D9A93C"),
	"EN": Color("#E07B39"),
	"CR": Color("#C8463A"),
	"EW": Color("#8A5BA8"),
	"EX": Color("#5E5E6E"),
}
## Color de fondo de cada bioma (tarjetas e imágenes de la Biopedia).
const COLOR_BIOMA := {
	1: Color("#EFE3B4"),
	2: Color("#F4DDB2"),
	3: Color("#D6EBC8"),
	4: Color("#DDE3EC"),
	5: Color("#CDEBE6"),
}
const ICONO_BIOMA := {1: "arbol", 2: "cactus", 3: "pino", 4: "montana", 5: "palmera"}

static var _tema: Theme


static var _iconos: Dictionary = {}


## Ícono pixel art escalado ×2 sin suavizado (los originales miden 16×16).
static func icono(nombre: String) -> Texture2D:
	if not _iconos.has(nombre):
		var base: Texture2D = load("res://Assets/UI/iconos/%s.png" % nombre)
		var imagen := base.get_image()
		imagen.resize(imagen.get_width() * 2, imagen.get_height() * 2, Image.INTERPOLATE_NEAREST)
		_iconos[nombre] = ImageTexture.create_from_image(imagen)
	return _iconos[nombre]


static func isla(id_bioma: int) -> Texture2D:
	return load("res://Assets/UI/islas/isla_%d.png" % id_bioma)


static func caja(fondo: Color, borde: Color = BORDE, radio: int = 12, grosor: int = 2, margen: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	s.anti_aliasing = true
	return s


static func obtener() -> Theme:
	if _tema:
		return _tema
	var t := Theme.new()
	t.default_font_size = 16

	t.set_stylebox("panel", "PanelContainer", caja(CREMA))
	t.set_stylebox("panel", "Panel", caja(CREMA))
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("default_color", "RichTextLabel", TEXTO)

	var normal := caja(VERDE, VERDE_PRESIONADO, 10, 2, 8)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", caja(VERDE_HOVER, VERDE_PRESIONADO, 10, 2, 8))
	t.set_stylebox("pressed", "Button", caja(VERDE_PRESIONADO, VERDE_PRESIONADO, 10, 2, 8))
	t.set_stylebox("hover_pressed", "Button", caja(VERDE_PRESIONADO, VERDE_PRESIONADO, 10, 2, 8))
	t.set_stylebox("disabled", "Button", caja(Color("#B9B6A6"), Color("#A3A090"), 10, 2, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(estado, "Button", CREMA)
	t.set_color("font_disabled_color", "Button", Color("#F2EFE6"))
	t.set_constant("h_separation", "Button", 8)

	t.set_stylebox("normal", "LineEdit", caja(Color.WHITE, BORDE, 10, 2, 8))
	t.set_stylebox("focus", "LineEdit", caja(Color.WHITE, VERDE, 10, 2, 8))
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("font_placeholder_color", "LineEdit", TEXTO_SUAVE)

	var fondo_barra := caja(CREMA_OSCURA, BORDE, 6, 1, 0)
	var relleno := caja(Color("#3E8E5A"), Color("#3E8E5A"), 6, 0, 0)
	t.set_stylebox("background", "ProgressBar", fondo_barra)
	t.set_stylebox("fill", "ProgressBar", relleno)
	t.set_color("font_color", "ProgressBar", TEXTO)

	t.set_stylebox("panel", "TabContainer", caja(CREMA, BORDE, 12, 2, 10))
	t.set_stylebox("tab_selected", "TabContainer", caja(VERDE, VERDE, 8, 0, 8))
	t.set_stylebox("tab_unselected", "TabContainer", caja(CREMA_OSCURA, BORDE, 8, 1, 8))
	t.set_stylebox("tab_hovered", "TabContainer", caja(VERDE_CLARO, BORDE, 8, 1, 8))
	t.set_color("font_selected_color", "TabContainer", CREMA)
	t.set_color("font_unselected_color", "TabContainer", TEXTO)
	t.set_color("font_hovered_color", "TabContainer", TEXTO)

	t.set_stylebox("normal", "OptionButton", normal)
	t.set_color("font_color", "OptionButton", CREMA)
	_tema = t
	return t


## Botón tipo "chip" claro (filtros, tarjetas): crema con borde, verde al estar activo.
static func estilizar_chip(boton: BaseButton) -> void:
	boton.add_theme_stylebox_override("normal", caja(Color.WHITE, BORDE, 12, 2, 6))
	boton.add_theme_stylebox_override("hover", caja(VERDE_CLARO, BORDE, 12, 2, 6))
	boton.add_theme_stylebox_override("pressed", caja(VERDE, VERDE_PRESIONADO, 12, 2, 6))
	boton.add_theme_stylebox_override("hover_pressed", caja(VERDE, VERDE_PRESIONADO, 12, 2, 6))
	boton.add_theme_stylebox_override("disabled", caja(CREMA_OSCURA, BORDE, 12, 2, 6))
	for estado in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
		boton.add_theme_color_override(estado, TEXTO)
	boton.add_theme_color_override("font_pressed_color", CREMA)
	boton.add_theme_color_override("font_hover_pressed_color", CREMA)


## Etiqueta con el estado de conservación como "píldora" de color.
static func insignia_estado(codigo: String) -> PanelContainer:
	var p := PanelContainer.new()
	var color: Color = COLOR_ESTADO.get(codigo, VERDE)
	p.add_theme_stylebox_override("panel", caja(color, color.darkened(0.2), 10, 1, 4))
	var l := Label.new()
	l.text = "%s (%s)" % [EspecieData.NOMBRES_ESTADO.get(codigo, "Sin evaluar"), codigo]
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_font_size_override("font_size", 13)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p
