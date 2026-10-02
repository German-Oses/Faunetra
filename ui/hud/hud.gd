extends Control

## HUD principal: bioma actual, PR locales, salud con la meta de desbloqueo, herramientas
## del terreno con sus costos, barra de plantación, accesos a la Tableta y al mapa, y avisos.

const Tableta := preload("res://ui/tableta/tableta.gd")
const MenuMundos := preload("res://ui/menu_mundos/menu_mundos.gd")

const HERRAMIENTAS := [
	{"id": "identificar", "texto": "Identificar"},
	{"id": "disipar", "texto": "Disipar niebla"},
	{"id": "limpiar", "texto": "Limpiar"},
	{"id": "plantar", "texto": "Plantar"},
	{"id": "sanar", "texto": "Sanar"},
]
const DURACION_AVISO := 4.0

var _nombre_bioma: Label
var _pr_label: Label
var _salud_barra: ProgressBar
var _salud_label: Label
var _boton_tableta: Button
var _fila_plantas: HBoxContainer
var _scroll_plantas: ScrollContainer
var _aviso: Label
var _tween_aviso: Tween
var _botones_herramienta: Dictionary = {}
var _grupo_plantas := ButtonGroup.new()
var _tableta: Tableta
var _menu: MenuMundos
var _dialogos_pendientes: Array = []
var _dialogo_abierto: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TemaFaunetra.obtener()
	_construir_barra_superior()
	_construir_barra_inferior()
	_construir_aviso()
	_tableta = Tableta.new()
	add_child(_tableta)
	_menu = MenuMundos.new()
	add_child(_menu)

	EventBus.bioma_cargado.connect(_on_bioma_cargado)
	EventBus.mensaje.connect(mostrar_aviso)
	GameState.pr_actualizado.connect(_on_pr_actualizado)
	GameState.salud_actualizada.connect(_on_salud_actualizada)
	GameState.herramienta_cambiada.connect(_on_herramienta_cambiada)
	GameState.repasos_actualizados.connect(_actualizar_boton_tableta)
	GameState.bioma_desbloqueado.connect(_on_bioma_desbloqueado)

	# Los repasos vencen con el paso del tiempo: revisamos periódicamente.
	var reloj := Timer.new()
	reloj.wait_time = 30.0
	reloj.autostart = true
	reloj.timeout.connect(_actualizar_boton_tableta)
	add_child(reloj)
	_on_herramienta_cambiada(GameState.herramienta_activa)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.herramienta_activa = "identificar"


# --- Construcción --------------------------------------------------------------------

func _construir_barra_superior() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	panel.add_child(fila)

	_nombre_bioma = Label.new()
	_nombre_bioma.add_theme_font_size_override("font_size", 18)
	_nombre_bioma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_nombre_bioma)

	_pr_label = Label.new()
	_pr_label.tooltip_text = "Puntos de Restauración (Esencia Vital) de este bioma. No se comparten entre biomas."
	_pr_label.mouse_filter = Control.MOUSE_FILTER_PASS
	fila.add_child(_pr_label)

	_salud_label = Label.new()
	fila.add_child(_salud_label)
	_salud_barra = ProgressBar.new()
	_salud_barra.custom_minimum_size = Vector2(160, 18)
	_salud_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_salud_barra.show_percentage = false
	_salud_barra.tooltip_text = "Sana el bioma hasta %d%% para desbloquear el siguiente." % int(GameState.UMBRAL_DESBLOQUEO)
	fila.add_child(_salud_barra)

	var mapa := Button.new()
	mapa.text = "Mundos"
	mapa.icon = TemaFaunetra.icono("casa")
	mapa.pressed.connect(func() -> void: _menu.abrir())
	fila.add_child(mapa)

	_boton_tableta = Button.new()
	_boton_tableta.text = "Tableta"
	_boton_tableta.pressed.connect(func() -> void: _tableta.abrir())
	fila.add_child(_boton_tableta)


func _construir_barra_inferior() -> void:
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var columna := VBoxContainer.new()
	panel.add_child(columna)

	_scroll_plantas = ScrollContainer.new()
	_scroll_plantas.custom_minimum_size.y = 54
	_scroll_plantas.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(_scroll_plantas)
	_fila_plantas = HBoxContainer.new()
	_fila_plantas.add_theme_constant_override("separation", 6)
	_scroll_plantas.add_child(_fila_plantas)
	_scroll_plantas.hide()

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	columna.add_child(fila)
	var grupo := ButtonGroup.new()
	for h in HERRAMIENTAS:
		var boton := Button.new()
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.custom_minimum_size = Vector2(120, 40)
		boton.pressed.connect(_seleccionar_herramienta.bind(h["id"]))
		fila.add_child(boton)
		_botones_herramienta[h["id"]] = boton
	_actualizar_textos_herramientas()


func _construir_aviso() -> void:
	_aviso = Label.new()
	_aviso.anchor_left = 0.5
	_aviso.anchor_right = 0.5
	_aviso.anchor_top = 1.0
	_aviso.anchor_bottom = 1.0
	_aviso.offset_left = -360
	_aviso.offset_right = 360
	_aviso.offset_top = -190
	_aviso.offset_bottom = -130
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.add_theme_color_override("font_color", Color.WHITE)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.add_theme_font_size_override("font_size", 17)
	_aviso.modulate.a = 0.0
	add_child(_aviso)


# --- Herramientas y plantas --------------------------------------------------------------

func _seleccionar_herramienta(id: String) -> void:
	GameState.herramienta_activa = id


func _on_herramienta_cambiada(id: String) -> void:
	for clave in _botones_herramienta:
		(_botones_herramienta[clave] as Button).set_pressed_no_signal(clave == id)
	_scroll_plantas.visible = id == "plantar"
	if id == "plantar" and GameState.especie_para_plantar == null:
		mostrar_aviso("Elige qué especie nativa plantar en la barra superior.")


func _actualizar_textos_herramientas() -> void:
	var textos := {
		"identificar": "Identificar",
		"disipar": "Disipar niebla (%d PR)" % ReglasEcosistema.costo_niebla(),
		"limpiar": "Limpiar",
		"plantar": "Plantar",
		"sanar": "Sanar (%d PR)" % ReglasEcosistema.costo_sanar(),
	}
	for clave in _botones_herramienta:
		(_botones_herramienta[clave] as Button).text = textos.get(clave, clave)


func _construir_barra_plantas(id_bioma: int) -> void:
	for hijo in _fila_plantas.get_children():
		hijo.queue_free()
	_grupo_plantas = ButtonGroup.new()
	for data in EspecieLoader.flora_plantable(id_bioma):
		var boton := Button.new()
		boton.toggle_mode = true
		boton.button_group = _grupo_plantas
		boton.text = "%s · %d PR" % [data.nombre_comun, ReglasEcosistema.costo_plantar(data)]
		boton.tooltip_text = "%s (%s)\n%s" % [data.nombre_cientifico, EspecieData.NOMBRES_ESTADO.get(data.estado_conservacion, ""), data.rol_ecologico]
		boton.icon = EspecieLoader.textura_de(data)
		boton.expand_icon = true
		boton.custom_minimum_size = Vector2(0, 46)
		boton.pressed.connect(_elegir_planta.bind(data))
		_fila_plantas.add_child(boton)


func _elegir_planta(data: EspecieData) -> void:
	GameState.especie_para_plantar = data
	GameState.herramienta_activa = "plantar"


# --- Estado -------------------------------------------------------------------------------

func _on_bioma_cargado(id_bioma: int) -> void:
	_nombre_bioma.text = GameState.nombre_bioma(id_bioma)
	_on_pr_actualizado(id_bioma, GameState.obtener_pr(id_bioma))
	_on_salud_actualizada(id_bioma, GameState.salud(id_bioma))
	_construir_barra_plantas(id_bioma)
	GameState.herramienta_activa = "identificar"
	_actualizar_boton_tableta()


func _on_pr_actualizado(id_bioma: int, total: int) -> void:
	if id_bioma == GameState.bioma_actual_id:
		_pr_label.text = "Esencia Vital: %d PR" % total


func _on_salud_actualizada(id_bioma: int, salud: float) -> void:
	if id_bioma != GameState.bioma_actual_id:
		return
	_salud_barra.value = salud
	_salud_label.text = "Salud %d%% (meta %d%%)" % [int(salud), int(GameState.UMBRAL_DESBLOQUEO)]
	_salud_barra.modulate = Color(0.55, 1.0, 0.6) if salud >= GameState.UMBRAL_DESBLOQUEO else Color.WHITE


func _on_bioma_desbloqueado(id_bioma: int) -> void:
	mostrar_dialogo("¡Nuevo bioma desbloqueado!",
		"Tu refugio alcanzó %d%% de salud. Ahora puedes viajar a %s desde Mundos." % [
			int(GameState.UMBRAL_DESBLOQUEO), GameState.nombre_bioma(id_bioma)])


func _actualizar_boton_tableta() -> void:
	var pendientes := GameState.repasos_pendientes().size()
	_boton_tableta.text = "Tableta (%d repasos)" % pendientes if pendientes > 0 else "Tableta"


# --- Avisos --------------------------------------------------------------------------------

func mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	if _tween_aviso:
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(DURACION_AVISO)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.6)


## Abre el menú de mundos (pantalla de inicio).
func abrir_menu(pagina: String = "refugio") -> void:
	_menu.abrir(pagina)


## Muestra un diálogo; si ya hay uno abierto, lo encola para mostrarlo al cerrarse el actual.
func mostrar_dialogo(titulo: String, texto: String) -> void:
	_dialogos_pendientes.append([titulo, texto])
	if _dialogo_abierto == null:
		_mostrar_siguiente_dialogo()


func _mostrar_siguiente_dialogo() -> void:
	_dialogo_abierto = null
	if _dialogos_pendientes.is_empty():
		return
	var datos: Array = _dialogos_pendientes.pop_front()

	# Panel modal dibujado dentro del HUD (no una Window aparte), así siempre recibe los clics.
	var dialogo := Control.new()
	dialogo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialogo)

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogo.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogo.add_child(centro)
	var panel := PanelContainer.new()
	centro.add_child(panel)
	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 18)
	panel.add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	margen.add_child(columna)

	var titulo := Label.new()
	titulo.text = datos[0]
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 20)
	columna.add_child(titulo)
	var texto := Label.new()
	texto.text = datos[1]
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 540
	columna.add_child(texto)
	var aceptar := Button.new()
	aceptar.text = "OK"
	aceptar.custom_minimum_size = Vector2(120, 36)
	aceptar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	aceptar.pressed.connect(_cerrar_dialogo.bind(dialogo))
	columna.add_child(aceptar)

	_dialogo_abierto = dialogo
	aceptar.grab_focus.call_deferred()


func _cerrar_dialogo(dialogo: Control) -> void:
	dialogo.queue_free()
	_mostrar_siguiente_dialogo()
