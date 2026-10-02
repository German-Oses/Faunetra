extends HBoxContainer

## Escáner de Especies (puzzle de percepción visual con el Lente Ancestral).
## Una expedición tiene RONDAS rondas: en cada una, una especie del bioma se camufla en el
## paisaje; el retículo del escáner disipa el camuflaje cerca de ella. Al encontrarla, el
## jugador la identifica entre 4 opciones. Acertar da PR y la registra en la Biopedia.
## A la derecha: tarjetas de repetición espaciada y del puzzle acústico.

signal abrir_puzzle_acustico

const RONDAS := 5
const RECOMPENSA_PR := 35
const ETIQUETAS_REPASO: Array[String] = ["24 h", "3 días", "7 días"]

var _visor: VisorEscaner
var _progreso: PuntosProgreso
var _instruccion_titulo: Label
var _instruccion_texto: Label
var _resultado: Label
var _boton_zoom: Button
var _boton_sonido: Button
var _reproductor: AudioStreamPlayer
var _opciones: GridContainer
var _siguiente: Button
var _repaso_nombre: Label
var _repaso_chips: HBoxContainer
var _repaso_boton: Button

var _objetivo: EspecieData
var _ronda := -1                       # -1 = sin expedición en curso
var _resultados: Array[int] = []       # 0 pendiente, 1 acierto, 2 error
var _usadas: Array[EspecieData] = []
var _pr_ganados := 0
var _respondida := false
var _ultima_identificada: EspecieData


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_reproductor = AudioStreamPlayer.new()
	add_child(_reproductor)
	add_child(_crear_columna_escaner())
	add_child(_crear_columna_lateral())
	GameState.repasos_actualizados.connect(_refrescar_repaso)


## La Tableta llama esto al mostrar la pestaña: retoma la expedición o empieza una nueva.
func al_mostrar() -> void:
	if _ronda < 0:
		_iniciar_expedicion()
	_refrescar_repaso()


# --- Construcción ---------------------------------------------------------------------------

func _crear_columna_escaner() -> Control:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.size_flags_stretch_ratio = 1.8
	columna.add_theme_constant_override("separation", 8)

	var cabecera := HBoxContainer.new()
	cabecera.add_child(_icono("escaner", 32))
	var titulo := Label.new()
	titulo.text = "Escáner de Especies"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(titulo)
	_progreso = PuntosProgreso.new()
	_progreso.custom_minimum_size = Vector2(190, 28)
	cabecera.add_child(_progreso)
	columna.add_child(cabecera)

	var instruccion := PanelContainer.new()
	instruccion.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 12, 2, 8))
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 0)
	instruccion.add_child(textos)
	_instruccion_titulo = Label.new()
	_instruccion_titulo.add_theme_font_size_override("font_size", 17)
	textos.add_child(_instruccion_titulo)
	_instruccion_texto = Label.new()
	_instruccion_texto.add_theme_font_size_override("font_size", 13)
	_instruccion_texto.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	_instruccion_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(_instruccion_texto)
	columna.add_child(instruccion)

	var marco := PanelContainer.new()
	marco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco.add_theme_stylebox_override("panel", TemaFaunetra.caja(TemaFaunetra.VERDE_PRESIONADO, TemaFaunetra.VERDE_PRESIONADO, 14, 3, 3))
	columna.add_child(marco)
	_visor = VisorEscaner.new()
	_visor.custom_minimum_size = Vector2(380, 200)
	_visor.encontrado.connect(_on_encontrado)
	_visor.fallo.connect(_on_fallo_visor)
	marco.add_child(_visor)

	_boton_zoom = _boton_flotante("lupa", "Zoom")
	_boton_zoom.toggle_mode = true
	_boton_zoom.toggled.connect(func(activo: bool) -> void: _visor.zoom = activo)
	_boton_zoom.position = Vector2(10, 10)
	_visor.add_child(_boton_zoom)
	_boton_sonido = _boton_flotante("sonido", "Sonido")
	_boton_sonido.pressed.connect(_reproducir_pista)
	_boton_sonido.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_boton_sonido.position += Vector2(-96, 10)
	_visor.add_child(_boton_sonido)

	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	_resultado = Label.new()
	_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resultado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resultado.add_theme_font_size_override("font_size", 14)
	pie.add_child(_resultado)
	_siguiente = Button.new()
	_siguiente.custom_minimum_size = Vector2(170, 40)
	_siguiente.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_siguiente.pressed.connect(_on_siguiente)
	pie.add_child(_siguiente)
	columna.add_child(pie)
	return columna


func _crear_columna_lateral() -> Control:
	var columna := VBoxContainer.new()
	columna.custom_minimum_size.x = 330
	columna.add_theme_constant_override("separation", 10)

	var panel_opciones := PanelContainer.new()
	panel_opciones.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 14, 2, 10))
	var caja := VBoxContainer.new()
	panel_opciones.add_child(caja)
	caja.add_child(_titulo_con_icono("huella", "Opciones", ""))
	_opciones = GridContainer.new()
	_opciones.columns = 2
	_opciones.add_theme_constant_override("h_separation", 8)
	_opciones.add_theme_constant_override("v_separation", 8)
	caja.add_child(_opciones)
	columna.add_child(panel_opciones)

	var repaso := PanelContainer.new()
	repaso.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 14, 2, 10))
	var caja_repaso := VBoxContainer.new()
	repaso.add_child(caja_repaso)
	caja_repaso.add_child(_titulo_con_icono("hoja", "Repetición espaciada", "Refuerza lo aprendido"))
	_repaso_nombre = Label.new()
	_repaso_nombre.add_theme_font_size_override("font_size", 13)
	_repaso_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja_repaso.add_child(_repaso_nombre)
	_repaso_chips = HBoxContainer.new()
	_repaso_chips.add_theme_constant_override("separation", 4)
	caja_repaso.add_child(_repaso_chips)
	_repaso_boton = Button.new()
	_repaso_boton.text = "Repasar ahora"
	_repaso_boton.pressed.connect(_on_repasar)
	caja_repaso.add_child(_repaso_boton)
	columna.add_child(repaso)

	var acustico := PanelContainer.new()
	acustico.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 14, 2, 10))
	var caja_acustico := VBoxContainer.new()
	acustico.add_child(caja_acustico)
	caja_acustico.add_child(_titulo_con_icono("sonido", "Puzzle acústico", "Escucha los sonidos de la fauna"))
	var fila := HBoxContainer.new()
	var play := Button.new()
	play.icon = TemaFaunetra.icono("play")
	play.flat = true
	play.tooltip_text = "Ir al puzzle acústico"
	play.pressed.connect(func() -> void: abrir_puzzle_acustico.emit())
	fila.add_child(play)
	var onda := OndaSonora.new()
	onda.custom_minimum_size = Vector2(200, 36)
	onda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(onda)
	caja_acustico.add_child(fila)
	columna.add_child(acustico)
	return columna


func _icono(nombre: String, tam: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = TemaFaunetra.icono(nombre)
	t.custom_minimum_size = Vector2(tam, tam)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


func _titulo_con_icono(icono: String, titulo: String, subtitulo: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_child(_icono(icono, 28))
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", -2)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 16)
	textos.add_child(t)
	if subtitulo != "":
		var s := Label.new()
		s.text = subtitulo
		s.add_theme_font_size_override("font_size", 12)
		s.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
		textos.add_child(s)
	fila.add_child(textos)
	return fila


func _boton_flotante(icono: String, texto: String) -> Button:
	var b := Button.new()
	b.icon = TemaFaunetra.icono(icono)
	b.text = texto
	b.custom_minimum_size = Vector2(86, 40)
	b.add_theme_font_size_override("font_size", 13)
	TemaFaunetra.estilizar_chip(b)
	b.add_theme_stylebox_override("normal", TemaFaunetra.caja(Color(1, 1, 1, 0.88), TemaFaunetra.BORDE, 12, 2, 6))
	return b


# --- Expedición ---------------------------------------------------------------------------------

func _iniciar_expedicion() -> void:
	_ronda = 0
	_pr_ganados = 0
	_usadas.clear()
	_resultados.clear()
	for i in RONDAS:
		_resultados.append(0)
	_preparar_ronda()


func _candidatas() -> Array[EspecieData]:
	var todas := EspecieLoader.cargar_especies_del_bioma(GameState.bioma_actual_id).filter(
		func(d: EspecieData) -> bool: return EspecieLoader.textura_de(d) != null)
	var nuevas := todas.filter(func(d: EspecieData) -> bool: return not _usadas.has(d))
	return nuevas if not nuevas.is_empty() else todas


func _preparar_ronda() -> void:
	_respondida = false
	_resultado.text = ""
	_progreso.actualizar(_resultados, _ronda)
	var candidatas := _candidatas()
	if candidatas.size() < 2:
		_instruccion_titulo.text = "Sin especies para escanear"
		_instruccion_texto.text = "Este bioma todavía no tiene especies con imagen."
		_visor.preparar(null, GameState.bioma_actual_id)
		_limpiar_opciones()
		_siguiente.visible = false
		return
	_objetivo = candidatas.pick_random()
	_usadas.append(_objetivo)
	_visor.preparar(_objetivo, GameState.bioma_actual_id)
	_instruccion_titulo.text = "Identifica la especie oculta · Ronda %d de %d" % [_ronda + 1, RONDAS]
	_instruccion_texto.text = "Observa bien el entorno y mueve el escáner: cerca de la especie, el camuflaje se disipa. Haz clic sobre ella."
	_boton_sonido.disabled = EspecieLoader.es_flora(_objetivo)
	_boton_sonido.tooltip_text = "Las plantas no emiten sonidos." if _boton_sonido.disabled else "Escucha una pista sonora."
	_crear_opciones()
	_siguiente.visible = false


func _crear_opciones() -> void:
	_limpiar_opciones()
	var opciones: Array[EspecieData] = [_objetivo]
	var del_bioma := EspecieLoader.cargar_especies_del_bioma(_objetivo.id_bioma).filter(
		func(d: EspecieData) -> bool: return d != _objetivo and EspecieLoader.textura_de(d) != null)
	del_bioma.shuffle()
	for d in del_bioma.slice(0, 3):
		opciones.append(d)
	opciones.shuffle()
	for d in opciones:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 58)
		b.icon = EspecieLoader.textura_de(d)
		b.expand_icon = true
		b.text = d.nombre_comun
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_constant_override("icon_max_width", 48)
		TemaFaunetra.estilizar_chip(b)
		b.disabled = true
		b.tooltip_text = "Primero encuentra la especie en el paisaje."
		b.pressed.connect(_on_opcion.bind(d, b))
		b.set_meta("especie", d)
		_opciones.add_child(b)


func _limpiar_opciones() -> void:
	for hijo in _opciones.get_children():
		_opciones.remove_child(hijo)
		hijo.queue_free()


func _on_encontrado() -> void:
	_instruccion_titulo.text = "¡Especie localizada!"
	_instruccion_texto.text = "Ahora identifícala entre las opciones."
	_resultado.text = ""
	for b in _opciones.get_children():
		(b as Button).disabled = false
		(b as Button).tooltip_text = ""


func _on_fallo_visor() -> void:
	_resultado.text = "Nada por aquí… acerca el escáner y observa con atención."


func _on_opcion(elegida: EspecieData, boton: Button) -> void:
	if _respondida:
		return
	_respondida = true
	for b in _opciones.get_children():
		var btn := b as Button
		btn.disabled = true
		if btn.get_meta("especie") == _objetivo:
			btn.add_theme_stylebox_override("disabled", TemaFaunetra.caja(TemaFaunetra.VERDE_CLARO, TemaFaunetra.VERDE, 12, 3, 6))
	if elegida == _objetivo:
		_resultados[_ronda] = 1
		_pr_ganados += RECOMPENSA_PR
		GameState.agregar_pr(RECOMPENSA_PR)
		var nueva := GameState.descubrir_especie(_objetivo)
		_resultado.text = "¡Correcto! Es %s (%s). +%d PR.%s" % [_objetivo.nombre_comun, _objetivo.nombre_cientifico,
			RECOMPENSA_PR, " Nueva entrada en la Biopedia." if nueva else ""]
	else:
		_resultados[_ronda] = 2
		boton.add_theme_stylebox_override("disabled", TemaFaunetra.caja(Color("#F6D8CF"), Color("#C8463A"), 12, 3, 6))
		_resultado.text = "Era %s. Pista para recordarla: %s (Sin castigo.)" % [_objetivo.nombre_comun, _objetivo.rol_ecologico]
	_ultima_identificada = _objetivo
	_visor.revelar()
	_progreso.actualizar(_resultados, _ronda)
	_refrescar_repaso()
	_siguiente.visible = true
	_siguiente.text = "Siguiente especie" if _ronda < RONDAS - 1 else "Ver resultados"


func _on_siguiente() -> void:
	if _ronda < 0:
		_iniciar_expedicion()
		return
	_ronda += 1
	if _ronda < RONDAS:
		_preparar_ronda()
		return
	var aciertos := _resultados.count(1)
	_instruccion_titulo.text = "Expedición completada: %d de %d especies identificadas" % [aciertos, RONDAS]
	_instruccion_texto.text = "Ganaste %d PR para %s. ¡Cada especie que reconoces es una que puedes proteger!" % [
		_pr_ganados, GameState.nombre_bioma(GameState.bioma_actual_id)]
	_progreso.actualizar(_resultados, RONDAS)
	_limpiar_opciones()
	_ronda = -1
	_siguiente.text = "Nueva expedición"


func _reproducir_pista() -> void:
	if _objetivo == null or EspecieLoader.es_flora(_objetivo):
		return
	_reproductor.stream = _objetivo.audio_canto if _objetivo.audio_canto else SintetizadorFauna.generar(_objetivo)
	_reproductor.play()


# --- Repetición espaciada -----------------------------------------------------------------------

func _especie_para_repaso() -> EspecieData:
	var pendientes := GameState.repasos_pendientes()
	if not pendientes.is_empty():
		return EspecieLoader.por_id(pendientes[0])
	if _ultima_identificada and GameState.esta_descubierta(_ultima_identificada.id_especie):
		return _ultima_identificada
	var reciente: EspecieData = null
	var fecha := -1.0
	for clave in GameState.descubiertas:
		if float(GameState.descubiertas[clave]) > fecha:
			fecha = float(GameState.descubiertas[clave])
			reciente = EspecieLoader.por_id(int(clave))
	return reciente


func _refrescar_repaso() -> void:
	if _repaso_chips == null:
		return
	for hijo in _repaso_chips.get_children():
		hijo.queue_free()
	var data := _especie_para_repaso()
	if data == null:
		_repaso_nombre.text = "Descubre especies para programar sus repasos."
		_repaso_boton.visible = false
		return
	var etapa := GameState.etapa_validacion(data.id_especie)
	var pendiente := GameState.repasos_pendientes().has(data.id_especie)
	_repaso_nombre.text = data.nombre_comun
	for i in ETIQUETAS_REPASO.size():
		var chip := PanelContainer.new()
		var fondo := TemaFaunetra.CREMA_OSCURA
		var borde := TemaFaunetra.BORDE
		if i < etapa:
			fondo = TemaFaunetra.VERDE_CLARO
			borde = TemaFaunetra.VERDE
		elif i == etapa and pendiente:
			fondo = Color("#FBE3B8")
			borde = Color("#D9A93C")
		chip.add_theme_stylebox_override("panel", TemaFaunetra.caja(fondo, borde, 12, 2, 4))
		var fila := HBoxContainer.new()
		chip.add_child(fila)
		if i < etapa:
			fila.add_child(_icono("check", 18))
		var l := Label.new()
		l.text = ETIQUETAS_REPASO[i]
		l.add_theme_font_size_override("font_size", 12)
		fila.add_child(l)
		_repaso_chips.add_child(chip)
	_repaso_boton.visible = pendiente
	_repaso_boton.set_meta("id_especie", data.id_especie)


func _on_repasar() -> void:
	EventBus.solicitar_trivia.emit("repaso", int(_repaso_boton.get_meta("id_especie")))


# --- Componentes visuales ----------------------------------------------------------------------

## Paisaje del bioma con la especie camuflada y el retículo del escáner.
class VisorEscaner extends Control:
	signal encontrado
	signal fallo

	const ANCHO_ESCENA := 192.0
	const ALTO_ESCENA := 112.0
	const RADIO_LENTE := 64.0
	const RADIO_ZOOM := 100.0

	var zoom := false
	var _fondo: Texture2D
	var _imagen_fondo: Image
	var _frames: SpriteFrames
	var _animacion: StringName
	var _textura_fija: Texture2D
	var _pos := Vector2(0.5, 0.7)      # posición normalizada en la escena
	var _follaje: Array[Dictionary] = []
	var _tinte := Color.WHITE
	var _activo := false
	var _revelado := false
	var _mouse := Vector2(-1000, -1000)
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		mouse_default_cursor_shape = Control.CURSOR_CROSS
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func preparar(data: EspecieData, id_bioma: int) -> void:
		_fondo = load("res://Assets/UI/escenas/escena_%d.png" % id_bioma)
		_imagen_fondo = _fondo.get_image() if _fondo else null
		_frames = null
		_textura_fija = null
		_activo = data != null
		_revelado = false
		_follaje.clear()
		if data == null:
			queue_redraw()
			return
		if data.escena:
			var nodo := data.escena.instantiate()
			var sprite := nodo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if sprite and sprite.sprite_frames:
				_frames = sprite.sprite_frames
				_animacion = sprite.animation
			nodo.free()
		if _frames == null:
			_textura_fija = EspecieLoader.textura_de(data)
		# Las especies se esconden en la mitad inferior (suelo y vegetación).
		_pos = Vector2(randf_range(0.16, 0.84), randf_range(0.56, 0.76))
		_tinte = _color_fondo(_pos)
		for i in 9:
			var angulo := randf() * TAU
			_follaje.append({
				"desfase": Vector2(cos(angulo), sin(angulo) * 0.7) * randf_range(0.15, 0.55),
				"tam": randf_range(0.18, 0.32),
				"color": _color_fondo(_pos + Vector2(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04))),
			})
		queue_redraw()

	func revelar() -> void:
		_revelado = true
		_activo = false
		queue_redraw()

	func _color_fondo(p: Vector2) -> Color:
		if _imagen_fondo == null:
			return Color(0.3, 0.5, 0.3)
		var x := clampi(int(p.x * ANCHO_ESCENA), 0, int(ANCHO_ESCENA) - 1)
		var y := clampi(int(p.y * ALTO_ESCENA), 0, int(ALTO_ESCENA) - 1)
		return _imagen_fondo.get_pixel(x, y)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		# Funciona con mouse y con el dedo: el retículo sigue al puntero (o al dedo al arrastrar)
		# y la búsqueda se confirma al soltar, para poder explorar el paisaje antes de elegir.
		if event is InputEventMouseMotion:
			_mouse = event.position
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_mouse = event.position
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _activo:
			_mouse = event.position
			if event.position.distance_to(_centro_objetivo()) <= _tam_objetivo().length() * 0.42:
				_revelado = true
				_activo = false
				encontrado.emit()
			else:
				fallo.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_mouse = Vector2(-1000, -1000)

	func _rect_escena() -> Rect2:
		var escala := maxf(size.x / ANCHO_ESCENA, size.y / ALTO_ESCENA)
		var tam := Vector2(ANCHO_ESCENA, ALTO_ESCENA) * escala
		return Rect2((size - tam) * 0.5, tam)

	func _escala_pixel() -> float:
		return _rect_escena().size.x / ANCHO_ESCENA

	func _centro_objetivo() -> Vector2:
		var r := _rect_escena()
		return r.position + _pos * r.size

	func _textura_actual() -> Texture2D:
		if _frames and _frames.has_animation(_animacion):
			var cantidad := _frames.get_frame_count(_animacion)
			if cantidad > 0:
				var cuadro := int(_t * _frames.get_animation_speed(_animacion)) % cantidad
				return _frames.get_frame_texture(_animacion, cuadro)
		return _textura_fija

	func _tam_objetivo() -> Vector2:
		var tex := _textura_actual()
		var alto := 26.0 * _escala_pixel()
		if tex == null:
			return Vector2.ONE * alto
		var t := tex.get_size()
		return t * (alto / maxf(t.x, t.y))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TemaFaunetra.VERDE_PRESIONADO)
		if _fondo:
			draw_texture_rect(_fondo, _rect_escena(), false)
		var radio := RADIO_ZOOM if zoom else RADIO_LENTE
		var dentro := Rect2(Vector2.ZERO, size).has_point(_mouse)
		var tex := _textura_actual()
		if tex:
			var centro := _centro_objetivo()
			var tam := _tam_objetivo()
			var cerca := _revelado or (dentro and _mouse.distance_to(centro) < radio)
			var rect := Rect2(centro - tam * 0.5, tam)
			draw_texture_rect(tex, rect, false, Color.WHITE if cerca else Color(_tinte, 0.55))
			if not cerca:
				# Follaje del entorno que tapa parte de la especie; el escáner lo disipa.
				var px := _escala_pixel()
				for f in _follaje:
					var c: Vector2 = centro + f["desfase"] * tam
					var lado: float = f["tam"] * tam.x
					var paso := maxf(px, 2.0)
					var y := -lado * 0.5
					while y < lado * 0.5:
						var x := -lado * 0.5
						while x < lado * 0.5:
							if Vector2(x, y).length() <= lado * 0.5:
								draw_rect(Rect2(c + Vector2(x, y), Vector2(paso, paso)), f["color"])
							x += paso
						y += paso
			if _revelado:
				draw_rect(rect.grow(6), Color(1, 0.85, 0.3), false, 3.0)
		_dibujar_esquinas()
		if dentro and _activo:
			_dibujar_reticulo(_mouse, radio)

	func _dibujar_reticulo(c: Vector2, radio: float) -> void:
		draw_circle(c, radio, Color(1, 1, 1, 0.08))
		draw_arc(c, radio + 1, 0, TAU, 64, Color(0, 0, 0, 0.35), 4.0)
		draw_arc(c, radio, 0, TAU, 64, Color.WHITE, 2.5)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * (radio - 12), c + d * (radio + 12), Color.WHITE, 3.0)
		draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color.WHITE, 2.0)
		draw_line(c + Vector2(0, -6), c + Vector2(0, 6), Color.WHITE, 2.0)

	func _dibujar_esquinas() -> void:
		var m := 14.0
		var l := 34.0
		var col := Color(1, 1, 1, 0.85)
		var esquinas := [Vector2(m, m), Vector2(size.x - m, m), Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]
		for i in esquinas.size():
			var p: Vector2 = esquinas[i]
			var sx := 1.0 if i % 2 == 0 else -1.0
			var sy := 1.0 if i < 2 else -1.0
			draw_line(p, p + Vector2(l * sx, 0), col, 4.0)
			draw_line(p, p + Vector2(0, l * sy), col, 4.0)


## Puntos de progreso de la expedición (pendiente, actual, acierto, error).
class PuntosProgreso extends Control:
	var _estados: Array[int] = []
	var _actual := 0

	func actualizar(estados: Array[int], actual: int) -> void:
		_estados = estados.duplicate()
		_actual = actual
		queue_redraw()

	func _draw() -> void:
		var n := _estados.size()
		if n == 0:
			return
		var paso := size.x / n
		var y := size.y * 0.5
		draw_line(Vector2(paso * 0.5, y), Vector2(size.x - paso * 0.5, y), TemaFaunetra.BORDE, 3.0)
		for i in n:
			var c := Vector2(paso * (i + 0.5), y)
			var relleno := TemaFaunetra.CREMA
			match _estados[i]:
				1:
					relleno = Color("#4E9A47")
				2:
					relleno = Color("#E07B39")
			var radio := 9.0 if i == _actual else 7.0
			draw_circle(c, radio + 2, TemaFaunetra.VERDE)
			draw_circle(c, radio, relleno)


## Forma de onda decorativa animada.
class OndaSonora extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var barras := int(size.x / 6)
		for i in barras:
			var alto := (0.25 + 0.75 * absf(sin(i * 0.7 + _t * 2.0) * sin(i * 0.23))) * size.y
			draw_rect(Rect2(i * 6, (size.y - alto) * 0.5, 3, alto), Color(TemaFaunetra.VERDE, 0.75))
