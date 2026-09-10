extends Control

@onready var nombre_label: Label = $NombreLabel
@onready var rol_label: Label = $RolLabel
@onready var cerrar_button: Button = $CerrarButton

# Nodos dinámicos para la experiencia narrativa de la trivia
var titulo_narrativo_label: Label
var situacion_label: Label
var pregunta_label: Label
var pista_label: Label
var opciones_container: VBoxContainer
var pista_button: Button
var retroalimentacion_panel: PanelContainer
var retroalimentacion_label: Label

var trivia_actual: TriviaData

func _ready() -> void:
	# Conexión a señales globales
	EventBus.especie_seleccionada.connect(_on_especie_seleccionada)
	cerrar_button.pressed.connect(_on_cerrar_pressed)
	
	_construir_interfaz_narrativa_si_falta()
	hide()

func _construir_interfaz_narrativa_si_falta() -> void:
	# Contenedor principal de la trivia narrativa
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	titulo_narrativo_label = Label.new()
	titulo_narrativo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_narrativo_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(titulo_narrativo_label)

	situacion_label = Label.new()
	situacion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	situacion_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(situacion_label)

	pregunta_label = Label.new()
	pregunta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pregunta_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(pregunta_label)

	pista_button = Button.new()
	pista_button.text = "💡 Pedir Pista Formativa"
	pista_button.pressed.connect(_on_pista_pressed)
	vbox.add_child(pista_button)

	pista_label = Label.new()
	pista_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pista_label.visible = false
	vbox.add_child(pista_label)

	opciones_container = VBoxContainer.new()
	opciones_container.add_theme_constant_override("separation", 10)
	vbox.add_child(opciones_container)

	retroalimentacion_panel = PanelContainer.new()
	retroalimentacion_panel.visible = false
	vbox.add_child(retroalimentacion_panel)

	retroalimentacion_label = Label.new()
	retroalimentacion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retroalimentacion_panel.add_child(retroalimentacion_label)

func _on_especie_seleccionada(datos: EspecieData) -> void:
	nombre_label.text = datos.nombre_comun
	rol_label.text = datos.rol_ecologico
	
	# Carga adaptativa de la trivia para esta especie según DDA (Flow Theory)
	trivia_actual = TriviaManager.obtener_trivia_adaptativa(datos.id_especie)
	
	if trivia_actual != null:
		_mostrar_trivia(trivia_actual)
	else:
		titulo_narrativo_label.text = "Exploración de: " + datos.nombre_comun
		situacion_label.text = datos.rol_ecologico
		pregunta_label.text = ""
		_limpiar_opciones()
		pista_button.visible = false
		retroalimentacion_panel.visible = false
		
	show()

func _mostrar_trivia(trivia: TriviaData) -> void:
	titulo_narrativo_label.text = "📜 " + trivia.titulo_narrativo + " (Especie: " + trivia.nombre_especie + ")"
	situacion_label.text = trivia.situacion_narrativa
	pregunta_label.text = "❓ " + trivia.pregunta
	pista_label.text = "💡 Pista: " + trivia.pista_narrativa
	pista_label.visible = false
	pista_button.visible = not trivia.pista_narrativa.is_empty()
	retroalimentacion_panel.visible = false

	_limpiar_opciones()

	for op in trivia.opciones:
		var btn := Button.new()
		btn.text = op.texto
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func(): _al_seleccionar_opcion(op))
		opciones_container.add_child(btn)

func _limpiar_opciones() -> void:
	for child in opciones_container.get_children():
		child.queue_free()

func _on_pista_pressed() -> void:
	pista_label.visible = true

func _al_seleccionar_opcion(opcion: TriviaOption) -> void:
	if trivia_actual == null:
		return

	TriviaManager.responder_trivia(trivia_actual, opcion)
	
	retroalimentacion_panel.visible = true
	if opcion.es_correcta:
		retroalimentacion_label.text = "¡RESPUESTA CORRECTA! 🎉\n\n" + opcion.retroalimentacion_narrativa + "\n\n+ " + str(trivia_actual.recompensa_xp) + " XP Biodiversidad"
	else:
		retroalimentacion_label.text = "RESPUESTA INCORRECTA 💡\n\n" + opcion.retroalimentacion_narrativa

func _on_cerrar_pressed() -> void:
	hide()
