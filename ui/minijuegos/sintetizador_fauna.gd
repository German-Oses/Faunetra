class_name SintetizadorFauna
extends RefCounted

## Genera paisajes sonoros procedurales para especies sin grabación (audio_canto vacío).
## Cada grupo tiene una firma acústica reconocible (aves agudas y moduladas, anfibios con
## croares pulsados, insectos que zumban...) y cada especie varía tono y ritmo según su id,
## de modo que el jugador pueda deducir la ficha correcta a partir de lo que escucha.

const MUESTREO := 22050
const DURACION := 3.0

const DESCRIPCIONES := {
	"ave": "Cantos agudos y modulados: las aves usan silbidos y trinos para marcar territorio y comunicarse a distancia.",
	"anfibio": "Croares graves y pulsados, típicos de anfibios que llaman desde zonas húmedas.",
	"insecto": "Zumbido continuo producido por el batir rápido de alas.",
	"acuatico": "Burbujeo y chapoteos: sonidos de un ambiente acuático o costero.",
	"reptil": "Crujidos secos de hojarasca y roca: reptiles que se desplazan sobre el suelo.",
	"invertebrado": "Leves chasquidos y roces: pequeños invertebrados moviéndose entre el sustrato.",
	"mamifero": "Resoplidos graves y pasos entre la vegetación, propios de mamíferos.",
}

static var _cache: Dictionary = {}


static func categoria(data: EspecieData) -> String:
	var texto := ReglasEcosistema.normalizar(data.nombre_comun + " " + data.rol_ecologico)
	if data.tipo == "ave" or _contiene(texto, ["ave ", "aves ", "loro", "condor", "flamenco", "fardela", "cometocino", "choroy", "cuervo", "huairavillo", "picaflor", "pajaro"]):
		return "ave"
	if _contiene(texto, ["rana", "sapo", "anfibio"]):
		return "anfibio"
	if _contiene(texto, ["delfin", "marin", "camaron", "pancora", "acuatic"]):
		return "acuatico"
	if _contiene(texto, ["lagartija", "gecko", "corredor", "serpiente", "reptil"]):
		return "reptil"
	if _contiene(texto, ["mosca", "abeja", "insecto", "polinizador"]):
		return "insecto"
	if data.tipo == "invertebrado":
		return "invertebrado"
	return "mamifero"


static func descripcion(data: EspecieData) -> String:
	return DESCRIPCIONES.get(categoria(data), "")


static func generar(data: EspecieData) -> AudioStreamWAV:
	if _cache.has(data.id_especie):
		return _cache[data.id_especie]
	var rng := RandomNumberGenerator.new()
	rng.seed = data.id_especie * 92821 + 7
	var muestras := PackedFloat32Array()
	muestras.resize(int(MUESTREO * DURACION))
	match categoria(data):
		"ave":
			_cantos(muestras, rng)
		"anfibio":
			_croares(muestras, rng)
		"insecto":
			_zumbido(muestras, rng)
		"acuatico":
			_burbujas(muestras, rng)
		"reptil", "invertebrado":
			_crujidos(muestras, rng)
		_:
			_resoplidos(muestras, rng)
	# Viento de fondo muy suave para que suene a paisaje y no a tono de laboratorio.
	for i in muestras.size():
		muestras[i] += rng.randf_range(-1.0, 1.0) * 0.015
	var wav := _a_wav(muestras)
	_cache[data.id_especie] = wav
	return wav


static func _contiene(texto: String, palabras: Array) -> bool:
	for p in palabras:
		if texto.contains(p):
			return true
	return false


static func _cantos(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var base := rng.randf_range(1800.0, 3400.0)
	var notas := rng.randi_range(3, 6)
	var duracion_nota := rng.randf_range(0.07, 0.16)
	var ascendente := rng.randf() < 0.5
	var t := 0.2
	while t < DURACION - 0.5:
		for n in notas:
			var f0 := base * (1.0 + 0.08 * n) if ascendente else base * (1.3 - 0.07 * n)
			_barrido(m, t, duracion_nota, f0, f0 * rng.randf_range(1.15, 1.5), 0.5)
			t += duracion_nota + 0.04
		t += rng.randf_range(0.4, 0.7)


static func _croares(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var f := rng.randf_range(220.0, 480.0)
	var pulso := rng.randf_range(22.0, 40.0)
	var periodo := rng.randf_range(0.45, 0.8)
	var t := 0.15
	while t < DURACION - 0.3:
		var inicio := int(t * MUESTREO)
		var largo := int(0.24 * MUESTREO)
		var fase := 0.0
		for i in largo:
			if inicio + i >= m.size():
				break
			var s := float(i) / MUESTREO
			fase += TAU * f / MUESTREO
			var am := 0.5 + 0.5 * signf(sin(TAU * pulso * s))
			m[inicio + i] += sin(fase) * am * sin(PI * i / largo) * 0.6
		t += periodo


static func _zumbido(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var f := rng.randf_range(170.0, 260.0)
	var vaiven := rng.randf_range(0.4, 1.2)
	var fase := 0.0
	for i in m.size():
		var s := float(i) / MUESTREO
		fase += TAU * (f + 12.0 * sin(TAU * vaiven * s)) / MUESTREO
		var sierra := fmod(fase / TAU, 1.0) * 2.0 - 1.0
		m[i] += sierra * (0.2 + 0.12 * sin(TAU * 0.5 * s))


static func _burbujas(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var cantidad := rng.randi_range(18, 30)
	for _b in cantidad:
		var t := rng.randf_range(0.0, DURACION - 0.1)
		var f0 := rng.randf_range(450.0, 1100.0)
		_barrido(m, t, 0.05, f0, f0 * 2.2, 0.35, true)
	# Oleaje: ruido filtrado lentamente modulado.
	var previo := 0.0
	for i in m.size():
		previo = lerpf(previo, rng.randf_range(-1.0, 1.0), 0.02)
		m[i] += previo * (0.5 + 0.5 * sin(TAU * 0.3 * float(i) / MUESTREO)) * 0.8


static func _crujidos(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var t := 0.1
	var densidad := rng.randf_range(0.05, 0.25)
	while t < DURACION:
		var inicio := int(t * MUESTREO)
		var largo := int(0.012 * MUESTREO)
		for i in largo:
			if inicio + i >= m.size():
				break
			m[inicio + i] += rng.randf_range(-1.0, 1.0) * exp(-6.0 * i / largo) * 0.6
		t += rng.randf_range(0.02, densidad)


static func _resoplidos(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var f := rng.randf_range(85.0, 170.0)
	for _r in rng.randi_range(2, 4):
		var inicio := int(rng.randf_range(0.1, DURACION - 0.5) * MUESTREO)
		var largo := int(rng.randf_range(0.18, 0.35) * MUESTREO)
		var fase := 0.0
		var ruido := 0.0
		for i in largo:
			if inicio + i >= m.size():
				break
			fase += TAU * f / MUESTREO
			ruido = lerpf(ruido, rng.randf_range(-1.0, 1.0), 0.15)
			var env := sin(PI * i / largo)
			m[inicio + i] += (sin(fase) * 0.5 + sin(fase * 2.0) * 0.2 + ruido * 0.5) * env * 0.7
	_crujidos(m, rng)


static func _barrido(m: PackedFloat32Array, t: float, duracion: float, f0: float, f1: float, volumen: float, decae: bool = false) -> void:
	var inicio := int(t * MUESTREO)
	var largo := int(duracion * MUESTREO)
	var fase := 0.0
	for i in largo:
		if inicio + i >= m.size():
			break
		var avance := float(i) / largo
		fase += TAU * lerpf(f0, f1, avance) / MUESTREO
		var env := exp(-5.0 * avance) if decae else sin(PI * avance)
		m[inicio + i] += sin(fase) * env * volumen


static func _a_wav(m: PackedFloat32Array) -> AudioStreamWAV:
	var maximo := 0.001
	for v in m:
		maximo = maxf(maximo, absf(v))
	var escala := 0.8 / maximo
	var bytes := PackedByteArray()
	bytes.resize(m.size() * 2)
	for i in m.size():
		bytes.encode_s16(i * 2, int(clampf(m[i] * escala, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUESTREO
	wav.stereo = false
	wav.data = bytes
	return wav
