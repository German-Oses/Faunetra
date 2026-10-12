extends Node

## Sonidos - Efectos y ambiente de Faunetra, sintetizados en tiempo de ejecución.
## Igual que SintetizadorFauna, no usa archivos: cada efecto se genera una vez y queda en caché,
## así el juego pesa poco en la web y no hay licencias de audio que gestionar.
## - Efectos de interfaz (clic en cualquier botón o pestaña) conectados automáticamente.
## - Efectos del refugio (disipar, limpiar, plantar, sanar, acción rechazada, llegada de fauna).
## - Trivias y minijuegos (correcta / incorrecta), desbloqueo de biomas.
## - Ambiente en bucle propio de cada bioma (viento, aves, grillos, oleaje).

const MUESTREO := 22050
const VOCES := 8
const VOLUMEN_EFECTOS_DB := -6.0
const VOLUMEN_AMBIENTE_DB := -15.0
const DURACION_AMBIENTE := 12.0
const FUNDIDO_BUCLE := 1.0
## Tiempo mínimo entre dos reproducciones del mismo efecto (evita metralla al tocar rápido).
const SEPARACION_MINIMA := 0.06

var _cache: Dictionary = {}
var _ultimo_uso: Dictionary = {}
var _voces: Array[AudioStreamPlayer] = []
var _siguiente_voz := 0
var _ambiente: AudioStreamPlayer
var _ambientes: Dictionary = {}  # id_bioma -> AudioStreamWAV
var _bioma_sonando := -1
var _tween_ambiente: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOCES:
		var voz := AudioStreamPlayer.new()
		voz.volume_db = VOLUMEN_EFECTOS_DB
		add_child(voz)
		_voces.append(voz)
	_ambiente = AudioStreamPlayer.new()
	_ambiente.volume_db = -80.0
	add_child(_ambiente)

	get_tree().node_added.connect(_on_nodo_agregado)
	EventBus.accion_terreno.connect(reproducir)
	EventBus.accion_rechazada.connect(func() -> void: reproducir("error"))
	EventBus.fauna_llego.connect(func(_data: EspecieData) -> void: reproducir("fauna"))
	EventBus.bioma_cargado.connect(iniciar_ambiente)
	GameState.bioma_desbloqueado.connect(func(_id: int) -> void: reproducir("desbloquear"))
	TriviaManager.respuesta_evaluada.connect(func(correcta: bool, _r: String, _xp: int) -> void:
		reproducir("correcta" if correcta else "incorrecta"))


## Reproduce un efecto por nombre (ver _generar). Variación leve de tono para que no canse.
func reproducir(nombre: String, variacion: float = 0.04) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - float(_ultimo_uso.get(nombre, -10.0)) < SEPARACION_MINIMA:
		return
	_ultimo_uso[nombre] = ahora
	if not _cache.has(nombre):
		_cache[nombre] = _a_wav(_generar(nombre))
	var voz := _voces[_siguiente_voz]
	_siguiente_voz = (_siguiente_voz + 1) % VOCES
	voz.stream = _cache[nombre]
	voz.pitch_scale = 1.0 + randf_range(-variacion, variacion)
	voz.play()


## Baja el ambiente unos segundos (p. ej. mientras suena un canto en el puzzle acústico).
func atenuar_ambiente(segundos: float) -> void:
	if _bioma_sonando < 0:
		return
	_fundir_ambiente(VOLUMEN_AMBIENTE_DB - 18.0, 0.3)
	_tween_ambiente.tween_interval(segundos)
	_tween_ambiente.tween_property(_ambiente, "volume_db", VOLUMEN_AMBIENTE_DB, 1.0)


func iniciar_ambiente(id_bioma: int) -> void:
	if id_bioma == _bioma_sonando:
		return
	_bioma_sonando = id_bioma
	if _ambientes.has(id_bioma):
		_cambiar_ambiente(_ambientes[id_bioma])
		return
	# Generar 12 s de ambiente toma un momento: lo hacemos fuera del hilo principal.
	WorkerThreadPool.add_task(func() -> void:
		var wav := _crear_ambiente(id_bioma)
		_listo_ambiente.call_deferred(id_bioma, wav))


func _listo_ambiente(id_bioma: int, wav: AudioStreamWAV) -> void:
	_ambientes[id_bioma] = wav
	if id_bioma == _bioma_sonando:
		_cambiar_ambiente(wav)


func _cambiar_ambiente(wav: AudioStreamWAV) -> void:
	if _ambiente.playing:
		_fundir_ambiente(-60.0, 0.6)
		_tween_ambiente.tween_callback(func() -> void:
			_ambiente.stream = wav
			_ambiente.play())
	else:
		_ambiente.stream = wav
		_ambiente.volume_db = -60.0
		_ambiente.play()
		_fundir_ambiente(VOLUMEN_AMBIENTE_DB, 0.01)
		return
	_tween_ambiente.tween_property(_ambiente, "volume_db", VOLUMEN_AMBIENTE_DB, 1.5)


func _fundir_ambiente(destino_db: float, segundos: float) -> void:
	if _tween_ambiente:
		_tween_ambiente.kill()
	_tween_ambiente = create_tween()
	_tween_ambiente.tween_property(_ambiente, "volume_db", destino_db, segundos)


# --- Clic automático en la interfaz ----------------------------------------------------------

func _on_nodo_agregado(nodo: Node) -> void:
	if nodo is BaseButton:
		if not nodo.pressed.is_connected(_on_boton):
			nodo.pressed.connect(_on_boton)
	elif nodo is TabBar:
		if not nodo.tab_clicked.is_connected(_on_pestana):
			nodo.tab_clicked.connect(_on_pestana)


func _on_boton() -> void:
	reproducir("clic", 0.06)


func _on_pestana(_i: int) -> void:
	reproducir("pestana", 0.03)


# --- Síntesis de efectos ---------------------------------------------------------------------

func _generar(nombre: String) -> PackedFloat32Array:
	match nombre:
		"clic":
			var m := _vacio(0.06)
			_tono(m, 0.0, 0.05, 1320.0, 0.5, 60.0)
			_tono(m, 0.0, 0.02, 2640.0, 0.15, 120.0)
			return m
		"pestana":
			var m := _vacio(0.09)
			_tono(m, 0.0, 0.04, 880.0, 0.35, 50.0)
			_tono(m, 0.035, 0.05, 1175.0, 0.35, 50.0)
			return m
		"disipar":
			# Ráfaga de viento que se abre: ruido con filtro que sube y baja, y un brillo al final.
			var m := _vacio(0.9)
			_soplido(m, 0.0, 0.85, 300.0, 2600.0, 0.9)
			_tono(m, 0.45, 0.4, 1568.0, 0.18, 7.0)
			_tono(m, 0.55, 0.35, 2093.0, 0.14, 8.0)
			return m
		"limpiar":
			# Tres raspones secos, como arrancar maleza o retirar basura.
			var m := _vacio(0.5)
			for i in 3:
				_ruido_golpe(m, i * 0.13, 0.09, 1800.0 - i * 300.0, 0.7)
			_tono(m, 0.0, 0.12, 140.0, 0.4, 25.0)
			return m
		"plantar":
			# Golpe suave de tierra y una campanita ascendente.
			var m := _vacio(0.7)
			_ruido_golpe(m, 0.0, 0.08, 500.0, 0.8)
			_tono(m, 0.0, 0.15, 110.0, 0.6, 20.0)
			_tono(m, 0.1, 0.35, 784.0, 0.3, 9.0)
			_tono(m, 0.2, 0.45, 1175.0, 0.3, 7.0)
			return m
		"sanar":
			# Arpegio cristalino que sube (Do mayor pentatónico).
			var m := _vacio(1.0)
			var notas := [523.25, 659.25, 783.99, 1046.5, 1318.5]
			for i in notas.size():
				_tono(m, i * 0.08, 0.5, notas[i], 0.28, 6.0, true)
			return m
		"error":
			# Dos notas graves cortas: avisa sin sonar a castigo.
			var m := _vacio(0.32)
			_tono(m, 0.0, 0.12, 220.0, 0.45, 18.0, true)
			_tono(m, 0.14, 0.16, 185.0, 0.45, 16.0, true)
			return m
		"correcta":
			var m := _vacio(0.9)
			var notas := [659.25, 783.99, 1046.5]
			for i in notas.size():
				_tono(m, i * 0.09, 0.55, notas[i], 0.35, 5.0, true)
			return m
		"incorrecta":
			# Descenso suave: el juego no castiga el error, solo lo marca.
			var m := _vacio(0.6)
			_tono(m, 0.0, 0.3, 392.0, 0.35, 7.0, true)
			_tono(m, 0.16, 0.4, 329.63, 0.35, 6.0, true)
			return m
		"fauna":
			# Pequeña fanfarria con trino: llegó un animal al refugio.
			var m := _vacio(1.4)
			var notas := [523.25, 659.25, 783.99, 1046.5]
			for i in notas.size():
				_tono(m, i * 0.11, 0.7, notas[i], 0.3, 4.0, true)
			for i in 4:
				_trino(m, 0.6 + i * 0.09, 0.07, 2800.0, 3600.0, 0.18)
			return m
		"desbloquear":
			var m := _vacio(2.0)
			var acordes := [[392.0, 493.88, 587.33], [523.25, 659.25, 783.99, 1046.5]]
			for a in acordes.size():
				for f in acordes[a]:
					_tono(m, a * 0.35, 1.5, f, 0.2, 2.5, true)
			_soplido(m, 0.3, 1.2, 1500.0, 5000.0, 0.25)
			return m
		"encontrado":
			var m := _vacio(0.5)
			_tono(m, 0.0, 0.3, 987.77, 0.35, 8.0, true)
			_tono(m, 0.08, 0.4, 1318.5, 0.35, 7.0, true)
			return m
	return _vacio(0.01)


func _vacio(segundos: float) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(int(segundos * MUESTREO))
	return m


## Nota con ataque corto y caída exponencial. "suave" suma armónicos tipo campana.
func _tono(m: PackedFloat32Array, t: float, duracion: float, f: float, volumen: float, caida: float, suave: bool = false) -> void:
	var inicio := int(t * MUESTREO)
	var largo := int(duracion * MUESTREO)
	var ataque := int(0.004 * MUESTREO)
	for i in largo:
		if inicio + i >= m.size():
			break
		var s := float(i) / MUESTREO
		var env := exp(-caida * s) * minf(1.0, float(i) / ataque)
		var fase := TAU * f * s
		var v := sin(fase)
		if suave:
			v += sin(fase * 2.0) * 0.3 * exp(-caida * s) + sin(fase * 3.0) * 0.1
		m[inicio + i] += v * env * volumen


func _trino(m: PackedFloat32Array, t: float, duracion: float, f0: float, f1: float, volumen: float) -> void:
	var inicio := int(t * MUESTREO)
	var largo := int(duracion * MUESTREO)
	var fase := 0.0
	for i in largo:
		if inicio + i >= m.size():
			break
		var avance := float(i) / largo
		fase += TAU * lerpf(f0, f1, avance) / MUESTREO
		m[inicio + i] += sin(fase) * sin(PI * avance) * volumen


## Ruido filtrado cuya frecuencia de corte sube y vuelve a bajar (viento, ráfaga).
func _soplido(m: PackedFloat32Array, t: float, duracion: float, f_baja: float, f_alta: float, volumen: float) -> void:
	var inicio := int(t * MUESTREO)
	var largo := int(duracion * MUESTREO)
	var a := 0.0
	var b := 0.0
	for i in largo:
		if inicio + i >= m.size():
			break
		var avance := float(i) / largo
		var corte := lerpf(f_baja, f_alta, sin(PI * avance))
		var k := 1.0 - exp(-TAU * corte / MUESTREO)
		a = lerpf(a, randf_range(-1.0, 1.0), k)
		b = lerpf(b, a, k)
		m[inicio + i] += (a - b * 0.5) * sin(PI * avance) * volumen


func _ruido_golpe(m: PackedFloat32Array, t: float, duracion: float, corte: float, volumen: float) -> void:
	var inicio := int(t * MUESTREO)
	var largo := int(duracion * MUESTREO)
	var k := 1.0 - exp(-TAU * corte / MUESTREO)
	var a := 0.0
	for i in largo:
		if inicio + i >= m.size():
			break
		a = lerpf(a, randf_range(-1.0, 1.0), k)
		m[inicio + i] += a * exp(-8.0 * float(i) / largo) * volumen * 3.0


# --- Ambientes por bioma ---------------------------------------------------------------------

## Ids: 1 Zona Central, 2 Norte Árido, 3 Bosque Templado, 4 Patagonia, 5 Territorios Insulares.
## Las modulaciones lentas usan ciclos enteros dentro del bucle y el final se funde con el inicio,
## así el ambiente se repite sin que se note el corte.
func _crear_ambiente(id_bioma: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = id_bioma * 7919 + 13
	var total := int((DURACION_AMBIENTE + FUNDIDO_BUCLE) * MUESTREO)
	var m := PackedFloat32Array()
	m.resize(total)
	match id_bioma:
		1:
			_viento(m, rng, 500.0, 0.35, 2)
			_grillos(m, rng, 4200.0, 0.06)
			_aves(m, rng, 5, 2200.0, 3200.0)
		2:
			_viento(m, rng, 380.0, 0.55, 3)
			_crujidos_secos(m, rng, 30)
		3:
			_viento(m, rng, 700.0, 0.3, 2)
			_hojas(m, rng)
			_aves(m, rng, 10, 1800.0, 3600.0)
		4:
			_viento(m, rng, 450.0, 0.75, 4)
			_aves(m, rng, 2, 1400.0, 2000.0)
		5:
			_olas(m, rng)
			_viento(m, rng, 600.0, 0.25, 2)
			_aves(m, rng, 3, 1200.0, 1800.0)
	return _a_wav(_cerrar_bucle(m), true)


func _cerrar_bucle(m: PackedFloat32Array) -> PackedFloat32Array:
	var largo := int(DURACION_AMBIENTE * MUESTREO)
	var fundido := int(FUNDIDO_BUCLE * MUESTREO)
	var salida := m.slice(0, largo)
	for i in fundido:
		var w := float(i) / fundido
		salida[i] = m[i] * w + m[largo + i] * (1.0 - w)
	return salida


## Viento: ruido filtrado con ráfagas lentas (ciclos enteros por bucle).
func _viento(m: PackedFloat32Array, rng: RandomNumberGenerator, corte: float, fuerza: float, rafagas: int) -> void:
	var a := 0.0
	var b := 0.0
	var fase_extra := rng.randf() * TAU
	for i in m.size():
		var s := float(i) / MUESTREO
		var lfo := 0.5 + 0.5 * sin(TAU * rafagas * s / DURACION_AMBIENTE + fase_extra)
		var lfo2 := 0.5 + 0.5 * sin(TAU * (rafagas * 2 + 1) * s / DURACION_AMBIENTE)
		var k := 1.0 - exp(-TAU * corte * (0.5 + lfo) / MUESTREO)
		a = lerpf(a, rng.randf_range(-1.0, 1.0), k)
		b = lerpf(b, a, k)
		m[i] += b * fuerza * (0.35 + 0.65 * lfo * (0.7 + 0.3 * lfo2)) * 2.5


func _aves(m: PackedFloat32Array, rng: RandomNumberGenerator, cantidad: int, f_min: float, f_max: float) -> void:
	for _a in cantidad:
		var t := rng.randf_range(0.3, DURACION_AMBIENTE - 1.0)
		var base := rng.randf_range(f_min, f_max)
		var notas := rng.randi_range(2, 5)
		var dur := rng.randf_range(0.05, 0.12)
		var vol := rng.randf_range(0.05, 0.12)
		for n in notas:
			var f0 := base * rng.randf_range(0.9, 1.15)
			_trino(m, t, dur, f0, f0 * rng.randf_range(1.1, 1.4), vol)
			t += dur + rng.randf_range(0.02, 0.07)


## Grillos: chirridos pulsados agudos, regulares como en una tarde de verano.
func _grillos(m: PackedFloat32Array, rng: RandomNumberGenerator, f: float, volumen: float) -> void:
	var periodo := 0.55
	var t := rng.randf_range(0.0, 0.3)
	while t < DURACION_AMBIENTE + FUNDIDO_BUCLE - 0.2:
		var inicio := int(t * MUESTREO)
		var largo := int(0.12 * MUESTREO)
		for i in largo:
			if inicio + i >= m.size():
				break
			var s := float(i) / MUESTREO
			var am := 0.5 + 0.5 * signf(sin(TAU * 45.0 * s))
			m[inicio + i] += sin(TAU * f * s) * am * sin(PI * float(i) / largo) * volumen
		t += periodo + rng.randf_range(-0.03, 0.03)


func _crujidos_secos(m: PackedFloat32Array, rng: RandomNumberGenerator, cantidad: int) -> void:
	for _c in cantidad:
		var inicio := int(rng.randf_range(0.0, DURACION_AMBIENTE) * MUESTREO)
		var largo := int(0.008 * MUESTREO)
		for i in largo:
			if inicio + i >= m.size():
				break
			m[inicio + i] += rng.randf_range(-1.0, 1.0) * exp(-6.0 * float(i) / largo) * 0.12


## Hojas: susurro agudo y suave que acompaña al viento del bosque.
func _hojas(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var previo := 0.0
	for i in m.size():
		var s := float(i) / MUESTREO
		var ruido := rng.randf_range(-1.0, 1.0)
		var agudo := ruido - previo
		previo = ruido
		var mod := 0.5 + 0.5 * sin(TAU * 3.0 * s / DURACION_AMBIENTE)
		m[i] += agudo * 0.025 * mod


## Oleaje: grandes vaivenes de ruido grave, cuatro olas por bucle.
func _olas(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var a := 0.0
	var b := 0.0
	for i in m.size():
		var s := float(i) / MUESTREO
		var ola := pow(0.5 + 0.5 * sin(TAU * 4.0 * s / DURACION_AMBIENTE), 2.0)
		var k := 1.0 - exp(-TAU * (250.0 + 900.0 * ola) / MUESTREO)
		a = lerpf(a, rng.randf_range(-1.0, 1.0), k)
		b = lerpf(b, a, k)
		m[i] += b * (0.15 + ola) * 1.6


## Los efectos conservan su volumen relativo (saturación suave con tanh); el ambiente se normaliza.
func _a_wav(m: PackedFloat32Array, bucle: bool = false) -> AudioStreamWAV:
	var escala := 1.0
	if bucle:
		var maximo := 0.001
		for v in m:
			maximo = maxf(maximo, absf(v))
		escala = 0.85 / maximo
	var bytes := PackedByteArray()
	bytes.resize(m.size() * 2)
	for i in m.size():
		var v := m[i] * escala if bucle else tanh(m[i])
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUESTREO
	wav.stereo = false
	wav.data = bytes
	if bucle:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = m.size()
	return wav
