extends VBoxContainer

## Perfil del Guardián: nivel (según XP), progreso de aprendizaje, salud de cada bioma,
## insignias, el modo de juego y la opción de comenzar una partida nueva (eligiendo su modo).

const XP_POR_NIVEL := 250

var _resumen: GridContainer
var _biomas: VBoxContainer
var _insignias: Label
var _modo: Label
var _nueva_partida: VBoxContainer
var _selector: SelectorModo
var _confirmar: Button
var _participante: LineEdit
var _registros: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void:
		if is_visible_in_tree():
			refrescar())

	var cabecera := HBoxContainer.new()
	var avatar := TextureRect.new()
	avatar.texture = TemaFaunetra.icono("persona")
	avatar.custom_minimum_size = Vector2(56, 56)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cabecera.add_child(avatar)
	var titulo := Label.new()
	titulo.text = "Perfil del Guardián"
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	cabecera.add_child(titulo)
	add_child(cabecera)

	_resumen = GridContainer.new()
	_resumen.columns = 4
	_resumen.add_theme_constant_override("h_separation", 10)
	_resumen.add_theme_constant_override("v_separation", 10)
	add_child(_resumen)

	var t := Label.new()
	t.text = "Salud de los refugios"
	t.add_theme_font_size_override("font_size", 18)
	add_child(t)
	_biomas = VBoxContainer.new()
	add_child(_biomas)

	_insignias = Label.new()
	_insignias.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_insignias)

	_modo = Label.new()
	_modo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_modo)

	add_child(_crear_seccion_investigacion())

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(espacio)

	var fila := HBoxContainer.new()
	add_child(fila)
	var nueva := Button.new()
	nueva.text = "Nueva partida"
	nueva.add_theme_stylebox_override("normal", TemaFaunetra.caja(Color("#B5553F"), Color("#8E3A2A"), 10, 2, 8))
	nueva.add_theme_stylebox_override("hover", TemaFaunetra.caja(Color("#C8634C"), Color("#8E3A2A"), 10, 2, 8))
	nueva.pressed.connect(func() -> void: _nueva_partida.visible = true)
	fila.add_child(nueva)

	_nueva_partida = VBoxContainer.new()
	_nueva_partida.visible = false
	add_child(_nueva_partida)
	var t_modo := Label.new()
	t_modo.text = "Elige el modo de la nueva partida:"
	_nueva_partida.add_child(t_modo)
	_selector = SelectorModo.new()
	_selector.cambiado.connect(func(_id: String) -> void: _actualizar_confirmar())
	_nueva_partida.add_child(_selector)
	_confirmar = Button.new()
	_confirmar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmar.add_theme_stylebox_override("normal", TemaFaunetra.caja(Color("#8E3A2A"), Color("#6E2A1E"), 10, 2, 8))
	_confirmar.pressed.connect(func() -> void: GameState.reiniciar_partida(_selector.seleccionado))
	_nueva_partida.add_child(_confirmar)


## Datos para la investigación: código anónimo del participante y exportación del registro.
func _crear_seccion_investigacion() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 12, 2, 10))
	# Se reparte en varias filas si no cabe (teléfono en vertical).
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 10)
	fila.add_theme_constant_override("v_separation", 8)
	panel.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = "Código de participante:"
	fila.add_child(etiqueta)
	_participante = LineEdit.new()
	_participante.placeholder_text = "Ej: P07 (opcional, anónimo)"
	_participante.custom_minimum_size.x = 200
	_participante.max_length = 20
	_participante.text_changed.connect(_on_participante)
	fila.add_child(_participante)
	_registros = Label.new()
	_registros.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_registros.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	_registros.add_theme_font_size_override("font_size", 13)
	fila.add_child(_registros)
	var exportar := Button.new()
	exportar.text = "Exportar registro (CSV)"
	exportar.icon = TemaFaunetra.icono("libro")
	exportar.pressed.connect(_exportar_csv)
	fila.add_child(exportar)
	return panel


func _on_participante(texto: String) -> void:
	GameState.codigo_participante = texto.strip_edges()
	GameState.marcar_cambios()


## En la web descarga el archivo; en PC lo guarda en la carpeta de datos del juego y la abre.
func _exportar_csv() -> void:
	var csv := GameState.registro_csv()
	var sufijo := GameState.codigo_participante if GameState.codigo_participante != "" else "anonimo"
	var nombre := "faunetra_registro_%s_%s.csv" % [sufijo, Time.get_date_string_from_system()]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(csv.to_utf8_buffer(), nombre, "text/csv")
		EventBus.mensaje.emit("Registro descargado: %s" % nombre)
		return
	var ruta := "user://" + nombre
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		EventBus.mensaje.emit("No se pudo guardar el registro.")
		return
	archivo.store_string(csv)
	archivo.close()
	EventBus.mensaje.emit("Registro guardado: %s" % ProjectSettings.globalize_path(ruta))
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _actualizar_confirmar() -> void:
	_confirmar.text = "¿Seguro? Se borrará todo el progreso — Confirmar partida nueva en modo %s" % GameState.nombre_modo(_selector.seleccionado)


func refrescar() -> void:
	var vertical := Pantalla.vertical
	_resumen.columns = 2 if vertical else 4
	_nueva_partida.visible = false
	_selector.seleccionar(GameState.modo)
	_actualizar_confirmar()
	_modo.text = "Modo de juego: %s. %s" % [GameState.nombre_modo(), GameState.MODOS[GameState.modo]["descripcion"]]
	_participante.text = GameState.codigo_participante
	_registros.text = "%d eventos registrados" % GameState.registro.size()
	for hijo in _resumen.get_children():
		hijo.queue_free()
	var xp := TriviaManager.xp_acumulada
	var completas := 0
	for clave in GameState.validaciones:
		if GameState.etapa_validacion(int(clave)) >= GameState.INTERVALOS_REPASO_DIAS.size():
			completas += 1
	var datos := [
		["persona", "Nivel", "%d  (%d XP)" % [1 + xp / XP_POR_NIVEL, xp]],
		["libro", "Especies descubiertas", "%d / %d" % [GameState.descubiertas.size(), EspecieLoader.cargar_todas().size()]],
		["check", "Trivias respondidas", str(TriviaManager.total_trivias_respondidas)],
		["hoja", "Conocimiento consolidado", "%d especies (3/3 repasos)" % completas],
	]
	for d in datos:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 12, 2, 10))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fila := HBoxContainer.new()
		p.add_child(fila)
		var icono := TextureRect.new()
		icono.texture = TemaFaunetra.icono(d[0])
		icono.custom_minimum_size = Vector2(32, 32)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fila.add_child(icono)
		var l := Label.new()
		l.text = "%s\n%s" % [d[1], d[2]]
		l.add_theme_font_size_override("font_size", 14)
		fila.add_child(l)
		_resumen.add_child(p)

	for hijo in _biomas.get_children():
		hijo.queue_free()
	for id in GameState.ORDEN_BIOMAS:
		var fila := HBoxContainer.new()
		var icono := TextureRect.new()
		icono.texture = TemaFaunetra.icono(TemaFaunetra.ICONO_BIOMA[id] if GameState.esta_desbloqueado(id) else "candado")
		icono.custom_minimum_size = Vector2(24, 24)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fila.add_child(icono)
		var nombre := Label.new()
		nombre.text = GameState.nombre_bioma(id)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_FILL
		nombre.custom_minimum_size.x = 0 if vertical else 240
		nombre.clip_text = true
		nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		fila.add_child(nombre)
		var barra := ProgressBar.new()
		barra.value = GameState.salud(id)
		barra.custom_minimum_size = Vector2(70 if vertical else 220, 16)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(barra)
		var pr := Label.new()
		pr.text = "  %d%% · %d PR" % [int(GameState.salud(id)), GameState.obtener_pr(id)]
		fila.add_child(pr)
		_biomas.add_child(fila)

	var insignias := TriviaManager.insignias_desbloqueadas
	_insignias.text = "Insignias: " + (", ".join(PackedStringArray(insignias.map(_nombre_insignia))) if not insignias.is_empty() else "aún ninguna. Responde trivias narrativas para ganarlas.")


func _nombre_insignia(id: String) -> String:
	return id.trim_prefix("insignia_").replace("_", " ").capitalize()
