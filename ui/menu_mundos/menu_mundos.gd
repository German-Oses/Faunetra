extends Control

## Menú principal de Faunetra: mapa de mundos (los 5 biomas como islas isométricas),
## panel del bioma seleccionado con "Explorar" y especies cercanas, y barra de navegación
## inferior hacia la Biopedia, Mis especies y el Perfil.

const Biopedia := preload("res://ui/tableta/biopedia.gd")
const Perfil := preload("res://ui/menu_mundos/perfil.gd")

## Posición de cada isla en el mapa (fracción del área), de norte a sur y las islas mar adentro.
const POSICION_ISLAS := {
	2: Vector2(0.17, 0.30),
	1: Vector2(0.43, 0.22),
	3: Vector2(0.70, 0.36),
	4: Vector2(0.40, 0.72),
	5: Vector2(0.80, 0.78),
}
const ESCALA_ISLA := 2.0
const TAM_ISLA := Vector2(112, 96)

var _seleccionado := -1
var _contenido: Control
var _pagina_refugio: Control
var _pagina_biopedia: Control
var _pagina_mis_especies: Control
var _pagina_perfil: Control
var _biopedia: Biopedia
var _mis_especies: Biopedia
var _perfil: Perfil
var _botones_nav: Dictionary = {}

var _mapa: Control
var _islas: Dictionary = {}          # id_bioma -> {"boton", "burbuja", "etiqueta", "textura"}
var _barra_salud: ProgressBar
var _texto_salud: Label
var _texto_pr: Label
var _texto_nivel: Label
var _titulo_bioma: Label
var _estado_bioma: Label
var _explorar: Button
var _especies_cercanas: GridContainer


func _ready() -> void:
	theme = TemaFaunetra.obtener()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var oceano := Oceano.new()
	oceano.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(oceano)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	raiz.add_child(_crear_cabecera())

	_contenido = MarginContainer.new()
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for lado in ["left", "right", "top", "bottom"]:
		_contenido.add_theme_constant_override("margin_" + lado, 10)
	raiz.add_child(_contenido)

	_pagina_refugio = _crear_pagina_refugio()
	_contenido.add_child(_pagina_refugio)
	_pagina_biopedia = _envolver(_crear_biopedia(false))
	_contenido.add_child(_pagina_biopedia)
	_pagina_mis_especies = _envolver(_crear_biopedia(true))
	_contenido.add_child(_pagina_mis_especies)
	_perfil = Perfil.new()
	_pagina_perfil = _envolver(_perfil)
	_contenido.add_child(_pagina_perfil)

	raiz.add_child(_crear_navegacion())

	GameState.salud_actualizada.connect(_on_estado_cambiado.unbind(2))
	GameState.bioma_desbloqueado.connect(_on_estado_cambiado.unbind(1))
	resized.connect(_ubicar_islas)
	hide()


func _on_estado_cambiado() -> void:
	if visible and _pagina_refugio.visible:
		_refrescar_mapa()


## Muestra el menú. `pagina`: "refugio", "biopedia", "mis_especies" o "perfil".
func abrir(pagina: String = "refugio") -> void:
	if _seleccionado < 0 or not GameState.esta_desbloqueado(_seleccionado):
		_seleccionado = GameState.bioma_actual_id if GameState.bioma_actual_id > 0 else GameState.ORDEN_BIOMAS[0]
	show()
	move_to_front()
	_ir_a(pagina)


func abrir_especie(data: EspecieData) -> void:
	abrir("biopedia")
	_biopedia.mostrar_especie(data)


# --- Cabecera -------------------------------------------------------------------------------

func _crear_cabecera() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TemaFaunetra.caja(TemaFaunetra.CREMA, TemaFaunetra.BORDE, 0, 0, 10))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	panel.add_child(fila)

	var logo := TextureRect.new()
	logo.texture = TemaFaunetra.icono("montana")
	logo.custom_minimum_size = Vector2(48, 48)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fila.add_child(logo)
	var marca := VBoxContainer.new()
	marca.add_theme_constant_override("separation", -4)
	var nombre := Label.new()
	nombre.text = "FAUNETRA"
	nombre.add_theme_font_size_override("font_size", 30)
	nombre.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	marca.add_child(nombre)
	var lema := Label.new()
	lema.text = "Conoce · Explora · Protege"
	lema.add_theme_font_size_override("font_size", 13)
	lema.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	marca.add_child(lema)
	fila.add_child(marca)

	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)

	var salud := _tarjeta_cabecera("hoja")
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	_texto_salud = Label.new()
	_texto_salud.add_theme_font_size_override("font_size", 13)
	columna.add_child(_texto_salud)
	_barra_salud = ProgressBar.new()
	_barra_salud.custom_minimum_size = Vector2(170, 12)
	_barra_salud.show_percentage = false
	columna.add_child(_barra_salud)
	salud.get_child(0).add_child(columna)
	fila.add_child(salud)

	var pr := _tarjeta_cabecera("hoja")
	_texto_pr = Label.new()
	_texto_pr.add_theme_font_size_override("font_size", 13)
	pr.get_child(0).add_child(_texto_pr)
	fila.add_child(pr)

	var perfil := _tarjeta_cabecera("persona")
	_texto_nivel = Label.new()
	_texto_nivel.add_theme_font_size_override("font_size", 13)
	perfil.get_child(0).add_child(_texto_nivel)
	fila.add_child(perfil)
	return panel


func _tarjeta_cabecera(icono: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 12, 2, 8))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	p.add_child(fila)
	var t := TextureRect.new()
	t.texture = TemaFaunetra.icono(icono)
	t.custom_minimum_size = Vector2(28, 28)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(t)
	return p


# --- Página Refugio (mapa de mundos) ---------------------------------------------------------

func _crear_pagina_refugio() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)

	_mapa = Control.new()
	_mapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapa.size_flags_stretch_ratio = 2.3
	_mapa.clip_contents = true
	fila.add_child(_mapa)
	# Las islas se ubican según el tamaño del área del mapa, que se conoce recién tras el primer acomodo.
	_mapa.resized.connect(_ubicar_islas)
	for id in GameState.ORDEN_BIOMAS:
		_crear_isla(id)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)
	_titulo_bioma = Label.new()
	_titulo_bioma.add_theme_font_size_override("font_size", 22)
	_titulo_bioma.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_titulo_bioma)
	_estado_bioma = Label.new()
	_estado_bioma.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado_bioma.add_theme_font_size_override("font_size", 14)
	_estado_bioma.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	columna.add_child(_estado_bioma)

	_explorar = Button.new()
	_explorar.icon = TemaFaunetra.icono("brujula")
	_explorar.custom_minimum_size = Vector2(0, 56)
	_explorar.add_theme_font_size_override("font_size", 22)
	_explorar.add_theme_stylebox_override("normal", TemaFaunetra.caja(TemaFaunetra.VERDE, TemaFaunetra.VERDE_PRESIONADO, 28, 3, 10))
	_explorar.add_theme_stylebox_override("hover", TemaFaunetra.caja(TemaFaunetra.VERDE_HOVER, TemaFaunetra.VERDE_PRESIONADO, 28, 3, 10))
	_explorar.add_theme_stylebox_override("disabled", TemaFaunetra.caja(Color("#B9B6A6"), Color("#A3A090"), 28, 3, 10))
	_explorar.pressed.connect(_on_explorar)
	columna.add_child(_explorar)

	var titulo := HBoxContainer.new()
	var icono := TextureRect.new()
	icono.texture = TemaFaunetra.icono("hoja")
	icono.custom_minimum_size = Vector2(22, 22)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	titulo.add_child(icono)
	var l := Label.new()
	l.text = "Especies cercanas"
	l.add_theme_font_size_override("font_size", 17)
	titulo.add_child(l)
	columna.add_child(titulo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)
	_especies_cercanas = GridContainer.new()
	_especies_cercanas.columns = 3
	_especies_cercanas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_especies_cercanas.add_theme_constant_override("h_separation", 6)
	_especies_cercanas.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_especies_cercanas)
	return fila


func _crear_isla(id_bioma: int) -> void:
	var boton := TextureButton.new()
	boton.texture_normal = TemaFaunetra.isla(id_bioma)
	boton.ignore_texture_size = true
	boton.stretch_mode = TextureButton.STRETCH_SCALE
	boton.size = TAM_ISLA * ESCALA_ISLA
	boton.pivot_offset = boton.size * 0.5
	boton.texture_click_mask = _mascara(boton.texture_normal)
	boton.pressed.connect(_seleccionar.bind(id_bioma))
	boton.mouse_entered.connect(_on_isla_hover.bind(id_bioma))
	boton.mouse_exited.connect(_pintar_isla.bind(id_bioma))
	_mapa.add_child(boton)

	var burbuja := PanelContainer.new()
	burbuja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burbuja.add_child(fila)
	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(28, 28)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", 13)
	fila.add_child(etiqueta)
	_mapa.add_child(burbuja)

	# Un animal ya descubierto del bioma pasea por la isla.
	var animal := AnimatedSprite2D.new()
	animal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boton.add_child(animal)
	_islas[id_bioma] = {"boton": boton, "burbuja": burbuja, "icono": icono, "etiqueta": etiqueta, "animal": animal}


func _on_isla_hover(id_bioma: int) -> void:
	if GameState.esta_desbloqueado(id_bioma):
		(_islas[id_bioma]["boton"] as TextureButton).self_modulate = Color(1.12, 1.12, 1.12)


## Máscara de clic: solo la isla (píxeles opacos) responde, no el océano alrededor.
func _mascara(tex: Texture2D) -> BitMap:
	var mapa := BitMap.new()
	mapa.create_from_image_alpha(tex.get_image())
	return mapa


func _ubicar_islas() -> void:
	if _mapa == null:
		return
	var area := _mapa.size
	var escala := clampf(minf(area.x / 640.0, area.y / 470.0) * ESCALA_ISLA, 1.2, 3.0)
	for id in _islas:
		var isla: Dictionary = _islas[id]
		var boton: TextureButton = isla["boton"]
		boton.size = TAM_ISLA * escala
		boton.pivot_offset = boton.size * 0.5
		var centro: Vector2 = POSICION_ISLAS.get(id, Vector2(0.5, 0.5)) * area
		boton.position = centro - boton.size * 0.5
		var burbuja: PanelContainer = isla["burbuja"]
		burbuja.reset_size()
		burbuja.position = Vector2(centro.x - burbuja.size.x * 0.5, boton.position.y - burbuja.size.y * 0.2)
		var animal: AnimatedSprite2D = isla["animal"]
		animal.position = boton.size * Vector2(0.62, 0.42)
		animal.scale = Vector2.ONE * escala * 0.5


func _refrescar_mapa() -> void:
	for id in _islas:
		_pintar_isla(id)
	var id := _seleccionado
	var estado := GameState.estado_bioma(id)
	var salud := GameState.salud(id)
	_barra_salud.value = salud
	_texto_salud.text = "Restauración: %s  %d%%" % [GameState.nombre_bioma(id), int(salud)]
	_texto_pr.text = "Puntos de restauración\n%d PR" % int(estado.get("pr", 0))
	var nivel := 1 + TriviaManager.xp_acumulada / 250
	_texto_nivel.text = "Guardián/a\nNv. %d" % nivel

	_titulo_bioma.text = GameState.nombre_bioma(id)
	var descubiertas := 0
	var total := 0
	for d in EspecieLoader.cargar_especies_del_bioma(id):
		total += 1
		if GameState.esta_descubierta(d.id_especie):
			descubiertas += 1
	if GameState.esta_desbloqueado(id):
		_estado_bioma.text = "Salud %d%% · %d/%d especies descubiertas · %d PR\nMeta: %d%% para abrir el siguiente bioma." % [
			int(salud), descubiertas, total, GameState.obtener_pr(id), int(GameState.UMBRAL_DESBLOQUEO)]
		_explorar.disabled = false
		_explorar.text = "Volver al refugio" if id == GameState.bioma_actual_id else "Explorar"
	else:
		_estado_bioma.text = "Bloqueado: sana %s hasta %d%% para llegar aquí." % [
			GameState.nombre_bioma(GameState.bioma_anterior(id)), int(GameState.UMBRAL_DESBLOQUEO)]
		_explorar.disabled = true
		_explorar.text = "Bloqueado"
	_refrescar_especies_cercanas(id)


func _pintar_isla(id: int) -> void:
	var isla: Dictionary = _islas[id]
	var boton: TextureButton = isla["boton"]
	var desbloqueado := GameState.esta_desbloqueado(id)
	boton.self_modulate = Color.WHITE if desbloqueado else Color(0.55, 0.58, 0.6)
	var seleccionado := id == _seleccionado
	var burbuja: PanelContainer = isla["burbuja"]
	burbuja.add_theme_stylebox_override("panel", TemaFaunetra.caja(
		TemaFaunetra.VERDE_CLARO if seleccionado else TemaFaunetra.CREMA,
		TemaFaunetra.VERDE if seleccionado else TemaFaunetra.BORDE, 12, 3 if seleccionado else 2, 6))
	(isla["icono"] as TextureRect).texture = TemaFaunetra.icono(TemaFaunetra.ICONO_BIOMA[id] if desbloqueado else "candado")
	(isla["etiqueta"] as Label).text = "%s\n%s" % [GameState.nombre_bioma(id), ("%d%%" % int(GameState.salud(id))) if desbloqueado else "Bloqueado"]
	_animar_seleccion(boton, seleccionado)
	_poner_animal(id, isla["animal"])
	_ubicar_islas.call_deferred()


func _animar_seleccion(boton: TextureButton, activo: bool) -> void:
	if boton.has_meta("tween"):
		var anterior: Tween = boton.get_meta("tween")
		if anterior and anterior.is_valid():
			anterior.kill()
	boton.scale = Vector2.ONE
	if not activo:
		return
	var tween := boton.create_tween().set_loops()
	tween.tween_property(boton, "scale", Vector2.ONE * 1.04, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(boton, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	boton.set_meta("tween", tween)


func _poner_animal(id: int, sprite: AnimatedSprite2D) -> void:
	sprite.visible = false
	for d in EspecieLoader.fauna_del_bioma(id):
		if d.escena == null or not GameState.esta_descubierta(d.id_especie):
			continue
		var nodo := d.escena.instantiate()
		var original := nodo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if original and original.sprite_frames:
			sprite.sprite_frames = original.sprite_frames
			sprite.play(original.animation)
			sprite.visible = true
		nodo.free()
		return


func _refrescar_especies_cercanas(id: int) -> void:
	for hijo in _especies_cercanas.get_children():
		hijo.queue_free()
	var especies := EspecieLoader.fauna_del_bioma(id)
	especies.sort_custom(_descubiertas_primero)
	for d in especies.slice(0, 9):
		var conocida := GameState.esta_descubierta(d.id_especie)
		var b := Button.new()
		b.custom_minimum_size = Vector2(82, 84)
		b.icon = EspecieLoader.textura_de(d)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = d.nombre_comun if conocida else "???"
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		TemaFaunetra.estilizar_chip(b)
		b.add_theme_stylebox_override("normal", TemaFaunetra.caja(TemaFaunetra.COLOR_BIOMA.get(id, Color.WHITE) if conocida else TemaFaunetra.CREMA_OSCURA, TemaFaunetra.BORDE, 10, 2, 4))
		if not conocida:
			for estado in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				b.add_theme_color_override(estado, Color(0.16, 0.2, 0.17, 0.85))
		b.pressed.connect(abrir_especie.bind(d))
		_especies_cercanas.add_child(b)


func _descubiertas_primero(a: EspecieData, b: EspecieData) -> bool:
	return GameState.esta_descubierta(a.id_especie) and not GameState.esta_descubierta(b.id_especie)


func _seleccionar(id_bioma: int) -> void:
	_seleccionado = id_bioma
	_refrescar_mapa()


func _on_explorar() -> void:
	if not GameState.esta_desbloqueado(_seleccionado):
		return
	hide()
	if _seleccionado != GameState.bioma_actual_id:
		EventBus.cambiar_bioma_solicitado.emit(_seleccionado)


# --- Navegación inferior -----------------------------------------------------------------------

func _crear_navegacion() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TemaFaunetra.caja(TemaFaunetra.CREMA, TemaFaunetra.BORDE, 0, 0, 6))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	panel.add_child(fila)
	var grupo := ButtonGroup.new()
	for item in [["refugio", "Refugio", "casa"], ["biopedia", "Biopedia", "libro"], ["mis_especies", "Mis especies", "huella"], ["perfil", "Perfil", "persona"]]:
		var b := Button.new()
		b.text = item[1]
		b.icon = TemaFaunetra.icono(item[2])
		b.toggle_mode = true
		b.button_group = grupo
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 46
		TemaFaunetra.estilizar_chip(b)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", TemaFaunetra.caja(TemaFaunetra.VERDE_CLARO, TemaFaunetra.VERDE, 12, 2, 6))
		b.add_theme_stylebox_override("hover_pressed", TemaFaunetra.caja(TemaFaunetra.VERDE_CLARO, TemaFaunetra.VERDE, 12, 2, 6))
		b.add_theme_color_override("font_pressed_color", TemaFaunetra.VERDE)
		b.add_theme_color_override("font_hover_pressed_color", TemaFaunetra.VERDE)
		b.pressed.connect(_ir_a.bind(item[0]))
		fila.add_child(b)
		_botones_nav[item[0]] = b
	return panel


func _ir_a(pagina: String) -> void:
	_pagina_refugio.visible = pagina == "refugio"
	_pagina_biopedia.visible = pagina == "biopedia"
	_pagina_mis_especies.visible = pagina == "mis_especies"
	_pagina_perfil.visible = pagina == "perfil"
	for clave in _botones_nav:
		(_botones_nav[clave] as Button).set_pressed_no_signal(clave == pagina)
	match pagina:
		"refugio":
			_refrescar_mapa()
		"biopedia":
			_biopedia.refrescar()
		"mis_especies":
			_mis_especies.refrescar()
		"perfil":
			_perfil.refrescar()


func _crear_biopedia(solo_descubiertas: bool) -> Biopedia:
	var b := Biopedia.new()
	b.solo_descubiertas = solo_descubiertas
	if solo_descubiertas:
		_mis_especies = b
	else:
		_biopedia = b
	return b


func _envolver(contenido: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_child(contenido)
	return panel


## Fondo de océano con olas suaves animadas.
class Oceano extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TemaFaunetra.OCEANO)
		var franjas := 8
		for i in franjas:
			var y := size.y * (float(i) + 0.5) / franjas
			draw_rect(Rect2(0, y, size.x, size.y / franjas * 0.45), Color(TemaFaunetra.OCEANO_PROFUNDO, 0.18))
		var semilla := 0
		for fila in range(0, int(size.y), 46):
			for col in range(0, int(size.x), 90):
				semilla += 1
				var x := col + 30 * sin(semilla * 1.7) + 6 * sin(_t * 0.8 + semilla)
				var y := fila + 12 * cos(semilla * 2.3)
				draw_line(Vector2(x, y), Vector2(x + 14, y), Color(1, 1, 1, 0.35), 2.0)
				draw_line(Vector2(x + 18, y + 3), Vector2(x + 24, y + 3), Color(1, 1, 1, 0.25), 2.0)
