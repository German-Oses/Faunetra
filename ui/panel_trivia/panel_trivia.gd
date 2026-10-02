extends Control

## Panel modal de trivias narrativas. Tres modos:
## - ESPECIE: al tocar una planta/animal o al resolver una pista conceptual de la Biopedia.
## - BIOMA: trivias libres del bioma actual desde la Tableta (principal fuente de PR).
## - REPASO: validación de repetición espaciada; fallar no castiga, se reprograma.

enum Modo { ESPECIE, BIOMA, REPASO }

const COLOR_CORRECTA := Color(0.55, 1.0, 0.6)
const COLOR_INCORRECTA := Color(1.0, 0.55, 0.5)

var trivia_actual: TriviaData
var _modo := Modo.BIOMA
var _especie: EspecieData
var _respondida := false
var _inicio_ms := 0
var _uso_pista := false

var _encabezado_label: Label
var titulo_narrativo_label: Label
var _ficha_label: RichTextLabel
var _imagen: TextureRect
var _imagen_label: Label
var situacion_label: Label
var pregunta_label: Label
var pista_button: Button
var pista_label: Label
var opciones_container: VBoxContainer
var retroalimentacion_panel: PanelContainer
var retroalimentacion_label: Label
var _siguiente_button: Button
var _scroll: ScrollContainer


func _ready() -> void:
	EventBus.especie_seleccionada.connect(_on_especie_seleccionada)
	EventBus.solicitar_trivia.connect(_on_solicitar_trivia)
	_construir_interfaz()
	hide()


func _construir_interfaz() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = TemaFaunetra.obtener()

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + lado, 60)
	for lado in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + lado, 30)
	add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)

	var interior := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		interior.add_theme_constant_override("margin_" + lado, 16)
	panel.add_child(interior)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 10)
	interior.add_child(raiz)

	_encabezado_label = Label.new()
	_encabezado_label.modulate = Color(0.8, 0.9, 1.0)
	raiz.add_child(_encabezado_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	_scroll.add_child(vbox)

	titulo_narrativo_label = Label.new()
	titulo_narrativo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_narrativo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_narrativo_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(titulo_narrativo_label)

	_ficha_label = RichTextLabel.new()
	_ficha_label.bbcode_enabled = true
	_ficha_label.fit_content = true
	_ficha_label.scroll_active = false
	vbox.add_child(_ficha_label)

	# Imagen de referencia: el tutor la muestra cuando detecta dificultades.
	_imagen = TextureRect.new()
	_imagen.custom_minimum_size = Vector2(0, 140)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_imagen)
	_imagen_label = Label.new()
	_imagen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_imagen_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_imagen_label)

	situacion_label = Label.new()
	situacion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	situacion_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(situacion_label)

	pregunta_label = Label.new()
	pregunta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pregunta_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(pregunta_label)

	pista_button = Button.new()
	pista_button.text = "Pedir pista formativa"
	pista_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pista_button.pressed.connect(_on_pista_pressed)
	vbox.add_child(pista_button)

	pista_label = Label.new()
	pista_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pista_label.modulate = Color(1.0, 0.92, 0.6)
	vbox.add_child(pista_label)

	opciones_container = VBoxContainer.new()
	opciones_container.add_theme_constant_override("separation", 8)
	vbox.add_child(opciones_container)

	retroalimentacion_panel = PanelContainer.new()
	vbox.add_child(retroalimentacion_panel)
	retroalimentacion_label = Label.new()
	retroalimentacion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retroalimentacion_panel.add_child(retroalimentacion_label)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	botones.add_theme_constant_override("separation", 10)
	raiz.add_child(botones)

	_siguiente_button = Button.new()
	_siguiente_button.text = "Otra trivia"
	_siguiente_button.pressed.connect(_on_siguiente_pressed)
	botones.add_child(_siguiente_button)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.pressed.connect(_on_cerrar_pressed)
	botones.add_child(cerrar)


# --- Entradas -------------------------------------------------------------------------

func _on_especie_seleccionada(datos: EspecieData) -> void:
	_modo = Modo.ESPECIE
	_especie = datos
	_abrir(TriviaManager.obtener_trivia_adaptativa(datos.id_especie))


func _on_solicitar_trivia(modo: String, id_especie: int) -> void:
	_especie = EspecieLoader.por_id(id_especie)
	match modo:
		"repaso":
			_modo = Modo.REPASO
			_abrir(TriviaManager.trivia_para_repaso(id_especie))
		"especie":
			_modo = Modo.ESPECIE
			_abrir(TriviaManager.obtener_trivia_adaptativa(id_especie))
		_:
			_modo = Modo.BIOMA
			_abrir(TriviaManager.obtener_trivia_adaptativa(0, GameState.bioma_actual_id))


func _abrir(trivia: TriviaData) -> void:
	trivia_actual = trivia
	if trivia == null:
		EventBus.mensaje.emit("No hay trivias disponibles para esta especie todavía.")
		return
	if _modo != Modo.ESPECIE:
		_especie = EspecieLoader.por_id(trivia.id_especie)
	_mostrar_trivia(trivia)
	show()
	move_to_front()


# --- Presentación ------------------------------------------------------------------------

func _mostrar_trivia(trivia: TriviaData) -> void:
	_respondida = false
	_inicio_ms = Time.get_ticks_msec()
	_uso_pista = false
	_scroll.scroll_vertical = 0
	var nivel: String = TriviaManager.NOMBRES_DIFICULTAD[trivia.dificultad]
	var pr: int = TriviaManager.PR_POR_DIFICULTAD[trivia.dificultad]
	match _modo:
		Modo.REPASO:
			var etapa := GameState.etapa_validacion(trivia.id_especie)
			_encabezado_label.text = "Repaso de validación %d/%d · Nivel %s · +%d PR" % [
				etapa + 1, GameState.INTERVALOS_REPASO_DIAS.size(), nivel, pr + TriviaManager.PR_BONO_REPASO]
		_:
			_encabezado_label.text = "Trivia de %s · Nivel %s · +%d PR (Esencia Vital)" % [
				GameState.nombre_bioma(GameState.bioma_actual_id), nivel, pr]

	titulo_narrativo_label.text = trivia.titulo_narrativo
	_mostrar_ficha()
	_mostrar_imagen_de_apoyo(trivia)
	situacion_label.text = trivia.situacion_narrativa
	pregunta_label.text = trivia.pregunta
	pista_label.text = "Pista: " + trivia.pista_narrativa
	pista_button.visible = not trivia.pista_narrativa.is_empty()
	# El tutor inteligente ofrece la pista de inmediato si detecta dificultades.
	pista_label.visible = pista_button.visible and TriviaManager.necesita_apoyo(trivia.id_especie)
	_uso_pista = pista_label.visible
	retroalimentacion_panel.visible = false
	_siguiente_button.visible = false

	_limpiar_opciones()
	for op in trivia.opciones:
		var btn := Button.new()
		btn.text = op.texto
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_al_seleccionar_opcion.bind(op, btn))
		opciones_container.add_child(btn)


func _mostrar_ficha() -> void:
	if _modo != Modo.ESPECIE or _especie == null or not GameState.esta_descubierta(_especie.id_especie):
		_ficha_label.visible = false
		return
	_ficha_label.visible = true
	_ficha_label.text = "[b]%s[/b] [i](%s)[/i] — %s\n%s" % [
		_especie.nombre_comun, _especie.nombre_cientifico,
		EspecieData.NOMBRES_ESTADO.get(_especie.estado_conservacion, ""), _especie.rol_ecologico]


func _mostrar_imagen_de_apoyo(trivia: TriviaData) -> void:
	var data := EspecieLoader.por_id(trivia.id_especie)
	var tex: Texture2D = EspecieLoader.textura_de(data) if data else null
	var mostrar := tex != null and TriviaManager.necesita_apoyo(trivia.id_especie)
	_imagen.visible = mostrar
	_imagen_label.visible = mostrar
	if mostrar:
		_imagen.texture = tex
		_imagen_label.text = "El tutor añadió una imagen de referencia para ayudarte."


func _limpiar_opciones() -> void:
	for child in opciones_container.get_children():
		opciones_container.remove_child(child)
		child.queue_free()


func _on_pista_pressed() -> void:
	pista_label.visible = true
	_uso_pista = true


func _al_seleccionar_opcion(opcion: TriviaOption, boton: Button) -> void:
	if trivia_actual == null or _respondida:
		return
	_respondida = true

	for i in opciones_container.get_child_count():
		var btn := opciones_container.get_child(i) as Button
		btn.disabled = true
		if trivia_actual.opciones[i].es_correcta:
			btn.modulate = COLOR_CORRECTA
	if not opcion.es_correcta:
		boton.modulate = COLOR_INCORRECTA

	var meta := {"tiempo_s": (Time.get_ticks_msec() - _inicio_ms) / 1000.0, "uso_pista": _uso_pista,
		"modo": ["especie", "bioma", "repaso"][_modo]}
	var resultado := TriviaManager.responder_trivia(trivia_actual, opcion, _modo == Modo.REPASO, meta)
	var texto := ""
	if resultado["correcta"]:
		texto = "¡RESPUESTA CORRECTA!\n\n%s\n\n+%d PR para %s · +%d XP Biodiversidad" % [
			opcion.retroalimentacion_narrativa, resultado["pr"],
			GameState.nombre_bioma(GameState.bioma_actual_id), resultado["xp"]]
		if resultado["descubierta"]:
			texto += "\nNueva entrada en la Biopedia: %s." % trivia_actual.nombre_especie
		if _modo == Modo.REPASO:
			var etapa := GameState.etapa_validacion(trivia_actual.id_especie)
			if etapa >= GameState.INTERVALOS_REPASO_DIAS.size():
				texto += "\nValidación completa: ¡conocimiento consolidado!"
			else:
				texto += "\nValidación %d/%d superada. El próximo repaso llegará en unos días." % [
					etapa, GameState.INTERVALOS_REPASO_DIAS.size()]
	else:
		texto = "RESPUESTA INCORRECTA\n\n%s\n\nSin castigo: no pierdes PR ni salud." % opcion.retroalimentacion_narrativa
		if not trivia_actual.pista_narrativa.is_empty():
			pista_label.visible = true
		if _modo == Modo.REPASO:
			texto += "\nEste repaso se reprogramó para tu próxima sesión. Revisa la pista para prepararte."
	retroalimentacion_label.text = texto
	retroalimentacion_panel.visible = true
	_siguiente_button.visible = _modo == Modo.BIOMA
	_desplazar_al_final.call_deferred()


func _desplazar_al_final() -> void:
	_scroll.ensure_control_visible(retroalimentacion_panel)


func _on_siguiente_pressed() -> void:
	_on_solicitar_trivia("bioma", 0)


func _on_cerrar_pressed() -> void:
	hide()
