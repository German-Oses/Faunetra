class_name SintetizadorFauna
extends RefCounted

## Genera paisajes sonoros procedurales para especies sin grabación (audio_canto vacío).
## El grupo biológico viene explícito en cada ficha (EspecieData.grupo, asignado por taxonomía);
## antes se deducía buscando palabras en el nombre y el rol, y fallaba: «cordillerana» contiene
## «rana», el rol del gato montés menciona aves... Cada grupo tiene una firma acústica (aves agudas
## y moduladas, anfibios con croares pulsados, insectos que zumban...) y cada especie varía tono y
## ritmo según su id. Los animales que no vocalizan (caracoles, crustáceos, arañas, reptiles) se
## representan con el sonido de su ambiente, y la explicación lo dice.

const MUESTREO := 22050
const DURACION := 3.0

## Qué se escucha de cada grupo (explicación que ve el jugador después de responder).
const DESCRIPCIONES := {
	"ave": "Cantos agudos y modulados: las aves usan silbidos y trinos para marcar territorio y comunicarse a distancia.",
	"mamifero": "Resoplidos graves y pasos entre la vegetación, propios de mamíferos.",
	"mamifero_marino": "Silbidos y chasquidos bajo el agua: los delfines se comunican y se orientan con sonidos agudos.",
	"anfibio": "Croares graves y pulsados, típicos de anfibios que llaman desde zonas húmedas.",
	"reptil": "Los reptiles casi no vocalizan: se oyen sus pasos y roces sobre la hojarasca y la roca.",
	"reptil_marino": "La serpiente marina no vocaliza: se oye el oleaje del mar abierto donde vive.",
	"insecto": "Zumbido del batir rápido de alas, típico de moscas y escarabajos en vuelo.",
	"aracnido": "Arañas y seudoescorpiones no emiten cantos: se oyen leves roces entre la hojarasca y el suelo.",
	"crustaceo": "Pancoras y camarones no vocalizan: se oye el agua del río, la poza o la costa donde viven.",
	"caracol_acuatico": "Los caracoles no emiten sonidos: se oye el agua de la vertiente donde viven.",
	"caracol_terrestre": "Los caracoles no emiten sonidos: se oye el roce de la hojarasca húmeda del bosque.",
}
## Firma sonora de cada grupo. Grupos distintos pueden sonar igual (crustáceos y caracoles de
## agua dulce suenan a agua): para elegir alternativas que se distingan al oído se compara la firma.
const FIRMAS := {
	"ave": "cantos", "mamifero": "resoplidos", "mamifero_marino": "silbidos_marinos", "anfibio": "croares",
	"reptil": "crujidos", "reptil_marino": "oleaje", "insecto": "zumbido", "aracnido": "roces",
	"crustaceo": "agua", "caracol_acuatico": "agua", "caracol_terrestre": "roces",
}

static var _cache: Dictionary = {}
static var _sin_grupo_avisado: Dictionary = {}


## Grupo biológico de la ficha (ver EspecieData.grupo).
static func categoria(data: EspecieData) -> String:
	if data.grupo in EspecieData.GRUPOS:
		return data.grupo
	# Ficha de fauna sin grupo: se avisa una vez y se usa un valor neutro según el tipo.
	if not _sin_grupo_avisado.has(data.id_especie):
		_sin_grupo_avisado[data.id_especie] = true
		push_warning("[SintetizadorFauna] %s no tiene un grupo válido en su ficha (grupo = \"%s\")." % [data.nombre_comun, data.grupo])
	return "ave" if data.tipo == "ave" else "mamifero"


## Firma sonora de la ficha: dos especies con la misma firma suenan parecido.
static func firma(data: EspecieData) -> String:
	return FIRMAS.get(categoria(data), "resoplidos")


static func descripcion(data: EspecieData) -> String:
	return DESCRIPCIONES.get(categoria(data), "")


static func generar(data: EspecieData) -> AudioStreamWAV:
	if _cache.has(data.id_especie):
		return _cache[data.id_especie]
	var rng := RandomNumberGenerator.new()
	rng.seed = data.id_especie * 92821 + 7
	var muestras := PackedFloat32Array()
	muestras.resize(int(MUESTREO * DURACION))
	match firma(data):
		"cantos":
			_cantos(muestras, rng)
		"croares":
			_croares(muestras, rng)
		"zumbido":
			_zumbido(muestras, rng)
		"agua":
			_burbujas(muestras, rng)
		"oleaje":
			_oleaje(muestras, rng, 1.0)
		"silbidos_marinos":
			_oleaje(muestras, rng, 0.5)
			_silbidos(muestras, rng)
		"crujidos":
			_crujidos(muestras, rng)
		"roces":
			_roces(muestras, rng)
		_:
			_resoplidos(muestras, rng)
	# Viento de fondo muy suave para que suene a paisaje y no a tono de laboratorio.
	for i in muestras.size():
		muestras[i] += rng.randf_range(-1.0, 1.0) * 0.015
	var wav := _a_wav(muestras)
	_cache[data.id_especie] = wav
	return wav


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


## Mar abierto: ruido filtrado con oleaje lento.
static func _oleaje(m: PackedFloat32Array, rng: RandomNumberGenerator, volumen: float) -> void:
	var previo := 0.0
	var ola := rng.randf_range(0.15, 0.3)
	for i in m.size():
		previo = lerpf(previo, rng.randf_range(-1.0, 1.0), 0.012)
		m[i] += previo * (0.4 + 0.6 * pow(0.5 + 0.5 * sin(TAU * ola * float(i) / MUESTREO), 2.0)) * volumen


## Delfines: silbidos agudos que suben y bajan, con trenes de chasquidos.
static func _silbidos(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var t := 0.2
	while t < DURACION - 0.6:
		var f0 := rng.randf_range(4500.0, 7000.0)
		_barrido(m, t, rng.randf_range(0.25, 0.45), f0, f0 * rng.randf_range(0.6, 1.4), 0.4)
		t += rng.randf_range(0.5, 0.8)
		for _c in rng.randi_range(6, 12):
			var inicio := int(t * MUESTREO)
			for i in int(0.003 * MUESTREO):
				if inicio + i < m.size():
					m[inicio + i] += rng.randf_range(-1.0, 1.0) * 0.5
			t += 0.03
		t += rng.randf_range(0.1, 0.3)


## Animales que no vocalizan sobre hojarasca: roces suaves y espaciados.
static func _roces(m: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var t := 0.1
	while t < DURACION:
		var inicio := int(t * MUESTREO)
		var largo := int(rng.randf_range(0.02, 0.06) * MUESTREO)
		var ruido := 0.0
		for i in largo:
			if inicio + i >= m.size():
				break
			ruido = lerpf(ruido, rng.randf_range(-1.0, 1.0), 0.3)
			m[inicio + i] += ruido * sin(PI * i / largo) * 0.35
		t += rng.randf_range(0.12, 0.4)


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
