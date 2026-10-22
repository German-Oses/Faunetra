extends Control

## Menú principal de Faunetra: mapa de Chile dividido en los biomas del juego (y un recuadro con
## las islas oceánicas), panel del bioma seleccionado con "Explorar" y especies cercanas, y barra
## de navegación inferior hacia la Biopedia, Mis especies y el Perfil.
## Cada bioma es una capa del mapa (Assets/UI/mapa_chile/zona_<id>.png, generada con
## herramientas/aseprite/mapa_chile.lua): responde al toque por su forma, los bloqueados se ven
## cubiertos por la niebla gris y los demás recuperan el color a medida que se restauran.
## En vertical (teléfono) el mapa va sobre el panel del bioma, la cabecera usa dos filas y la
## navegación muestra el ícono sobre el texto.

const Biopedia := preload("res://ui/tableta/biopedia.gd")
const Perfil := preload("res://ui/menu_mundos/perfil.gd")

const RUTA_ZONA := "res://Assets/UI/mapa_chile/zona_%d.png"
## Tamaño del dibujo del mapa (px) y, por bioma, el borde oriental de su zona a media altura
## (ahí se apoya su etiqueta) y dónde pasea su animal. Las anclas las imprime mapa_chile.lua.
const TAM_MAPA := Vector2(200, 300)
const ANCLA_ETIQUETA := {1: Vector2(121, 129), 2: Vector2(152, 54), 3: Vector2(102, 179), 4: Vector2(84, 247), 5: Vector2(3, 70)}
const POSICION_ANIMAL := {1: Vector2(104, 132), 2: Vector2(133, 58), 3: Vector2(88, 182), 4: Vector2(66, 236), 5: Vector2(26, 118)}
## Margen (px del dibujo) que se suma a la forma de cada zona para que sea fácil tocarla con el dedo.
const MARGEN_TOQUE := 4
## Color de cada zona: gris de niebla si está bloqueada; desbloqueada, desde COLOR_MINIMO hasta pleno
## al alcanzar la meta de restauración.
const COLOR_MINIMO := 0.62
const SHADER_ZONA := """
shader_type canvas_item;
uniform float color = 1.0;   // 0 = cubierta por la niebla, 1 = color pleno
uniform float brillo = 1.0;
void fragment() {
	vec4 c = COLOR;
	float gris = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 niebla = mix(vec3(gris), vec3(0.80, 0.84, 0.88), 0.4);
	COLOR = vec4(mix(niebla, c.rgb, color) * brillo, c.a);
}
"""

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
var _zonas: Dictionary = {}          # id_bioma -> {"boton", "burbuja", "icono", "etiqueta", "animal"}
var _barra_salud: ProgressBar
var _texto_salud: Label
var _texto_pr: Label
var _texto_nivel: Label
var _titulo_bioma: Label
var _estado_bioma: Label
var _explorar: Button
var _especies_cercanas: GridContainer
var _pagina_refugio_caja: BoxContainer
var _cabecera_fila1: HBoxContainer
var _cabecera_fila2: HBoxContainer
var _lema: Label
var _tarjeta_salud: PanelContainer
var _tarjeta_pr: PanelContainer


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
	_pagina_perfil = _envolver(_perfil, true)
	_contenido.add_child(_pagina_perfil)

	raiz.add_child(_crear_navegacion())

	GameState.salud_actualizada.connect(_on_estado_cambiado.unbind(2))
	GameState.bioma_desbloqueado.connect(_on_estado_cambiado.unbind(1))
	resized.connect(_ubicar_zonas)
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _reacomodar())
	_reacomodar()
	hide()


## Reorganiza cabecera, página del mapa y navegación según la orientación.
func _reacomodar() -> void:
	var vertical: bool = Pantalla.vertical
	# Cabecera: en vertical, la salud y los PR bajan a una segunda fila.
	for tarjeta in [_tarjeta_salud, _tarjeta_pr]:
		var destino := _cabecera_fila2 if vertical else _cabecera_fila1
		if tarjeta.get_parent() != destino:
			tarjeta.get_parent().remove_child(tarjeta)
			destino.add_child(tarjeta)
			if not vertical:
				destino.move_child(tarjeta, destino.get_child_count() - 2)   # antes del perfil
	_tarjeta_salud.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_FILL
	_cabecera_fila2.visible = vertical
	_lema.visible = not vertical
	# Página del mapa: Chile arriba y panel del bioma abajo.
	_pagina_refugio_caja.vertical = vertical
	_mapa.size_flags_stretch_ratio = 1.7 if vertical else 2.3
	_especies_cercanas.columns = 5 if vertical else 3
	# 5 fichas de 82 px: con 6 px de separación (434) no caben en los 432 px del panel en vertical.
	_especies_cercanas.add_theme_constant_override("h_separation", 4 if vertical else 6)
	for b in _botones_nav.values():
		(b as Button).vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if vertical else VERTICAL_ALIGNMENT_CENTER
		(b as Button).add_theme_font_size_override("font_size", 13 if vertical else 16)
		(b as Button).custom_minimum_size.y = 58 if vertical else 46
	_ubicar_zonas.call_deferred()


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
	var filas := VBoxContainer.new()
	panel.add_child(filas)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	filas.add_child(fila)
	_cabecera_fila1 = fila
	_cabecera_fila2 = HBoxContainer.new()
	_cabecera_fila2.add_theme_constant_override("separation", 10)
	filas.add_child(_cabecera_fila2)

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
	_lema = Label.new()
	_lema.text = "Conoce · Explora · Protege"
	_lema.add_theme_font_size_override("font_size", 13)
	_lema.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	marca.add_child(_lema)
	fila.add_child(marca)

	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)

	var salud := _tarjeta_cabecera("hoja")
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto_salud = Label.new()
	_texto_salud.add_theme_font_size_override("font_size", 13)
	_texto_salud.clip_text = true
	_texto_salud.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_texto_salud.custom_minimum_size.x = 120
	columna.add_child(_texto_salud)
	_barra_salud = ProgressBar.new()
	_barra_salud.custom_minimum_size = Vector2(120, 12)
	_barra_salud.show_percentage = false
	columna.add_child(_barra_salud)
	salud.get_child(0).add_child(columna)
	fila.add_child(salud)
	_tarjeta_salud = salud

	var pr := _tarjeta_cabecera("hoja")
	_texto_pr = Label.new()
	_texto_pr.add_theme_font_size_override("font_size", 13)
	pr.get_child(0).add_child(_texto_pr)
	fila.add_child(pr)
	_tarjeta_pr = pr

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
	var fila := BoxContainer.new()   # horizontal en PC; vertical en teléfono (ver _reacomodar)
	fila.add_theme_constant_override("separation", 12)
	_pagina_refugio_caja = fila

	_mapa = Control.new()
	_mapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapa.size_flags_stretch_ratio = 2.3
	_mapa.clip_contents = true
	fila.add_child(_mapa)
	# Las zonas se ubican según el tamaño del área del mapa, que se conoce recién tras el primer acomodo.
	_mapa.resized.connect(_ubicar_zonas)
	var shader := Shader.new()
	shader.code = SHADER_ZONA
	for id in GameState.ORDEN_BIOMAS:
		_crear_zona(id, shader)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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


func _crear_zona(id_bioma: int, shader: Shader) -> void:
	var boton := TextureButton.new()
	boton.texture_normal = load(RUTA_ZONA % id_bioma)
	boton.ignore_texture_size = true
	boton.stretch_mode = TextureButton.STRETCH_SCALE
	boton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boton.texture_click_mask = _mascara(boton.texture_normal)
	var material := ShaderMaterial.new()
	material.shader = shader
	boton.material = material
	boton.pressed.connect(_seleccionar.bind(id_bioma))
	boton.mouse_entered.connect(_on_zona_hover.bind(id_bioma))
	boton.mouse_exited.connect(_pintar_zona.bind(id_bioma))
	_mapa.add_child(boton)

	var burbuja := PanelContainer.new()
	burbuja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burbuja.add_child(fila)
	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(24, 24)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", 12)
	fila.add_child(etiqueta)
	_mapa.add_child(burbuja)

	# Un animal ya descubierto del bioma pasea por su zona.
	var animal := AnimatedSprite2D.new()
	animal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boton.add_child(animal)
	_zonas[id_bioma] = {"boton": boton, "burbuja": burbuja, "icono": icono, "etiqueta": etiqueta, "animal": animal}


func _on_zona_hover(id_bioma: int) -> void:
	if GameState.esta_desbloqueado(id_bioma):
		((_zonas[id_bioma]["boton"] as TextureButton).material as ShaderMaterial).set_shader_parameter("brillo", 1.12)


## Máscara de toque: la forma de la zona (píxeles opacos) más un margen, no el océano alrededor.
func _mascara(tex: Texture2D) -> BitMap:
	var mapa := BitMap.new()
	var imagen := tex.get_image()
	mapa.create_from_image_alpha(imagen)
	mapa.grow_mask(MARGEN_TOQUE, Rect2i(Vector2i.ZERO, imagen.get_size()))
	return mapa


func _ubicar_zonas() -> void:
	if _mapa == null:
		return
	var area := _mapa.size
	var escala := maxf(0.5, minf(area.x / TAM_MAPA.x, area.y / TAM_MAPA.y) * 0.97)
	var origen := ((area - TAM_MAPA * escala) * 0.5).floor()
	for id in _zonas:
		var zona: Dictionary = _zonas[id]
		var boton: TextureButton = zona["boton"]
		boton.position = origen
		boton.size = TAM_MAPA * escala
		var burbuja: PanelContainer = zona["burbuja"]
		burbuja.reset_size()
		var ancla: Vector2 = origen + ANCLA_ETIQUETA[id] * escala
		# Etiqueta al este de la zona (sobre el océano/Argentina); la insular, sobre su recuadro.
		var pos := Vector2(ancla.x, ancla.y - burbuja.size.y - 4) if id == 5 \
			else Vector2(ancla.x + 8, ancla.y - burbuja.size.y * 0.5)
		burbuja.position = pos.clamp(Vector2.ZERO, (area - burbuja.size).max(Vector2.ZERO))
		var animal: AnimatedSprite2D = zona["animal"]
		animal.position = POSICION_ANIMAL[id] * escala
		animal.scale = Vector2.ONE * maxf(1.0, escala * 0.45)


func _refrescar_mapa() -> void:
	for id in _zonas:
		_pintar_zona(id)
	var id := _seleccionado
	var estado: Dictionary = GameState.estado_bioma(id)
	var salud: float = GameState.salud(id)
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
			int(salud), descubiertas, total, GameState.obtener_pr(id), int(GameState.umbral_desbloqueo())]
		_explorar.disabled = false
		_explorar.text = "Volver al refugio" if id == GameState.bioma_actual_id else "Explorar"
	else:
		_estado_bioma.text = "Bloqueado: sana %s hasta %d%% para llegar aquí." % [
			GameState.nombre_bioma(GameState.bioma_anterior(id)), int(GameState.umbral_desbloqueo())]
		_explorar.disabled = true
		_explorar.text = "Bloqueado"
	_refrescar_especies_cercanas(id)


func _pintar_zona(id: int) -> void:
	var zona: Dictionary = _zonas[id]
	var boton: TextureButton = zona["boton"]
	var desbloqueado: bool = GameState.esta_desbloqueado(id)
	var material := boton.material as ShaderMaterial
	var avance := clampf(GameState.salud(id) / GameState.umbral_desbloqueo(), 0.0, 1.0)
	material.set_shader_parameter("color", lerpf(COLOR_MINIMO, 1.0, avance) if desbloqueado else 0.0)
	material.set_shader_parameter("brillo", 1.0)
	var seleccionado := id == _seleccionado
	var burbuja: PanelContainer = zona["burbuja"]
	burbuja.add_theme_stylebox_override("panel", TemaFaunetra.caja(
		TemaFaunetra.VERDE_CLARO if seleccionado else TemaFaunetra.CREMA,
		TemaFaunetra.VERDE if seleccionado else TemaFaunetra.BORDE, 12, 3 if seleccionado else 2, 5))
	(zona["icono"] as TextureRect).texture = TemaFaunetra.icono(TemaFaunetra.ICONO_BIOMA[id] if desbloqueado else "candado")
	(zona["etiqueta"] as Label).text = "%s\n%s" % [GameState.nombre_bioma(id), ("%d%%" % int(GameState.salud(id))) if desbloqueado else "Bloqueado"]
	_animar_seleccion(boton, seleccionado)
	_poner_animal(id, zona["animal"])
	_ubicar_zonas.call_deferred()


## La zona elegida late suavemente de brillo (no de tamaño: todas las capas comparten el rectángulo).
func _animar_seleccion(boton: TextureButton, activo: bool) -> void:
	if boton.has_meta("tween"):
		var anterior: Tween = boton.get_meta("tween")
		if anterior and anterior.is_valid():
			anterior.kill()
	if not activo:
		return
	var material := boton.material as ShaderMaterial
	var tween := boton.create_tween().set_loops()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("brillo", v), 1.0, 1.18, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("brillo", v), 1.18, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
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
		var conocida: bool = GameState.esta_descubierta(d.id_especie)
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


## `desplazable`: para páginas sin desplazamiento propio que pueden no caber (Perfil en un teléfono).
func _envolver(contenido: Control, desplazable := false) -> PanelContainer:
	var panel := PanelContainer.new()
	if desplazable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL   # si sobra alto, lo sigue llenando
		scroll.add_child(contenido)
		panel.add_child(scroll)
	else:
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
