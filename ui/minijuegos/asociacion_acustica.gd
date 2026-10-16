extends VBoxContainer

## Puzzle de asociación acústica: el jugador escucha un paisaje sonoro y debe asociarlo
## con la ficha de la especie correcta. Usa el audio_canto de la ficha si existe; si no,
## un sonido procedural con la firma acústica de su grupo (ver SintetizadorFauna).

## Anti-adivinanza: cada ronda admite un solo intento. Reconocer por primera vez (en la sesión)
## el sonido de una especie da RECOMPENSA_PR; repetirla da RECOMPENSA_REPETIDA. Fallar deja al
## jugador en práctica (sin PR) hasta acertar PRACTICAS_TRAS_ERROR rondas seguidas, así adivinar al azar
## casi no rinde (un jugador que adivina cobra en ~1 de cada 27 rondas).
const RECOMPENSA_PR := 35
const RECOMPENSA_REPETIDA := 5
const PRACTICAS_TRAS_ERROR := 2

var _instrucciones: Label
var _escuchar: Button
var _fichas: VBoxContainer
var _resultado: Label
var _reproductor: AudioStreamPlayer
var _objetivo: EspecieData
var _respondida := false
var _inicio_ms := 0
## Aciertos seguidos que faltan para volver a ganar PR tras un error (saltar rondas no lo borra).
var _practicas_pendientes := 0
## Especies cuyo sonido ya se reconoció en esta sesión (id_especie -> true).
var _reconocidas: Dictionary = {}


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
	_escuchar.pressed.connect(func() -> void:
		if _reproductor.stream:
			Sonidos.atenuar_ambiente(_reproductor.stream.get_length())
			_reproductor.play())
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


## Al abrir la pestaña: conserva la ronda en curso y solo inicia otra si no hay una pendiente.
func al_mostrar() -> void:
	if _objetivo == null or _respondida or _fichas.get_child_count() == 0:
		nueva_ronda()


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
	Sonidos.atenuar_ambiente(_reproductor.stream.get_length())
	_reproductor.play()
	_inicio_ms = Time.get_ticks_msec()
	# Sin grabación real en la ficha, el sonido es una simulación de su grupo (ave, anfibio, insecto...):
	# se dice claramente para no presentarlo como el canto verdadero de la especie.
	var consigna := "Escucha con atención y elige la ficha de la especie que produce este sonido." if _objetivo.audio_canto \
		else "Sonido simulado: no es una grabación real, sino un sonido creado para representar a su grupo. Elige la ficha cuyo grupo encaja con lo que escuchas."
	if _practicas_pendientes > 0:
		_instrucciones.text = ("Ronda de práctica (sin PR): acierta %d seguida(s) para volver a ganar Esencia Vital. " % _practicas_pendientes) + consigna + " Tienes un solo intento."
	else:
		_instrucciones.text = consigna + " Tienes un solo intento. (+%d PR si es una especie nueva para ti, +%d PR si ya la reconociste)" % [RECOMPENSA_PR, RECOMPENSA_REPETIDA]

	for d in _elegir_opciones(fauna):
		var ficha := Button.new()
		ficha.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ficha.text = "%s (%s)\n%s" % [d.nombre_comun, d.tipo, d.rol_ecologico]
		ficha.pressed.connect(_on_ficha.bind(d, ficha))
		_fichas.add_child(ficha)


## El objetivo más dos distractores, priorizando los que suenan distinto (otra firma sonora) para
## que sea deducible: dos grupos diferentes pueden sonar igual, como crustáceos y caracoles de agua.
func _elegir_opciones(fauna: Array[EspecieData]) -> Array[EspecieData]:
	var firma_objetivo := SintetizadorFauna.firma(_objetivo)
	var distintas: Array[EspecieData] = []
	var iguales: Array[EspecieData] = []
	for d in fauna:
		if d == _objetivo:
			continue
		if SintetizadorFauna.firma(d) != firma_objetivo or d.audio_canto:
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
	var correcta := elegida == _objetivo
	var era_practica := _practicas_pendientes > 0
	var pr := 0
	if correcta and not era_practica:
		pr = RECOMPENSA_REPETIDA if _reconocidas.has(_objetivo.id_especie) else RECOMPENSA_PR
	GameState.registrar({"tipo": "sonido", "id_especie": _objetivo.id_especie, "especie": _objetivo.nombre_comun,
		"correcta": correcta, "tiempo_s": snappedf((Time.get_ticks_msec() - _inicio_ms) / 1000.0, 0.1),
		"pr": pr, "detalle": "eligio=%s;audio=%s%s" % [elegida.nombre_comun, "real" if _objetivo.audio_canto else "simulado",
			";practica" if era_practica else ""]})
	Sonidos.reproducir("correcta" if correcta else "incorrecta")
	if correcta:
		boton.modulate = Color(0.55, 1.0, 0.6)
		if era_practica:
			_practicas_pendientes -= 1
		_reconocidas[_objetivo.id_especie] = true
		if pr > 0:
			GameState.agregar_pr(pr)
		var nueva: bool = GameState.descubrir_especie(_objetivo)
		var premio := "+%d PR." % pr if pr > 0 else ("Práctica superada: la próxima ronda vuelve a dar PR." \
			if _practicas_pendientes == 0 else "Bien: te falta %d acierto más para volver a ganar PR." % _practicas_pendientes)
		_resultado.text = "¡Correcto! Era %s. %s %s%s" % [
			_objetivo.nombre_comun, explicacion, premio, " Nueva entrada en la Biopedia." if nueva else ""]
	else:
		boton.modulate = Color(1.0, 0.55, 0.5)
		_practicas_pendientes = PRACTICAS_TRAS_ERROR
		_resultado.text = "Era %s. %s No pierdes PR, pero pasas a práctica: acierta %d rondas seguidas para volver a ganar PR." % [_objetivo.nombre_comun, explicacion, PRACTICAS_TRAS_ERROR]
