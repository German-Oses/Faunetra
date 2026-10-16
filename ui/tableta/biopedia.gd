extends HBoxContainer

## Biopedia: catálogo de especies nativas con filtros por bioma, búsqueda, tarjetas de
## especies descubiertas (con check) y no descubiertas (silueta con candado) y una ficha
## de detalle con estado de conservación, rol ecológico y relaciones ecológicas.
## Con `solo_descubiertas = true` funciona como "Mis especies".
## En vertical (teléfono) la lista y la ficha no caben lado a lado: tocar una tarjeta abre la
## ficha a pantalla completa con un botón para volver a la lista.

const COLOR_SILUETA := Color(0.16, 0.2, 0.17, 0.85)
const ANCHO_TARJETA := 104
const SEPARACION_TARJETAS := 8
const MARGENES_LISTA_VERTICAL := 72   # márgenes de la ventana y del panel alrededor de la lista
const FILTROS := [
	{"id": -1, "texto": "Todos", "icono": ""},
	{"id": 2, "texto": "Norte Árido", "icono": "cactus"},
	{"id": 1, "texto": "Zona Central", "icono": "arbol"},
	{"id": 3, "texto": "Sur", "icono": "pino"},
	{"id": 4, "texto": "Patagonia", "icono": "montana"},
	{"id": 5, "texto": "Insular", "icono": "palmera"},
]
## Color de la marca de rareza según el estado de conservación (más amenazada, más llamativa).
const COLORES_ESTADO := {
	"EX": Color("#3A3A3A"), "EW": Color("#5A4A6A"), "CR": Color("#B8322A"), "EN": Color("#D2702A"),
	"VU": Color("#C9A227"), "NT": Color("#7FA04A"), "LC": Color("#4E8A5A"),
}
## Dónde ver cada bioma en terreno (áreas protegidas representativas; ver «Sal a buscarla»).
const LUGARES_BIOMA := {
	1: "Parque Nacional La Campana, Reserva Nacional Río Clarillo y el Santuario de la Naturaleza Yerba Loca.",
	2: "Parque Nacional Lauca y Reserva Nacional Las Vicuñas en el altiplano; Parque Nacional Pan de Azúcar en la costa.",
	3: "Parque Nacional Alerce Andino, Parque Nacional Nahuelbuta, Parque Nacional Chiloé y la Reserva Costera Valdiviana.",
	4: "Parque Nacional Torres del Paine, Parque Nacional Patagonia y la Reserva Nacional Magallanes.",
	5: "Parque Nacional Archipiélago Juan Fernández y Parque Nacional Rapa Nui.",
}
const URL_INATURALIST := "https://www.inaturalist.org/observations?place_id=7182&taxon_name=%s"   # 7182 = Chile
const COLORES_TIPO := {
	"vertebrado": Color(0.55, 0.85, 0.5),
	"ave": Color(0.55, 0.78, 0.95),
	"planta": Color(0.25, 0.6, 0.3),
	"hongo": Color(0.85, 0.65, 0.4),
	"invertebrado": Color(0.95, 0.65, 0.3),
}

var solo_descubiertas := false

var _filtro_bioma := -1
var _contador: Label
var _busqueda: LineEdit
var _grilla_descubiertas: GridContainer
var _grilla_ocultas: GridContainer
var _titulo_ocultas: HBoxContainer
var _detalle: VBoxContainer
var _seleccionada: EspecieData
var _botones_filtro: Array[Button] = []
var _lista: VBoxContainer
var _panel_detalle: PanelContainer
var _volver: Button
var _en_ficha := false   # en vertical: true mientras se ve la ficha en lugar de la lista
var _placeholders: Dictionary = {}
var _progreso: ProgressBar


func _ready() -> void:
	theme = TemaFaunetra.obtener()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)

	var izquierda := VBoxContainer.new()
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.size_flags_stretch_ratio = 1.5
	izquierda.add_theme_constant_override("separation", 10)
	add_child(izquierda)
	_lista = izquierda
	izquierda.add_child(_crear_cabecera())
	izquierda.add_child(_crear_filtros())
	_progreso = ProgressBar.new()
	_progreso.custom_minimum_size.y = 10
	_progreso.show_percentage = false
	_progreso.modulate = Color(0.75, 1.0, 0.75)
	izquierda.add_child(_progreso)

	_busqueda = LineEdit.new()
	_busqueda.placeholder_text = "Buscar especie…"
	_busqueda.right_icon = TemaFaunetra.icono("lupa")
	_busqueda.clear_button_enabled = true
	_busqueda.text_changed.connect(func(_t: String) -> void: refrescar())
	izquierda.add_child(_busqueda)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	izquierda.add_child(scroll)
	var listas := VBoxContainer.new()
	listas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listas.add_theme_constant_override("separation", 8)
	scroll.add_child(listas)
	listas.add_child(_titulo_seccion("check", "Especies descubiertas"))
	_grilla_descubiertas = _crear_grilla()
	listas.add_child(_grilla_descubiertas)
	_titulo_ocultas = _titulo_seccion("candado", "Especies no descubiertas")
	listas.add_child(_titulo_ocultas)
	_grilla_ocultas = _crear_grilla()
	listas.add_child(_grilla_ocultas)

	_panel_detalle = PanelContainer.new()
	_panel_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_panel_detalle)
	var columna_detalle := VBoxContainer.new()
	_panel_detalle.add_child(columna_detalle)
	_volver = Button.new()
	_volver.text = "‹ Volver a la lista"
	_volver.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_volver.pressed.connect(func() -> void:
		_en_ficha = false
		_reacomodar())
	columna_detalle.add_child(_volver)
	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna_detalle.add_child(scroll_detalle)
	_detalle = VBoxContainer.new()
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.add_theme_constant_override("separation", 8)
	scroll_detalle.add_child(_detalle)

	GameState.especie_descubierta.connect(_on_especie_descubierta)
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _reacomodar())
	get_viewport().size_changed.connect(_ajustar_columnas)
	_reacomodar()
	_seleccionar_filtro(-1)


## En horizontal se ven lista y ficha a la vez; en vertical, una u otra.
func _reacomodar() -> void:
	var vertical: bool = Pantalla.vertical
	_ajustar_columnas()
	_lista.visible = not vertical or not _en_ficha
	_panel_detalle.visible = not vertical or _en_ficha
	_volver.visible = vertical


## Tarjeta tocada: muestra la ficha (en vertical, reemplazando a la lista).
func _abrir_ficha(data: EspecieData) -> void:
	_mostrar_detalle(data)
	_en_ficha = true
	_reacomodar()


## En horizontal, 5 columnas junto a la ficha. En vertical la lista ocupa el ancho de la pantalla
## (menos los márgenes de la ventana y del panel): caben tantas tarjetas como permita.
## Se calcula desde la pantalla porque una grilla impone su ancho mínimo a quien la contiene.
func _ajustar_columnas() -> void:
	var columnas := 5
	if Pantalla.vertical:
		var ancho := get_viewport_rect().size.x - MARGENES_LISTA_VERTICAL
		columnas = maxi(2, floori((ancho + SEPARACION_TARJETAS) / (ANCHO_TARJETA + SEPARACION_TARJETAS)))
	for g in [_grilla_descubiertas, _grilla_ocultas]:
		if g.columns != columnas:
			g.columns = columnas


# --- Construcción -----------------------------------------------------------------------

func _crear_cabecera() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	var icono := TextureRect.new()
	icono.texture = TemaFaunetra.icono("huella" if solo_descubiertas else "libro")
	icono.custom_minimum_size = Vector2(48, 48)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fila.add_child(icono)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 0)
	var titulo := Label.new()
	titulo.text = "Mis especies" if solo_descubiertas else "Biopedia"
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	textos.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.text = "Las especies que ya conoces" if solo_descubiertas else "Catálogo de especies nativas de Chile"
	subtitulo.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	textos.add_child(subtitulo)
	fila.add_child(textos)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.VERDE, 12, 2, 6))
	var chip_fila := HBoxContainer.new()
	chip.add_child(chip_fila)
	var hoja := TextureRect.new()
	hoja.texture = TemaFaunetra.icono("hoja")
	hoja.custom_minimum_size = Vector2(28, 28)
	hoja.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip_fila.add_child(hoja)
	_contador = Label.new()
	_contador.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	chip_fila.add_child(_contador)
	fila.add_child(chip)
	return fila


func _crear_filtros() -> Control:
	# Los filtros pasan a una segunda fila si no caben.
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	var grupo := ButtonGroup.new()
	for f in FILTROS:
		var b := Button.new()
		b.text = f["texto"]
		b.toggle_mode = true
		b.button_group = grupo
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if f["icono"] != "":
			b.icon = TemaFaunetra.icono(f["icono"])
			b.expand_icon = false
		TemaFaunetra.estilizar_chip(b)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_seleccionar_filtro.bind(f["id"]))
		b.set_meta("id_bioma", f["id"])
		fila.add_child(b)
		_botones_filtro.append(b)
	return fila


func _titulo_seccion(icono: String, texto: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var t := TextureRect.new()
	t.texture = TemaFaunetra.icono(icono)
	t.custom_minimum_size = Vector2(22, 22)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fila.add_child(t)
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 17)
	fila.add_child(l)
	return fila


func _crear_grilla() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5   # se ajusta al ancho disponible en _ajustar_columnas
	g.add_theme_constant_override("h_separation", SEPARACION_TARJETAS)
	g.add_theme_constant_override("v_separation", SEPARACION_TARJETAS)
	return g


# --- Datos ---------------------------------------------------------------------------------

## Cada filtro de bioma muestra su avance; con el bioma completo, lleva el sello (check).
func _actualizar_filtros() -> void:
	for b in _botones_filtro:
		var id := int(b.get_meta("id_bioma"))
		var f: Dictionary = FILTROS.filter(func(x: Dictionary) -> bool: return x["id"] == id)[0]
		if id < 0:
			continue
		var total := 0
		var conocidas := 0
		for d in EspecieLoader.cargar_especies_del_bioma(id):
			total += 1
			if GameState.esta_descubierta(d.id_especie):
				conocidas += 1
		var completo := total > 0 and conocidas == total
		b.text = "%s %d/%d" % [f["texto"], conocidas, total]
		b.icon = TemaFaunetra.icono("check" if completo else f["icono"])
		b.tooltip_text = "¡Sello de bioma completo!" if completo else ""


func _seleccionar_filtro(id_bioma: int) -> void:
	_filtro_bioma = id_bioma
	for b in _botones_filtro:
		b.set_pressed_no_signal(int(b.get_meta("id_bioma")) == id_bioma)
	refrescar()


## Abre la Biopedia directamente en una especie (filtrando por su bioma).
func mostrar_especie(data: EspecieData) -> void:
	_seleccionada = data
	_busqueda.text = ""
	_seleccionar_filtro(data.id_bioma)
	_en_ficha = true
	_reacomodar()


func _on_especie_descubierta(_data: EspecieData) -> void:
	if is_visible_in_tree():
		refrescar()


func refrescar() -> void:
	for g in [_grilla_descubiertas, _grilla_ocultas]:
		for hijo in g.get_children():
			hijo.queue_free()

	var texto := ReglasEcosistema.normalizar(_busqueda.text)
	var total := 0
	var conocidas := 0
	var visibles: Array[EspecieData] = []
	for data in EspecieLoader.cargar_todas():
		if _filtro_bioma >= 0 and data.id_bioma != _filtro_bioma:
			continue
		total += 1
		var conocida: bool = GameState.esta_descubierta(data.id_especie)
		if conocida:
			conocidas += 1
		elif solo_descubiertas:
			continue
		# Solo se puede buscar por nombre lo que ya se conoce.
		if texto != "" and not (conocida and (ReglasEcosistema.normalizar(data.nombre_comun).contains(texto)
				or ReglasEcosistema.normalizar(data.nombre_cientifico).contains(texto))):
			continue
		visibles.append(data)
		(_grilla_descubiertas if conocida else _grilla_ocultas).add_child(_crear_tarjeta(data, conocida))

	_contador.text = "%d/%d descubiertas" % [conocidas, total]
	_progreso.max_value = maxi(1, total)
	_progreso.value = conocidas
	_actualizar_filtros()
	_titulo_ocultas.visible = not solo_descubiertas and _grilla_ocultas.get_child_count() > 0
	_grilla_ocultas.visible = _titulo_ocultas.visible
	if _seleccionada and visibles.has(_seleccionada):
		_mostrar_detalle(_seleccionada)
	elif not visibles.is_empty():
		_mostrar_detalle(visibles[0])
	else:
		_limpiar_detalle()
		var vacio := Label.new()
		vacio.text = "Aún no hay especies aquí. ¡Explora, planta y responde trivias para descubrirlas!"
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detalle.add_child(vacio)


func _crear_tarjeta(data: EspecieData, conocida: bool) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(ANCHO_TARJETA, 112)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # las columnas se reparten el ancho sobrante
	boton.toggle_mode = true
	boton.set_pressed_no_signal(data == _seleccionada)
	TemaFaunetra.estilizar_chip(boton)
	var fondo: Color = TemaFaunetra.COLOR_BIOMA.get(data.id_bioma, Color.WHITE) if conocida else TemaFaunetra.CREMA_OSCURA
	boton.add_theme_stylebox_override("normal", TemaFaunetra.caja(fondo, TemaFaunetra.BORDE, 12, 2, 6))
	boton.add_theme_stylebox_override("pressed", TemaFaunetra.caja(fondo, TemaFaunetra.VERDE, 12, 3, 6))
	boton.add_theme_stylebox_override("hover_pressed", TemaFaunetra.caja(fondo, TemaFaunetra.VERDE, 12, 3, 6))
	boton.add_theme_color_override("font_pressed_color", TemaFaunetra.TEXTO)
	boton.add_theme_color_override("font_hover_pressed_color", TemaFaunetra.TEXTO)
	boton.pressed.connect(_abrir_ficha.bind(data))
	boton.set_meta("id_especie", data.id_especie)

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 6
	caja.offset_right = -6
	caja.offset_top = 6
	caja.offset_bottom = -6
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(caja)
	var imagen := TextureRect.new()
	imagen.texture = _imagen_de(data)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not conocida:
		imagen.modulate = COLOR_SILUETA
	caja.add_child(imagen)
	var nombre := Label.new()
	nombre.text = data.nombre_comun if conocida else "???"
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.add_theme_font_size_override("font_size", 12)
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(nombre)

	if conocida:
		# Marca de rareza: el estado de conservación, con color según cuán amenazada está.
		var rareza := Label.new()
		rareza.text = data.estado_conservacion
		rareza.add_theme_font_size_override("font_size", 10)
		rareza.add_theme_color_override("font_color", Color.WHITE)
		rareza.add_theme_stylebox_override("normal", TemaFaunetra.caja(COLORES_ESTADO.get(data.estado_conservacion, TemaFaunetra.VERDE), Color(0, 0, 0, 0), 6, 0, 3))
		rareza.position = Vector2(6, 6)
		rareza.tooltip_text = EspecieData.NOMBRES_ESTADO.get(data.estado_conservacion, "")
		# PASS (no IGNORE): así recibe el hover para su tooltip y el clic sigue llegando a la tarjeta.
		rareza.mouse_filter = Control.MOUSE_FILTER_PASS
		boton.add_child(rareza)
		if GameState.vio_en_la_vida_real(data.id_especie):
			var vista := TextureRect.new()
			vista.texture = TemaFaunetra.icono("persona")
			vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			vista.custom_minimum_size = Vector2(20, 20)
			vista.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			vista.offset_left = -26
			vista.offset_right = -6
			vista.offset_top = -44
			vista.offset_bottom = -24
			vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boton.add_child(vista)

	var insignia := TextureRect.new()
	insignia.texture = TemaFaunetra.icono("check" if conocida else "candado")
	insignia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia.custom_minimum_size = Vector2(22, 22)
	insignia.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	insignia.offset_left = -28
	insignia.offset_right = -6
	insignia.offset_top = 4
	insignia.offset_bottom = 26
	insignia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(insignia)
	return boton


# --- Ficha de detalle --------------------------------------------------------------------

func _limpiar_detalle() -> void:
	for hijo in _detalle.get_children():
		_detalle.remove_child(hijo)
		hijo.queue_free()


func _mostrar_detalle(data: EspecieData) -> void:
	_seleccionada = data
	for g in [_grilla_descubiertas, _grilla_ocultas]:
		for tarjeta in g.get_children():
			(tarjeta as Button).set_pressed_no_signal(int(tarjeta.get_meta("id_especie", -1)) == data.id_especie)
	_limpiar_detalle()
	var conocida: bool = GameState.esta_descubierta(data.id_especie)
	var flora := EspecieLoader.es_flora(data)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 12)
	_detalle.add_child(cabecera)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", TemaFaunetra.caja(TemaFaunetra.COLOR_BIOMA.get(data.id_bioma, Color.WHITE), TemaFaunetra.BORDE, 12, 2, 6))
	cabecera.add_child(marco)
	var imagen := TextureRect.new()
	imagen.texture = _imagen_de(data)
	imagen.custom_minimum_size = Vector2(128, 128)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not conocida:
		imagen.modulate = COLOR_SILUETA
	marco.add_child(imagen)

	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(datos)
	var nombre := Label.new()
	nombre.text = data.nombre_comun if conocida else "Especie no descubierta"
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.add_theme_font_size_override("font_size", 22)
	datos.add_child(nombre)
	if conocida:
		var cientifico := RichTextLabel.new()
		cientifico.bbcode_enabled = true
		cientifico.fit_content = true
		cientifico.text = "[i]%s[/i]" % data.nombre_cientifico
		datos.add_child(cientifico)
		datos.add_child(TemaFaunetra.insignia_estado(data.estado_conservacion))
	datos.add_child(_fila_dato(TemaFaunetra.ICONO_BIOMA.get(data.id_bioma, "arbol"), "Bioma", GameState.nombre_bioma(data.id_bioma)))
	datos.add_child(_fila_dato("hoja" if flora else "huella", "Tipo", data.tipo.capitalize()))

	if conocida:
		_detalle.add_child(_parrafo("Rol ecológico", data.rol_ecologico))
		var fecha := _fecha(float(GameState.descubiertas[str(data.id_especie)]))
		_detalle.add_child(_parrafo("Registro", "Primer avistamiento: %s · Validaciones: %d/%d" % [
			fecha, GameState.etapa_validacion(data.id_especie), GameState.INTERVALOS_REPASO_DIAS.size()]))
		_detalle.add_child(_relaciones(data))
		_detalle.add_child(_sal_a_buscarla(data))
	else:
		var pista := ""
		if flora:
			pista = "Esta especie está extinta, no queda ningún ejemplar vivo: conócela resolviendo su pista conceptual." if data.estado_conservacion == "EX" \
				else "Plántala desde la barra de plantación de su bioma o resuelve su pista conceptual."
		else:
			pista = ReglasEcosistema.texto_requisitos(data) + " Cuando llegue al refugio, tócalo para identificarlo."
		_detalle.add_child(_parrafo("Pista", pista))
		var boton := Button.new()
		boton.text = "Resolver pista conceptual"
		boton.icon = TemaFaunetra.icono("lupa")
		boton.pressed.connect(func() -> void: EventBus.solicitar_trivia.emit("especie", data.id_especie))
		_detalle.add_child(boton)


## «Sal a buscarla»: dónde verla en Chile, sus observaciones reales en iNaturalist y un botón
## para registrar que el jugador la vio en la vida real (queda en el registro de investigación).
func _sal_a_buscarla(data: EspecieData) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	# Extinta (EX): no quedan ejemplares vivos en ninguna parte, así que no hay nada que salir a buscar
	# ni avistamiento que registrar. Extinta en estado silvestre (EW): sobrevive solo en cultivo o cautiverio.
	if data.estado_conservacion == "EX":
		caja.add_child(_titulo_seccion("brujula", "Su historia"))
		var historia := Label.new()
		historia.text = "Esta especie está extinta: ya no quedan ejemplares vivos, ni en la naturaleza ni en viveros. " \
			+ "La conocemos por sus restos (semillas, polen o troncos) y por la historia de su ecosistema. " \
			+ "Recordarla nos ayuda a proteger a las especies que todavía podemos salvar."
		historia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		historia.add_theme_font_size_override("font_size", 13)
		caja.add_child(historia)
		return caja
	caja.add_child(_titulo_seccion("brujula", "Sal a buscarla"))
	var texto := ""
	if data.estado_conservacion == "EW":
		texto = "Ya no vive en estado silvestre: hoy sobrevive gracias a viveros y programas de conservación que buscan devolverla a su hábitat."
	else:
		texto = "Puedes encontrarla en áreas protegidas como: %s" % LUGARES_BIOMA.get(data.id_bioma, "")
	texto += "
Observa sin tocar ni sacar nada: una foto basta para registrarla."
	var parrafo := Label.new()
	parrafo.text = texto
	parrafo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parrafo.add_theme_font_size_override("font_size", 13)
	caja.add_child(parrafo)

	var botones := HFlowContainer.new()
	botones.add_theme_constant_override("h_separation", 8)
	botones.add_theme_constant_override("v_separation", 6)
	caja.add_child(botones)
	var observaciones := Button.new()
	observaciones.text = "Ver observaciones reales"
	observaciones.icon = TemaFaunetra.icono("lupa")
	observaciones.tooltip_text = "Abre iNaturalist con los registros de %s en Chile." % data.nombre_cientifico
	observaciones.pressed.connect(func() -> void:
		GameState.registrar({"tipo": "inaturalist", "id_especie": data.id_especie, "especie": data.nombre_comun, "id_bioma": data.id_bioma})
		OS.shell_open(URL_INATURALIST % data.nombre_cientifico.uri_encode()))
	botones.add_child(observaciones)
	if GameState.vio_en_la_vida_real(data.id_especie):
		var vista := Label.new()
		vista.text = "La viste en la vida real el %s." % _fecha(float(GameState.avistamientos_reales[str(data.id_especie)]))
		vista.add_theme_color_override("font_color", TemaFaunetra.VERDE)
		botones.add_child(vista)
	else:
		var marcar := Button.new()
		marcar.text = "¡La vi en la vida real!"
		marcar.icon = TemaFaunetra.icono("persona")
		marcar.pressed.connect(func() -> void:
			GameState.marcar_avistamiento_real(data)
			Sonidos.reproducir("encontrado")
			refrescar())
		botones.add_child(marcar)
	return caja


func _fila_dato(icono: String, etiqueta: String, valor: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var t := TextureRect.new()
	t.texture = TemaFaunetra.icono(icono)
	t.custom_minimum_size = Vector2(20, 20)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila.add_child(t)
	var l := Label.new()
	l.text = "%s: %s" % [etiqueta, valor]
	l.add_theme_font_size_override("font_size", 14)
	fila.add_child(l)
	return fila


func _parrafo(titulo: String, texto: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = "[b]%s[/b]\n%s" % [titulo, texto]
	return r


## Relaciones ecológicas: sinergias de la planta, o las plantas que el animal necesita.
func _relaciones(data: EspecieData) -> Control:
	var caja := VBoxContainer.new()
	caja.add_child(_titulo_seccion("hoja", "Relaciones ecológicas"))
	var hay := false
	if EspecieLoader.es_flora(data):
		for s in ReglasEcosistema.datos().get("sinergias", []):
			var fuente := _por_nombre(str(s["fuente"]), data.id_bioma)
			var objetivo := _por_nombre(str(s["objetivo"]), data.id_bioma)
			if fuente == null or objetivo == null or (fuente != data and objetivo != data):
				continue
			caja.add_child(_fila_relacion(fuente, objetivo, "«%s» +%d%% de crecimiento" % [s.get("nombre", "Sinergia"), int(round(float(s.get("bono", 0.2)) * 100))]))
			hay = true
		for animal in EspecieLoader.fauna_del_bioma(data.id_bioma):
			if (ReglasEcosistema.requisitos_fauna(animal)["plantas"] as Array).has(data.nombre_comun):
				caja.add_child(_fila_relacion(data, animal, "atrae a %s" % _nombre_visible(animal)))
				hay = true
	else:
		for nombre in ReglasEcosistema.requisitos_fauna(data)["plantas"]:
			var planta := _por_nombre(nombre, data.id_bioma)
			if planta:
				caja.add_child(_fila_relacion(planta, data, "%s le da hábitat" % nombre))
				hay = true
	if not hay:
		var l := Label.new()
		l.text = "Crece mejor junto a especies distintas (+10% por biodiversidad)." if EspecieLoader.es_flora(data) \
			else ReglasEcosistema.texto_requisitos(data)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 13)
		caja.add_child(l)
	return caja


func _fila_relacion(origen: EspecieData, destino: EspecieData, texto: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 10, 1, 6))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	panel.add_child(fila)
	for d in [origen, destino]:
		var t := TextureRect.new()
		t.texture = _imagen_de(d)
		t.custom_minimum_size = Vector2(36, 36)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not GameState.esta_descubierta(d.id_especie):
			t.modulate = COLOR_SILUETA
		fila.add_child(t)
		if d == origen:
			var flecha := Label.new()
			flecha.text = "→"
			flecha.add_theme_font_size_override("font_size", 20)
			fila.add_child(flecha)
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 13)
	fila.add_child(l)
	return panel


func _por_nombre(nombre: String, id_bioma: int) -> EspecieData:
	var buscado := ReglasEcosistema.normalizar(nombre)
	for d in EspecieLoader.cargar_especies_del_bioma(id_bioma):
		if ReglasEcosistema.normalizar(d.nombre_comun) == buscado:
			return d
	return null


func _nombre_visible(data: EspecieData) -> String:
	return data.nombre_comun if GameState.esta_descubierta(data.id_especie) else "una especie por descubrir"


func _imagen_de(data: EspecieData) -> Texture2D:
	var tex := EspecieLoader.textura_de(data)
	if tex:
		return tex
	if not _placeholders.has(data.tipo):
		var imagen := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		imagen.fill(COLORES_TIPO.get(data.tipo, Color.WHITE))
		_placeholders[data.tipo] = ImageTexture.create_from_image(imagen)
	return _placeholders[data.tipo]


func _fecha(timestamp: float) -> String:
	var local := int(timestamp) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var f := Time.get_datetime_dict_from_unix_time(local)
	return "%02d/%02d/%d" % [f["day"], f["month"], f["year"]]
