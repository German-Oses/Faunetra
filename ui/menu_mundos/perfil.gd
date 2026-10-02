extends VBoxContainer

## Perfil del Guardián: nivel (según XP), progreso de aprendizaje, salud de cada bioma,
## insignias y la opción de comenzar una partida nueva.

const XP_POR_NIVEL := 250

var _resumen: GridContainer
var _biomas: VBoxContainer
var _insignias: Label
var _confirmar: Button


func _ready() -> void:
	add_theme_constant_override("separation", 12)

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

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(espacio)

	var fila := HBoxContainer.new()
	add_child(fila)
	var nueva := Button.new()
	nueva.text = "Nueva partida"
	nueva.add_theme_stylebox_override("normal", TemaFaunetra.caja(Color("#B5553F"), Color("#8E3A2A"), 10, 2, 8))
	nueva.add_theme_stylebox_override("hover", TemaFaunetra.caja(Color("#C8634C"), Color("#8E3A2A"), 10, 2, 8))
	nueva.pressed.connect(func() -> void: _confirmar.visible = true)
	fila.add_child(nueva)
	_confirmar = Button.new()
	_confirmar.text = "¿Seguro? Se borrará todo el progreso — Confirmar"
	_confirmar.add_theme_stylebox_override("normal", TemaFaunetra.caja(Color("#8E3A2A"), Color("#6E2A1E"), 10, 2, 8))
	_confirmar.visible = false
	_confirmar.pressed.connect(GameState.reiniciar_partida)
	fila.add_child(_confirmar)


func refrescar() -> void:
	_confirmar.visible = false
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
		nombre.custom_minimum_size.x = 240
		fila.add_child(nombre)
		var barra := ProgressBar.new()
		barra.value = GameState.salud(id)
		barra.custom_minimum_size = Vector2(220, 16)
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
