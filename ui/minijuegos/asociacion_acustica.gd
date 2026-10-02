extends VBoxContainer

## Puzzle de asociación acústica: el jugador escucha un paisaje sonoro y debe asociarlo
## con la ficha de la especie correcta. Usa el audio_canto de la ficha si existe; si no,
## un sonido procedural con la firma acústica de su grupo (ver SintetizadorFauna).

const RECOMPENSA_PR := 35

var _instrucciones: Label
var _escuchar: Button
var _fichas: VBoxContainer
var _resultado: Label
var _reproductor: AudioStreamPlayer
var _objetivo: EspecieData
var _respondida := false
var _inicio_ms := 0


func _ready() -> void:
	name = "Paisaje Sonoro"
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_reproductor = AudioStreamPlayer.new()
	add_child(_reproductor)

	_instrucciones = Label.new()
	_instrucciones.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_instrucciones)

	_escuchar = Button.new()
	_escuchar.text = "Escuchar paisaje sonoro"
	_escuchar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_escuchar.pressed.connect(func() -> void: _reproductor.play())
	add_child(_escuchar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_fichas = VBoxContainer.new()
	_fichas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fichas.add_theme_constant_override("separation", 8)
	scroll.add_child(_fichas)

	_resultado = Label.new()
	_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_resultado)

	var nueva := Button.new()
	nueva.text = "Nuevo paisaje sonoro"
	nueva.size_flags_horizontal = Control.SIZE_SHRINK_END
	nueva.pressed.connect(nueva_ronda)
	add_child(nueva)


func nueva_ronda() -> void:
	for hijo in _fichas.get_children():
		hijo.queue_free()
	_resultado.text = ""
	_respondida = false

	var fauna := EspecieLoader.fauna_del_bioma(GameState.bioma_actual_id)
	if fauna.size() < 3:
		fauna = EspecieLoader.toda_la_fauna()
	if fauna.size() < 2:
		_instrucciones.text = "No hay fauna registrada para este minijuego."
		_escuchar.disabled = true
		return
	_escuchar.disabled = false
	_objetivo = fauna.pick_random()
	_reproductor.stream = _objetivo.audio_canto if _objetivo.audio_canto else SintetizadorFauna.generar(_objetivo)
	_reproductor.play()
	_inicio_ms = Time.get_ticks_msec()
	_instrucciones.text = "Escucha con atención y elige la ficha de la especie que produce este sonido. (+%d PR)" % RECOMPENSA_PR

	for d in _elegir_opciones(fauna):
		var ficha := Button.new()
		ficha.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ficha.text = "%s (%s)\n%s" % [d.nombre_comun, d.tipo, d.rol_ecologico]
		ficha.pressed.connect(_on_ficha.bind(d, ficha))
		_fichas.add_child(ficha)


## El objetivo más dos distractores, priorizando grupos acústicos distintos para que sea deducible.
func _elegir_opciones(fauna: Array[EspecieData]) -> Array[EspecieData]:
	var categoria_objetivo := SintetizadorFauna.categoria(_objetivo)
	var distintas: Array[EspecieData] = []
	var iguales: Array[EspecieData] = []
	for d in fauna:
		if d == _objetivo:
			continue
		if SintetizadorFauna.categoria(d) != categoria_objetivo or d.audio_canto:
			distintas.append(d)
		else:
			iguales.append(d)
	distintas.shuffle()
	iguales.shuffle()
	distintas.append_array(iguales)
	var opciones: Array[EspecieData] = [_objetivo]
	for d in distintas.slice(0, 2):
		opciones.append(d)
	opciones.shuffle()
	return opciones


func _on_ficha(elegida: EspecieData, boton: Button) -> void:
	if _respondida:
		return
	_respondida = true
	for b in _fichas.get_children():
		(b as Button).disabled = true
	var explicacion := SintetizadorFauna.descripcion(_objetivo) if _objetivo.audio_canto == null else ""
	GameState.registrar({"tipo": "sonido", "id_especie": _objetivo.id_especie, "especie": _objetivo.nombre_comun,
		"correcta": elegida == _objetivo, "tiempo_s": snappedf((Time.get_ticks_msec() - _inicio_ms) / 1000.0, 0.1),
		"pr": RECOMPENSA_PR if elegida == _objetivo else 0, "detalle": "eligio=%s" % elegida.nombre_comun})
	if elegida == _objetivo:
		boton.modulate = Color(0.55, 1.0, 0.6)
		GameState.agregar_pr(RECOMPENSA_PR)
		var nueva := GameState.descubrir_especie(_objetivo)
		_resultado.text = "¡Correcto! Era %s. %s +%d PR.%s" % [
			_objetivo.nombre_comun, explicacion, RECOMPENSA_PR, " Nueva entrada en la Biopedia." if nueva else ""]
	else:
		boton.modulate = Color(1.0, 0.55, 0.5)
		_resultado.text = "Era %s. %s Sin castigo: escucha de nuevo y prueba otro paisaje." % [_objetivo.nombre_comun, explicacion]
