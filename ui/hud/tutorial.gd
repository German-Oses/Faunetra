extends PanelContainer

## Tutorial guiado de los primeros minutos. Cada paso avanza solo cuando el jugador
## realiza la acción pedida (abrir la Tableta, responder, disipar, limpiar, plantar).
## El botón relacionado parpadea para guiar la mirada. El progreso se guarda en GameState.

signal terminado

const PASOS := [
	{"titulo": "Bienvenida, guardián/a",
	 "texto": "La Niebla del Olvido cubre los refugios de Chile. Elige un refugio en el mapa y presiona «Explorar».",
	 "espera": "explorar"},
	{"titulo": "1 · Aprende",
	 "texto": "Abre la Tableta de Campo. Allí está la Biopedia y las trivias que te dan Esencia Vital (PR).",
	 "espera": "tableta", "resaltar": "tableta"},
	{"titulo": "2 · Gana Esencia Vital",
	 "texto": "En la pestaña «Trivias», presiona «Comenzar trivia del bioma» y responde. Cada acierto suma PR a este refugio.",
	 "espera": "trivia"},
	{"titulo": "3 · Sana: disipa la niebla",
	 "texto": "Elige «Disipar niebla» abajo y haz clic sobre una parcela cubierta de niebla junto al claro.",
	 "espera": "disipar", "resaltar": "disipar"},
	{"titulo": "4 · Sana: limpia el terreno",
	 "texto": "Elige «Limpiar» y haz clic sobre la basura o la especie invasora (los triángulos oscuros).",
	 "espera": "limpiar", "resaltar": "limpiar"},
	{"titulo": "5 · Sana: planta flora nativa",
	 "texto": "Elige «Plantar», escoge una especie en la barra y haz clic en una parcela libre. Algunas crecen más rápido junto a otras.",
	 "espera": "plantar", "resaltar": "plantar"},
	{"titulo": "6 · Atrae la fauna",
	 "texto": "Cuando tus plantas crezcan sanas llegarán animales nativos. En la Biopedia, cada animal te dice qué plantas necesita. ¡Sana el refugio hasta 75% para abrir el siguiente!",
	 "espera": "boton"},
]

var hud: Control
var _titulo: Label
var _texto: Label
var _contador: Label
var _boton: Button
var _tween_resalte: Tween
var _resaltado: CanvasItem


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -260
	offset_right = 260
	offset_top = 64
	add_theme_stylebox_override("panel", TemaFaunetra.caja(TemaFaunetra.CREMA, TemaFaunetra.VERDE, 14, 3, 12))

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	add_child(columna)
	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	var icono := TextureRect.new()
	icono.texture = TemaFaunetra.icono("brujula")
	icono.custom_minimum_size = Vector2(28, 28)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cabecera.add_child(icono)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 18)
	_titulo.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_titulo)
	_contador = Label.new()
	_contador.add_theme_font_size_override("font_size", 12)
	_contador.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	cabecera.add_child(_contador)

	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size.x = 490
	_texto.add_theme_font_size_override("font_size", 14)
	columna.add_child(_texto)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	columna.add_child(botones)
	var omitir := Button.new()
	omitir.text = "Omitir tutorial"
	omitir.flat = true
	omitir.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	omitir.pressed.connect(_terminar)
	botones.add_child(omitir)
	_boton = Button.new()
	_boton.text = "¡Entendido!"
	_boton.pressed.connect(func() -> void: avisar("boton"))
	botones.add_child(_boton)

	EventBus.accion_terreno.connect(avisar)
	TriviaManager.respuesta_evaluada.connect(func(_c: bool, _r: String, _x: int) -> void: avisar("trivia"))
	_mostrar_paso()


## Notifica que ocurrió algo; si es lo que espera el paso actual, avanza.
func avisar(evento: String) -> void:
	var paso := GameState.tutorial_paso
	if paso >= PASOS.size() or PASOS[paso]["espera"] != evento:
		return
	GameState.tutorial_paso = paso + 1
	GameState.marcar_cambios()
	if GameState.tutorial_paso >= PASOS.size():
		_terminar()
	else:
		_mostrar_paso()


func _mostrar_paso() -> void:
	var paso: Dictionary = PASOS[GameState.tutorial_paso]
	_titulo.text = paso["titulo"]
	_texto.text = paso["texto"]
	_contador.text = "%d/%d" % [GameState.tutorial_paso + 1, PASOS.size()]
	_boton.visible = paso["espera"] == "boton"
	# En el menú de mundos la tarjeta va sobre la lista de especies cercanas, para no tapar las islas.
	if paso["espera"] == "explorar":
		anchor_left = 1.0
		anchor_right = 1.0
		offset_left = -346
		offset_right = -14
		offset_top = 290
		_texto.custom_minimum_size.x = 300
	else:
		_texto.custom_minimum_size.x = 490
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = -260
		offset_right = 260
		offset_top = 64
	reset_size()
	_resaltar(hud.objetivo_tutorial(paso.get("resaltar", "")) if hud else null)


func _resaltar(objetivo: CanvasItem) -> void:
	if _tween_resalte:
		_tween_resalte.kill()
	if is_instance_valid(_resaltado):
		_resaltado.modulate = Color.WHITE
	_resaltado = objetivo
	if objetivo == null:
		return
	_tween_resalte = create_tween().set_loops()
	_tween_resalte.tween_property(objetivo, "modulate", Color(1.5, 1.4, 0.7), 0.45)
	_tween_resalte.tween_property(objetivo, "modulate", Color.WHITE, 0.45)


func _terminar() -> void:
	GameState.tutorial_paso = PASOS.size()
	GameState.marcar_cambios()
	_resaltar(null)
	terminado.emit()
	queue_free()
