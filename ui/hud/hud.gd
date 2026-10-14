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
const PistasRefugio := preload("res://ui/hud/pistas_refugio.gd")
const IdentificacionFauna := preload("res://ui/minijuegos/identificacion_fauna.gd")

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
var _pistas: PistasRefugio
var _barra_superior: PanelContainer
var _barra_inferior: PanelContainer
var _info_planta: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TemaFaunetra.obtener()
	_construir_barra_superior()
	_construir_barra_inferior()
	_construir_aviso()
	_pistas = PistasRefugio.new()
	_pistas.position = Vector2(10, 64)
	add_child(_pistas)
	_tableta = Tableta.new()
	add_child(_tableta)
	_menu = MenuMundos.new()
	add_child(_menu)
	add_child(IdentificacionFauna.new())
	# La pausa va en su propia capa, por encima de todo (también del panel de trivias, que es
	# hermano posterior del HUD): así, cuando se muestra, siempre se ve y recibe los clics.
	var capa_pausa := CanvasLayer.new()
	capa_pausa.name = "CapaPausa"
	capa_pausa.layer = 10
	add_child(capa_pausa)
	_opciones = Opciones.new()
	_opciones.theme = theme   # una CanvasLayer corta la herencia del tema
	_opciones.ir_a_mundos.connect(func() -> void: _menu.abrir())
	capa_pausa.add_child(_opciones)

	EventBus.bioma_cargado.connect(_on_bioma_cargado)
	EventBus.mensaje.connect(mostrar_aviso)
	EventBus.dialogo.connect(mostrar_dialogo)
	GameState.pr_actualizado.connect(_on_pr_actualizado)
	GameState.salud_actualizada.connect(_on_salud_actualizada)
	GameState.herramienta_cambiada.connect(_on_herramienta_cambiada)
	GameState.repasos_actualizados.connect(_actualizar_boton_tableta)
	GameState.bioma_desbloqueado.connect(_on_bioma_desbloqueado)
	GameState.especie_descubierta.connect(_on_especie_descubierta)

	# Los repasos vencen con el paso del tiempo: revisamos periódicamente.
	var reloj := Timer.new()
	reloj.wait_time = 30.0
	reloj.autostart = true
	reloj.timeout.connect(_actualizar_boton_tableta)
	add_child(reloj)
	_on_herramienta_cambiada(GameState.herramienta_activa)
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _reacomodar())
	_reacomodar()


## Esc: si hay una ventana abierta (trivia, Tableta, diálogo...) cierra la de más arriba;
## si no, primero suelta la herramienta activa y, si no hay ninguna, abre la pausa.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _cerrar_modal_superior():
			pass
		elif GameState.herramienta_activa != "identificar":
			GameState.herramienta_activa = "identificar"
		else:
			abrir_opciones()
		get_viewport().set_input_as_handled()


func abrir_opciones() -> void:
	_opciones.abrir()


## Cierra la ventana modal visible que está más arriba. Devuelve false si no había ninguna.
## El menú de mundos es la pantalla de inicio: no se cierra con Esc (ahí Esc abre la pausa).
func _cerrar_modal_superior() -> bool:
	# Lo que está después del HUD en el CanvasLayer (el panel de trivias) se dibuja encima.
	var capa := get_parent()
	if capa:
		for i in range(capa.get_child_count() - 1, get_index(), -1):
			var hermano := capa.get_child(i) as Control
			if hermano and hermano.visible and hermano.mouse_filter == Control.MOUSE_FILTER_STOP:
				hermano.hide()
				return true
	for i in range(get_child_count() - 1, -1, -1):
		var hijo := get_child(i) as Control
		if hijo == null or not hijo.visible:
			continue
		if hijo == _menu:
			return false
		if hijo == _dialogo_abierto:
			_cerrar_dialogo(hijo)
			return true
		if hijo is VentanaModal or hijo is IdentificacionFauna:
			if hijo.has_method("_cerrar"):
				hijo.call("_cerrar")   # identificación: deja registro de que se pospuso
			else:
				hijo.hide()
			return true
	return false


# --- Construcción --------------------------------------------------------------------

func _construir_barra_superior() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(panel)
	_barra_superior = panel
	panel.resized.connect(func() -> void:
		if _pistas:
			_pistas.position = Vector2(10, panel.size.y + 8)
		if is_instance_valid(_tutorial):
			_tutorial.reubicar())
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
	_salud_label.tooltip_text = _salud_barra.tooltip_text
	_salud_label.mouse_filter = Control.MOUSE_FILTER_PASS
	# En pantallas táctiles no hay "hover": tocar el texto muestra la explicación como aviso.
	for nodo in [_pr_label, _salud_label, _salud_barra]:
		(nodo as Control).gui_input.connect(_al_tocar_info.bind(nodo))

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


## Toque (o clic) sobre un indicador: muestra su explicación, que en PC también es tooltip.
func _al_tocar_info(event: InputEvent, nodo: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mostrar_aviso(nodo.tooltip_text)


func _construir_barra_inferior() -> void:
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	_barra_inferior = panel
	panel.resized.connect(func() -> void:
		if is_instance_valid(_tutorial):
			_tutorial.reubicar()
		_ubicar_aviso())
	var columna := VBoxContainer.new()
	panel.add_child(columna)

	# Ficha breve de la especie elegida (nombre científico, estado y rol): en PC también está
	# como tooltip del botón, pero en pantallas táctiles no hay hover.
	_info_planta = Label.new()
	_info_planta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_planta.custom_minimum_size.x = 200
	_info_planta.add_theme_font_size_override("font_size", 13)
	_info_planta.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	_info_planta.hide()
	columna.add_child(_info_planta)

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
	_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	_actualizar_info_planta()
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
	_ubicar_aviso()


## Los avisos van justo sobre la barra inferior (que crece con la barra de plantas) y, si la
## tarjeta del tutorial está abajo, sobre ella. Crecen hacia arriba si el texto es largo.
func _ubicar_aviso() -> void:
	if _aviso == null or _barra_inferior == null:
		return
	var base := (150.0 if Pantalla.vertical else 130.0)
	var ocupado := _barra_inferior.size.y + 12.0
	if is_instance_valid(_tutorial) and _tutorial.visible and _tutorial.anchor_top >= 1.0:
		ocupado = get_viewport_rect().size.y - _tutorial.position.y + 8.0
	_aviso.offset_bottom = -maxf(base, ocupado)
	_aviso.offset_top = _aviso.offset_bottom - 80.0


func alto_barra_superior() -> float:
	return _barra_superior.size.y if _barra_superior else 0.0


## Alto de la barra inferior (herramientas y, al plantar, la barra de especies).
func alto_barra_inferior() -> float:
	return _barra_inferior.size.y if _barra_inferior else 0.0


func _construir_barra_plantas(id_bioma: int) -> void:
	for hijo in _fila_plantas.get_children():
		hijo.queue_free()
	_grupo_plantas = ButtonGroup.new()
	for data in EspecieLoader.flora_plantable(id_bioma):
		var boton := Button.new()
		boton.toggle_mode = true
		boton.button_group = _grupo_plantas
		boton.text = "%s · %d PR" % [data.nombre_comun, ReglasEcosistema.costo_plantar(data)]
		boton.tooltip_text = _ficha_planta(data)
		boton.icon = EspecieLoader.textura_de(data)
		boton.expand_icon = true
		boton.custom_minimum_size = Vector2(0, 46)
		boton.pressed.connect(_elegir_planta.bind(data))
		_fila_plantas.add_child(boton)


func _elegir_planta(data: EspecieData) -> void:
	GameState.especie_para_plantar = data
	GameState.herramienta_activa = "plantar"
	# Pista ecológica: con quién crece mejor y a quién atrae; en el terreno se iluminan las
	# parcelas donde tendría una sinergia.
	mostrar_aviso(ReglasEcosistema.pista_planta(data))
	_actualizar_info_planta()


func _ficha_planta(data: EspecieData) -> String:
	return "%s (%s)\n%s" % [data.nombre_cientifico, EspecieData.NOMBRES_ESTADO.get(data.estado_conservacion, ""), data.rol_ecologico]


func _actualizar_info_planta() -> void:
	var data := GameState.especie_para_plantar
	var mostrar := GameState.herramienta_activa == "plantar" and data != null \
		and data.id_bioma == GameState.bioma_actual_id
	_info_planta.visible = mostrar
	if mostrar:
		_info_planta.text = "%s: %s" % [data.nombre_comun, _ficha_planta(data).replace("\n", " · ")]


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


## Sello del álbum: al descubrir la última especie de un bioma.
func _on_especie_descubierta(data: EspecieData) -> void:
	var especies := EspecieLoader.cargar_especies_del_bioma(data.id_bioma)
	for d in especies:
		if not GameState.esta_descubierta(d.id_especie):
			return
	GameState.registrar({"tipo": "biopedia_completa", "id_bioma": data.id_bioma, "detalle": "especies=%d" % especies.size()})
	mostrar_dialogo("¡Biopedia completa: %s!" % GameState.nombre_bioma(data.id_bioma),
		"Registraste las %d especies nativas de este bioma. Su sello ya brilla en tu Biopedia." % especies.size())


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
	_tutorial.terminado.connect(func() -> void:
		_tutorial = null
		_ubicar_aviso.call_deferred())
	_tutorial.item_rect_changed.connect(_ubicar_aviso)
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

	# El ancho lo fija el texto, acotado a la pantalla (márgenes del panel incluidos); el título
	# se parte en líneas para que un nombre de bioma largo no ensanche el panel.
	var ancho := minf(340.0 if Pantalla.vertical else 540.0, get_viewport_rect().size.x - 100.0)
	var titulo := Label.new()
	titulo.text = datos[0]
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.custom_minimum_size.x = ancho
	titulo.add_theme_font_size_override("font_size", 20)
	columna.add_child(titulo)
	var texto := Label.new()
	texto.text = datos[1]
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = ancho
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
