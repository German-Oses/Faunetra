extends Control

## HUD principal: bioma actual, PR locales, salud con la meta de desbloqueo, herramientas
## del terreno con sus costos, barra de plantación, accesos a la Tableta y al mapa, y avisos.
## En vertical (teléfono) la barra superior se divide en dos filas y las herramientas muestran
## su costo en una segunda línea, para caber en 480 px lógicos (ver Pantalla).

const Tableta := preload("res://ui/tableta/tableta.gd")
const MenuMundos := preload("res://ui/menu_mundos/menu_mundos.gd")
const Tutorial := preload("res://ui/hud/tutorial.gd")
const Opciones := preload("res://ui/opciones/opciones.gd")
const VentanaModo := preload("res://ui/hud/ventana_modo.gd")

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
var _boton_mapa: Button
var _fila_superior: HBoxContainer
var _fila_estado: HBoxContainer      # segunda fila de la barra superior (solo en vertical)
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
var _tutorial: Tutorial
var _opciones: Opciones


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
	_opciones = Opciones.new()
	_opciones.ir_a_mundos.connect(func() -> void: _menu.abrir())
	add_child(_opciones)

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
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _reacomodar())
	_reacomodar()


## Esc: primero suelta la herramienta activa; si no hay ninguna, abre la pausa.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if GameState.herramienta_activa != "identificar":
			GameState.herramienta_activa = "identificar"
		else:
			abrir_opciones()
		get_viewport().set_input_as_handled()


func abrir_opciones() -> void:
	_opciones.abrir()


# --- Construcción --------------------------------------------------------------------

func _construir_barra_superior() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(panel)
	var columna := VBoxContainer.new()
	panel.add_child(columna)
	_fila_superior = HBoxContainer.new()
	_fila_superior.add_theme_constant_override("separation", 14)
	columna.add_child(_fila_superior)
	_fila_estado = HBoxContainer.new()
	_fila_estado.add_theme_constant_override("separation", 10)
	columna.add_child(_fila_estado)

	_nombre_bioma = Label.new()
	_nombre_bioma.add_theme_font_size_override("font_size", 18)
	_nombre_bioma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nombre_bioma.clip_text = true
	_nombre_bioma.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fila_superior.add_child(_nombre_bioma)

	_pr_label = Label.new()
	_pr_label.tooltip_text = "Puntos de Restauración (Esencia Vital) de este bioma. No se comparten entre biomas."
	_pr_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_salud_label = Label.new()
	_salud_barra = ProgressBar.new()
	_salud_barra.custom_minimum_size = Vector2(160, 18)
	_salud_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_salud_barra.show_percentage = false
	_salud_barra.tooltip_text = "Sana el bioma hasta %d%% para desbloquear el siguiente." % int(GameState.umbral_desbloqueo())

	_boton_mapa = Button.new()
	_boton_mapa.icon = TemaFaunetra.icono("casa")
	_boton_mapa.tooltip_text = "Mapa de mundos"
	_boton_mapa.pressed.connect(func() -> void: _menu.abrir())

	_boton_tableta = Button.new()
	_boton_tableta.text = "Tableta"
	_boton_tableta.pressed.connect(func() -> void: _tableta.abrir())

	var opciones := Button.new()
	opciones.icon = TemaFaunetra.icono("engranaje")
	opciones.tooltip_text = "Pausa y opciones (Esc)"
	opciones.pressed.connect(abrir_opciones)
	# Orden en horizontal: nombre · PR · salud · barra · Mundos · Tableta · opciones.
	for nodo in [_pr_label, _salud_label, _salud_barra, _boton_mapa, _boton_tableta, opciones]:
		_fila_superior.add_child(nodo)


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
		boton.pressed.connect(_seleccionar_herramienta.bind(h["id"]))
		fila.add_child(boton)
		_botones_herramienta[h["id"]] = boton


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
	# En vertical el costo va en una segunda línea para que las cinco herramientas quepan.
	var salto := "\n" if Pantalla.vertical else " "
	var textos := {
		"identificar": "Identificar",
		"disipar": ("Disipar%s(%d PR)" if Pantalla.vertical else "Disipar niebla%s(%d PR)") % [salto, ReglasEcosistema.costo_niebla()],
		"limpiar": "Limpiar",
		"plantar": "Plantar",
		"sanar": "Sanar%s(%d PR)" % [salto, ReglasEcosistema.costo_sanar()],
	}
	for clave in _botones_herramienta:
		(_botones_herramienta[clave] as Button).text = textos.get(clave, clave)


## Reubica la barra superior, las herramientas y los avisos según la orientación.
func _reacomodar() -> void:
	var vertical := Pantalla.vertical
	# Barra superior: en vertical, PR y salud bajan a una segunda fila.
	var destino := _fila_estado if vertical else _fila_superior
	for i in 3:
		var nodo: Control = [_pr_label, _salud_label, _salud_barra][i]
		if nodo.get_parent() != destino:
			if nodo.get_parent():
				nodo.get_parent().remove_child(nodo)
			destino.add_child(nodo)
			destino.move_child(nodo, i if vertical else 1 + i)
	_fila_estado.visible = vertical
	_salud_barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_FILL
	_salud_barra.custom_minimum_size.x = 40 if vertical else 160   # en vertical llena lo que sobre de la fila
	_boton_mapa.text = "" if vertical else "Mundos"

	for clave in _botones_herramienta:
		var boton: Button = _botones_herramienta[clave]
		boton.custom_minimum_size = Vector2(0, 52) if vertical else Vector2(120, 40)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_FILL
		if vertical:
			boton.add_theme_font_size_override("font_size", 14)
		else:
			boton.remove_theme_font_size_override("font_size")
	_actualizar_textos_herramientas()

	# Avisos: a lo ancho de la pantalla en vertical, centrados y acotados en horizontal.
	_aviso.anchor_left = 0.0 if vertical else 0.5
	_aviso.anchor_right = 1.0 if vertical else 0.5
	_aviso.offset_left = 16 if vertical else -360
	_aviso.offset_right = -16 if vertical else 360
	_aviso.offset_top = -230 if vertical else -190
	_aviso.offset_bottom = -150 if vertical else -130


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
	_salud_label.text = "Salud %d%% (meta %d%%)" % [int(salud), int(GameState.umbral_desbloqueo())]
	_salud_barra.modulate = Color(0.55, 1.0, 0.6) if salud >= GameState.umbral_desbloqueo() else Color.WHITE


func _on_bioma_desbloqueado(id_bioma: int) -> void:
	mostrar_dialogo("¡Nuevo bioma desbloqueado!",
		"Tu refugio alcanzó %d%% de salud. Ahora puedes viajar a %s desde Mundos." % [
			int(GameState.umbral_desbloqueo()), GameState.nombre_bioma(id_bioma)])


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


## Inicia (o retoma) el tutorial guiado si el jugador no lo ha completado.
## Primera partida: pide elegir el modo de juego y luego comienza el tutorial.
func elegir_modo_inicial() -> void:
	var ventana := VentanaModo.new()
	ventana.terminado.connect(iniciar_tutorial)
	add_child(ventana)
	ventana.abrir()


func iniciar_tutorial() -> void:
	if _tutorial != null or GameState.tutorial_paso >= Tutorial.PASOS.size():
		return
	_tutorial = Tutorial.new()
	_tutorial.hud = self
	_tutorial.terminado.connect(func() -> void: _tutorial = null)
	add_child(_tutorial)
	if not _menu.visibility_changed.is_connected(_on_menu_visibilidad):
		_menu.visibility_changed.connect(_on_menu_visibilidad)
		_tableta.visibility_changed.connect(_on_tableta_visibilidad)


func _on_menu_visibilidad() -> void:
	if _tutorial and not _menu.visible:
		_tutorial.avisar("explorar")


func _on_tableta_visibilidad() -> void:
	if _tutorial and _tableta.visible:
		_tutorial.avisar("tableta")


## Control que el tutorial hace parpadear en cada paso.
func objetivo_tutorial(nombre: String) -> CanvasItem:
	if nombre == "tableta":
		return _boton_tableta
	return _botones_herramienta.get(nombre)


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
	texto.custom_minimum_size.x = 340 if Pantalla.vertical else 540
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
