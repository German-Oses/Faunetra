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
	 "texto": "Elige «Disipar niebla» abajo y toca una parcela cubierta de niebla junto al claro.",
	 "espera": "disipar", "resaltar": "disipar"},
	{"titulo": "4 · Sana: limpia el terreno",
	 "texto": "Elige «Limpiar» y toca la basura o la especie invasora (los triángulos oscuros).",
	 "espera": "limpiar", "resaltar": "limpiar"},
	{"titulo": "5 · Sana: planta flora nativa",
	 "texto": "Elige «Plantar», escoge una especie en la barra y toca una parcela libre. Algunas crecen más rápido junto a otras.",
	 "espera": "plantar", "resaltar": "plantar"},
	{"titulo": "6 · Atrae la fauna",
	 "texto": "Cuando tus plantas crezcan sanas llegarán animales nativos: tócalos para identificarlos y registrarlos en la Biopedia. En «Pistas del refugio» (arriba a la izquierda) verás qué plantas busca cada visitante. ¡Sana el refugio hasta {umbral}% para abrir el siguiente!",
	 "espera": "boton"},
]

var hud: Control
var _titulo: Label
var _texto: Label
var _contador: Label
var _boton: Button
var _tween_resalte: Tween
var _resaltado: CanvasItem
var _eventos_previos: Dictionary = {}   # eventos ocurridos antes de llegar a su paso


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
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void:
		if GameState.tutorial_paso < PASOS.size():
			_mostrar_paso())


## Notifica que ocurrió algo; si es lo que espera el paso actual, avanza.
func avisar(evento: String) -> void:
	var paso: int = GameState.tutorial_paso
	if paso >= PASOS.size():
		return
	if PASOS[paso]["espera"] != evento:
		# Acción adelantada (p. ej. disipar antes de llegar a ese paso): se recuerda para que el
		# paso se dé por cumplido al llegar a él.
		if evento != "boton":
			_eventos_previos[evento] = true
		return
	GameState.tutorial_paso = paso + 1
	GameState.marcar_cambios()
	GameState.registrar({"tipo": "tutorial", "detalle": "paso_completado=%d;evento=%s" % [paso + 1, evento]})
	if GameState.tutorial_paso >= PASOS.size():
		_terminar()
	else:
		_mostrar_paso()


func _mostrar_paso() -> void:
	var paso: Dictionary = PASOS[GameState.tutorial_paso]
	_titulo.text = paso["titulo"]
	_texto.text = str(paso["texto"]).replace("{umbral}", str(int(GameState.umbral_desbloqueo())))
	_contador.text = "%d/%d" % [GameState.tutorial_paso + 1, PASOS.size()]
	_boton.visible = paso["espera"] == "boton"
	reubicar()
	_resaltar(hud.objetivo_tutorial(paso.get("resaltar", "")) if hud else null)
	# Si la meta del paso ya se cumplió (acción hecha antes de tiempo), se avanza sola.
	if _meta_cumplida(str(paso["espera"])):
		avisar.call_deferred(str(paso["espera"]))


## Ubica la tarjeta según la orientación y el paso, sin tapar lo que el paso pide usar.
func reubicar() -> void:
	if GameState.tutorial_paso >= PASOS.size():
		return
	var espera: String = PASOS[GameState.tutorial_paso]["espera"]
	if Pantalla.vertical:
		# Teléfono: a todo el ancho y abajo. En el mapa de mundos, sobre la navegación; en el
		# refugio, justo sobre la barra de herramientas, para no tapar la barra superior, las
		# «Pistas del refugio» ni las pestañas de la Tableta.
		var en_mapa := espera == "explorar"
		_texto.custom_minimum_size.x = 0
		anchor_left = 0.0
		anchor_right = 1.0
		offset_left = 10
		offset_right = -10
		anchor_top = 1.0
		anchor_bottom = 1.0
		grow_vertical = Control.GROW_DIRECTION_BEGIN
		var alto_barra: float = hud.alto_barra_inferior() if hud and hud.has_method("alto_barra_inferior") else 70.0
		offset_bottom = -80.0 if en_mapa else -(alto_barra + 8.0)
		offset_top = offset_bottom
	elif espera == "explorar":
		anchor_top = 0.0
		anchor_bottom = 0.0
		grow_vertical = Control.GROW_DIRECTION_END
		anchor_left = 1.0
		anchor_right = 1.0
		offset_left = -346
		offset_right = -14
		offset_top = 290
		offset_bottom = offset_top
		_texto.custom_minimum_size.x = 300
	elif espera == "trivia":
		# La Tableta está abierta: la tarjeta baja para dejar libres sus pestañas y botones.
		anchor_top = 1.0
		anchor_bottom = 1.0
		grow_vertical = Control.GROW_DIRECTION_BEGIN
		_texto.custom_minimum_size.x = 490
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = -260
		offset_right = 260
		offset_bottom = -44
		offset_top = offset_bottom
	else:
		anchor_top = 0.0
		anchor_bottom = 0.0
		grow_vertical = Control.GROW_DIRECTION_END
		_texto.custom_minimum_size.x = 490
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = -260
		offset_right = 260
		# Bajo la barra superior (su alto varía con la fuente y el tema).
		var alto_sup: float = hud.alto_barra_superior() if hud and hud.has_method("alto_barra_superior") else 56.0
		offset_top = maxf(64.0, alto_sup + 8.0)
		offset_bottom = offset_top
	# El alto parte en cero y el tamaño mínimo lo hace crecer (hacia abajo o hacia arriba según
	# grow_vertical), así la tarjeta se ajusta al texto de cada paso.


## true si lo que pide el paso ya está hecho o ya no se puede hacer (p. ej. no queda niebla
## que disipar ni basura que limpiar), para que el tutorial no quede trabado.
func _meta_cumplida(espera: String) -> bool:
	if _eventos_previos.has(espera):
		return true
	var terreno := _buscar_terreno()
	if terreno == null:
		return false
	var celdas: Dictionary = terreno.get("celdas")
	if celdas.is_empty():
		return false
	match espera:
		"disipar":
			for c in celdas.values():
				if c.get("n", false):
					return false
			return true
		"limpiar":
			for c in celdas.values():
				if str(c.get("b", "")) != "":
					return false
			return true
	return false


func _buscar_terreno() -> Node:
	var raiz := get_tree().current_scene if is_inside_tree() else null
	return raiz.find_child("TerrenoRefugio", true, false) if raiz else null


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
	if GameState.tutorial_paso < PASOS.size():
		GameState.registrar({"tipo": "tutorial", "detalle": "omitido_en_paso=%d" % (GameState.tutorial_paso + 1)})
	GameState.tutorial_paso = PASOS.size()
	GameState.marcar_cambios()
	_resaltar(null)
	terminado.emit()
	queue_free()
