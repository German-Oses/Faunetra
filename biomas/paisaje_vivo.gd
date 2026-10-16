class_name PaisajeVivo
extends Node

## El paisaje alrededor del refugio refleja su salud: al comenzar está degradado (suelo seco,
## agua turbia, árboles muertos y tocones) y se recupera desde el refugio hacia afuera a medida
## que sube la salud, hasta quedar todo verde al alcanzar la meta de desbloqueo.
## - Cada parcela exterior tiene un umbral de salud: crece con la distancia al refugio y lleva
##   ruido, así lo verde avanza como una mancha irregular y no como un anillo.
## - Tres estados por parcela: seco, brotando (mitad seca, mitad verde, con arbolitos jóvenes)
##   y sano. Los cambios se aplican de a poco, en orden de umbral, para que se vea el avance.
## - Las baldosas degradadas no son arte aparte: se derivan del tileset del bioma al cargar
##   (mismas coordenadas en otras dos fuentes del TileSet), así siguen cualquier cambio del arte.
## - La caseta del guardaparque marca el avance: abandonada, en reparación y restaurada (con humo).
## - Desierto Florido (solo Norte Árido): desde FLORIDO_DESDE de la meta, la arena se cubre de flores
##   nativas (pata de guanaco, suspiro, malvilla, añañuca, garra de león), también desde el refugio
##   hacia afuera. Se retiran si la salud baja. La primera vez se explica el fenómeno.

enum Estado { SECO, BROTANDO, SANO }

const FUENTE_SECA := 1
const FUENTE_BROTANDO := 2
## Margen de salud (puntos) en que una parcela está brotando antes de quedar sana.
const MARGEN_BROTE := 10.0
## La parcela más cercana se recupera con esta salud; la más lejana justo antes de la meta.
const UMBRAL_MINIMO := 16.0
const ESCALA_JOVEN := 0.5
## Cambios de parcela por segundo al avanzar (o retroceder) el paisaje; con un salto grande de
## salud se acelera para que el avance nunca tarde más de DURACION_AVANCE segundos.
const CAMBIOS_POR_SEGUNDO := 90.0
const DURACION_AVANCE := 2.5

## Suelo seco de cada bioma, de oscuro a claro (se mapea según la luminosidad del original).
const SUELO_SECO := {
	1: ["#4A3A28", "#7A6040", "#A88A5C", "#CBB07C"],
	2: ["#5A4E44", "#8A7A68", "#B4A48C", "#D2C4AA"],
	3: ["#43362A", "#6E5A42", "#94805E", "#B4A07A"],
	4: ["#4C4236", "#786A54", "#A09072", "#C2B494"],
	5: ["#4A3A2E", "#7A5E46", "#A6845E", "#C8A87C"],
}
## Etapas de la caseta como fracción de la meta del bioma.
const CASETA_REPARACION := 0.25
const CASETA_RESTAURADA := 0.6
## Punta de la chimenea respecto del pie de la caseta (caseta.png, 64x64, anclada abajo al centro).
const CHIMENEA := Vector2(11.0, -41.3)

## Desierto Florido: bioma, fracción de la meta desde la que florece y especies con su peso
## (la pata de guanaco forma los mantos más extensos). Arte: herramientas/aseprite/desierto_florido.lua.
const BIOMA_FLORIDO := 2
const FLORIDO_DESDE := 0.9
const FLORES := {"pata_de_guanaco": 5, "suspiro": 2, "malvilla": 2, "ananuca_roja": 1,
	"ananuca_amarilla": 1, "garra_de_leon": 1}
const RUTA_FLORES := "res://Assets/decoracion/flores_%s_%s.png"
## Bajo este ruido la parcela queda como claro de arena (aprox. una de cada cuatro).
const CLAROS_FLORIDO := -0.5

const COLOR_AGUA_TURBIA := Color("#6B6450")
## Columnas del tileset que se degradan: suelo (0-2), agua (4-5) y suelo especial (6).
const COLUMNAS_SUELO: Array[int] = [0, 1, 2, 6]
const COLUMNAS_AGUA: Array[int] = [4, 5]

var id_bioma := -1
var _capas: Array[TileMapLayer] = []
var _celdas: Array[Vector2i] = []
var _umbral: Dictionary = {}      # Vector2i -> salud (%) desde la que la parcela está sana
var _posicion: Dictionary = {}    # Vector2i -> Vector2(distancia normalizada, ruido) para recalcular _umbral
var _estado: Dictionary = {}      # Vector2i -> Estado mostrado
var _decoraciones: Dictionary = {}  # Vector2i -> Array[{sprite, tipo, textura, escala}]
var _pendientes: Array[Vector2i] = []
var _acumulado := 0.0
var _velocidad := CAMBIOS_POR_SEGUNDO
var _salud := 0.0
var _caseta: Sprite2D
var _etapa_caseta := ""
var _humo: CPUParticles2D
var _tilemap: TileMapLayer
var _contenedor: Node2D
var _alturas: Dictionary = {}
var _umbral_flor: Dictionary = {}  # Vector2i -> salud (%) desde la que florece (solo arena del desierto)
var _florido: Dictionary = {}      # Vector2i -> bool mostrado
var _flores: Dictionary = {}       # Vector2i -> Array[Sprite2D] (se crean la primera vez que florece)


func configurar(p_id_bioma: int, tilemap: TileMapLayer, mapa: Dictionary) -> void:
	id_bioma = p_id_bioma
	_tilemap = tilemap
	_alturas = mapa.get("alturas", {})
	_capas = [tilemap]
	_capas.append_array(mapa.get("capas", []))
	_agregar_fuentes(tilemap.tile_set)

	var r := GeneradorMapa.RADIO_JUGABLE
	var alcance := float(GeneradorMapa.RADIO_EXTERIOR - r)
	for c: Vector2i in mapa.get("tipos", {}):
		var distancia := maxi(absi(c.x), absi(c.y)) - r
		if distancia <= 0:
			continue   # el refugio lo restaura el jugador parcela a parcela
		var t := clampf(distancia / alcance, 0.0, 1.0)
		var ruido := GeneradorMapa._ruido_suave(c.x, c.y, 17 * id_bioma) * 5.0 + GeneradorMapa._ruido(c.x, c.y, 3 * id_bioma) * 2.0
		_posicion[c] = Vector2(t, ruido)
		_celdas.append(c)
		# Florece sobre arena (el salar, el agua y la roca no), en mantos con claros entre medio.
		if id_bioma == BIOMA_FLORIDO and mapa["tipos"][c] == "suelo" \
				and _alturas.get(c, 0) < GeneradorMapa._roca_desde(id_bioma) \
				and GeneradorMapa._ruido_suave(c.x, c.y, 91) * 0.3 + GeneradorMapa._ruido(c.x, c.y, 37) > CLAROS_FLORIDO:
			_umbral_flor[c] = 0.0
	_calcular_umbrales()
	for item: Dictionary in mapa.get("paisaje", []):
		var s: Sprite2D = item["sprite"]
		var lista: Array = _decoraciones.get(item["celda"], [])
		lista.append({"sprite": s, "tipo": item["tipo"], "textura": s.texture, "escala": s.scale})
		_decoraciones[item["celda"]] = lista

	_caseta = mapa.get("decoraciones", {}).get(GeneradorMapa.CASETA)
	_contenedor = _caseta.get_parent() if _caseta else tilemap.get_parent()
	_salud = GameState.calcular_salud(id_bioma)
	_actualizar_caseta(false)
	# Al cargar, el paisaje aparece directamente en su estado (sin animar el avance).
	for c in _celdas:
		_aplicar(c, _estado_para(c, _salud), false)
		_aplicar_flores(c, _florido_para(c, _salud), false)
	if _florido.values().has(true):
		_avisar_desierto_florido.call_deferred()   # partidas que ya estaban floridas al cargar
	GameState.salud_actualizada.connect(_on_salud)
	GameState.modo_cambiado.connect(_on_modo_cambiado)


## Umbral de cada parcela según la meta de desbloqueo del modo actual.
func _calcular_umbrales() -> void:
	var meta: float = GameState.umbral_desbloqueo()
	for c in _celdas:
		var p: Vector2 = _posicion[c]
		_umbral[c] = clampf(lerpf(UMBRAL_MINIMO, meta - 1.0, p.x) + p.y, UMBRAL_MINIMO, meta - 1.0)
		if _umbral_flor.has(c):
			var desde: float = meta * FLORIDO_DESDE
			_umbral_flor[c] = maxf(_umbral[c], clampf(lerpf(desde, meta - 0.5, p.x) + p.y * 0.3, desde, meta - 0.5))


## El modo se elige con el primer bioma ya cargado: la meta cambia y el paisaje se reajusta.
func _on_modo_cambiado(_id_modo: String) -> void:
	_calcular_umbrales()
	_pendientes.clear()
	_acumulado = 0.0
	for c in _celdas:
		_aplicar(c, _estado_para(c, _salud), false)
		_aplicar_flores(c, _florido_para(c, _salud), false)
	_actualizar_caseta(true)


func _on_salud(p_id_bioma: int, salud: float) -> void:
	if p_id_bioma != id_bioma or is_equal_approx(salud, _salud):
		return
	var subio := salud > _salud
	_salud = salud
	_pendientes.clear()
	for c in _celdas:
		if _estado_para(c, salud) != _estado[c] or _florido_para(c, salud) != _florido.get(c, false):
			_pendientes.append(c)
	# Lo verde avanza desde el refugio hacia afuera; la degradación, desde afuera hacia adentro.
	_pendientes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (_umbral[a] > _umbral[b]) if subio else (_umbral[a] < _umbral[b]))
	_velocidad = maxf(CAMBIOS_POR_SEGUNDO, _pendientes.size() / DURACION_AVANCE)
	_actualizar_caseta(true)


func _process(delta: float) -> void:
	if _pendientes.is_empty():
		return
	_acumulado += delta * _velocidad
	while _acumulado >= 1.0 and not _pendientes.is_empty():
		_acumulado -= 1.0
		var c: Vector2i = _pendientes.pop_back()
		_aplicar(c, _estado_para(c, _salud), true)
		_aplicar_flores(c, _florido_para(c, _salud), true)
	if _pendientes.is_empty():
		_acumulado = 0.0


func _estado_para(c: Vector2i, salud: float) -> Estado:
	var u: float = _umbral[c]
	if salud >= u:
		return Estado.SANO
	if salud >= u - MARGEN_BROTE:
		return Estado.BROTANDO
	return Estado.SECO


func _florido_para(c: Vector2i, salud: float) -> bool:
	return _umbral_flor.has(c) and salud >= _umbral_flor[c]


## Flores de la parcela: uno o dos manchones de una especie, elegidos de forma fija por parcela.
func _aplicar_flores(c: Vector2i, florece: bool, animar: bool) -> void:
	if not _umbral_flor.has(c) or _florido.get(c, false) == florece:
		return
	_florido[c] = florece
	if florece and not _flores.has(c):
		_flores[c] = _crear_flores(c)
	for s: Sprite2D in _flores.get(c, []):
		if s.has_meta("tween"):
			(s.get_meta("tween") as Tween).kill()
		s.visible = true
		if not animar:
			s.visible = florece
			s.scale = Vector2.ONE
			continue
		var tween := s.create_tween()
		s.set_meta("tween", tween)
		if florece:
			s.scale = Vector2(0.2, 0.0)
			tween.tween_property(s, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tween.tween_property(s, "scale", Vector2(0.2, 0.0), 0.35)
			tween.tween_callback(s.hide)
	if florece and animar:
		_avisar_desierto_florido()


func _crear_flores(c: Vector2i) -> Array[Sprite2D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, 7919))
	var total := 0
	for n in FLORES:
		total += FLORES[n]
	var lista: Array[Sprite2D] = []
	var subir := Vector2(0, -GeneradorMapa.ALTO_NIVEL * int(_alturas.get(c, 0)))
	for i in (2 if rng.randf() < 0.55 else 1):
		var r := rng.randi_range(1, total)
		var especie := ""
		for n in FLORES:
			r -= FLORES[n]
			if r <= 0:
				especie = n
				break
		var variante := "a" if rng.randf() < 0.5 else "b"
		var s := Sprite2D.new()
		s.name = "Flores_%s_%d_%d_%d" % [especie, c.x, c.y, i]
		s.texture = load(RUTA_FLORES % [especie, variante])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.flip_h = rng.randf() < 0.5
		s.z_index = -1   # a ras de suelo: los cardones y la fauna quedan por encima
		_contenedor.add_child(s)
		var desfase := Vector2(rng.randi_range(-10, 10), rng.randi_range(-4, 5)) + subir
		s.global_position = _tilemap.to_global(_tilemap.map_to_local(c)) + desfase
		lista.append(s)
	return lista


## La primera vez que florece el desierto se explica el fenómeno real (queda en el registro).
func _avisar_desierto_florido() -> void:
	var estado: Dictionary = GameState.estado_bioma(id_bioma)
	if estado.get("florido_visto", false):
		return
	estado["florido_visto"] = true
	GameState.marcar_cambios()
	GameState.registrar({"tipo": "desierto_florido", "id_bioma": id_bioma, "detalle": "salud=%.1f" % _salud})
	EventBus.dialogo.emit("¡Desierto Florido!",
		"Tu refugio está casi restaurado y la arena se cubrió de flores. En la costa y los llanos de "
		+ "Atacama, semillas y bulbos esperan años bajo el suelo; cuando llueve más de lo normal "
		+ "(a menudo en años de El Niño) germinan todas juntas: pata de guanaco, suspiros, añañucas "
		+ "y la escasa garra de león. Dura unas semanas y es uno de los fenómenos más famosos de Chile.")


func _aplicar(c: Vector2i, estado: Estado, animar: bool) -> void:
	if _estado.get(c, -1) == estado:
		return
	_estado[c] = estado
	var fuente: int = [FUENTE_SECA, FUENTE_BROTANDO, 0][estado]
	for capa in _capas:
		var coords := capa.get_cell_atlas_coords(c)
		if coords.x >= 0:
			capa.set_cell(c, fuente, coords)
	for deco: Dictionary in _decoraciones.get(c, []):
		if deco["tipo"] == "arbol":
			_aplicar_arbol(c, deco, estado, animar)
		else:
			(deco["sprite"] as Sprite2D).visible = estado == Estado.SANO


## Seco: árbol muerto, tocón o nada (talado). Brotando: el árbol joven. Sano: el árbol adulto.
func _aplicar_arbol(c: Vector2i, deco: Dictionary, estado: Estado, animar: bool) -> void:
	var s: Sprite2D = deco["sprite"]
	var base: Vector2 = deco["escala"]
	var objetivo := base
	# El vaivén con el viento (GeneradorMapa.SHADER_VAIVEN) es solo para árboles vivos.
	if not deco.has("material"):
		deco["material"] = s.material
	s.material = null if estado == Estado.SECO else deco["material"]
	if estado == Estado.SECO:
		var seco := _sprite_seco(c)
		s.visible = seco != ""
		if seco != "":
			_cambiar_textura(s, load(GeneradorMapa.RUTA_DECORACION % seco))
		s.scale = base
		return
	var venia_seco: bool = s.texture != deco["textura"] or not s.visible
	s.visible = true
	if venia_seco:
		_cambiar_textura(s, deco["textura"])
	if estado == Estado.BROTANDO:
		objetivo = base * ESCALA_JOVEN
	if not animar:
		s.scale = objetivo
		return
	if venia_seco:
		s.scale = Vector2.ZERO
	var tween := s.create_tween()
	tween.tween_property(s, "scale", objetivo, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Qué queda de cada árbol en el paisaje degradado (fijo por parcela).
func _sprite_seco(c: Vector2i) -> String:
	var r := absf(GeneradorMapa._ruido(c.x * 7, c.y * 5, 31)) * 10.0
	r -= floorf(r)
	if id_bioma == 2:
		return "cardon_seco" if r < 0.55 else ("tocon" if r < 0.8 else "")
	if r < 0.4:
		return "arbol_seco_a"
	if r < 0.6:
		return "arbol_seco_b"
	if r < 0.85:
		return "tocon"
	return ""


func _cambiar_textura(s: Sprite2D, textura: Texture2D) -> void:
	s.texture = textura
	s.offset = Vector2(-textura.get_width() * 0.5, -textura.get_height())
	GeneradorMapa.ajustar_sombra(s)


# --- Caseta ----------------------------------------------------------------------------------

func _actualizar_caseta(animar: bool) -> void:
	if _caseta == null:
		return
	var avance: float = _salud / GameState.umbral_desbloqueo()
	var etapa := "caseta_abandonada"
	if avance >= CASETA_RESTAURADA:
		etapa = "caseta_restaurada"
	elif avance >= CASETA_REPARACION:
		etapa = "caseta_reparacion"
	if etapa == _etapa_caseta:
		return
	_etapa_caseta = etapa
	_cambiar_textura(_caseta, load(GeneradorMapa.RUTA_DECORACION % etapa))
	_humo_activo(etapa == "caseta_restaurada")
	if animar:
		# Pequeño salto al cambiar de etapa, para que el jugador note la mejora.
		_caseta.scale = Vector2(1.15, 0.85)
		var tween := _caseta.create_tween()
		tween.tween_property(_caseta, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _humo_activo(activo: bool) -> void:
	if _humo == null:
		if not activo:
			return
		_humo = CPUParticles2D.new()
		_humo.name = "Humo"
		_humo.position = CHIMENEA
		_humo.amount = 7
		_humo.lifetime = 3.2
		_humo.texture = _textura_humo()
		_humo.direction = Vector2(0.2, -1)
		_humo.spread = 12.0
		_humo.gravity = Vector2(5, -3)
		_humo.initial_velocity_min = 5.0
		_humo.initial_velocity_max = 8.0
		var tam := Curve.new()
		tam.add_point(Vector2(0, 0.5))
		tam.add_point(Vector2(1, 1.6))
		_humo.scale_amount_curve = tam
		var rampa := Gradient.new()
		rampa.set_color(0, Color(0.93, 0.92, 0.9, 0.75))
		rampa.set_color(1, Color(0.8, 0.8, 0.82, 0.0))
		_humo.color_ramp = rampa
		_humo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_caseta.add_child(_humo)
	_humo.emitting = activo


static func _textura_humo() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 6:
			var d := Vector2(x - 2.5, y - 2.5).length()
			if d <= 2.9:
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 2.0 else 0.6))
	return ImageTexture.create_from_image(img)


# --- Tileset degradado -----------------------------------------------------------------------

static var _texturas: Dictionary = {}  # "id_bioma:fuente" -> ImageTexture


func _agregar_fuentes(ts: TileSet) -> void:
	var original := (ts.get_source(0) as TileSetAtlasSource).texture
	for fuente in [FUENTE_SECA, FUENTE_BROTANDO]:
		if ts.has_source(fuente):
			continue
		var clave := "%d:%d" % [id_bioma, fuente]
		if not _texturas.has(clave):
			_texturas[clave] = ImageTexture.create_from_image(_degradar(original.get_image(), fuente == FUENTE_BROTANDO))
		ts.add_source(GeneradorMapa.crear_fuente(_texturas[clave]), fuente)


## Suelo: cada píxel toma el color de la rampa seca según su luminosidad. Agua: se enturbia.
## En "brotando" solo se seca la mitad de los píxeles, en manchas de 2x2 (se lee como pasto ralo).
func _degradar(img: Image, brotando: bool) -> Image:
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var rampa: Array = SUELO_SECO.get(id_bioma, SUELO_SECO[3]).map(func(h: String) -> Color: return Color(h))
	var ancho_baldosa := 64
	for y in img.get_height():
		for x in img.get_width():
			var col := x / ancho_baldosa
			var es_suelo := col in COLUMNAS_SUELO
			if not es_suelo and not (col in COLUMNAS_AGUA):
				continue
			var p := img.get_pixel(x, y)
			if p.a == 0.0:
				continue
			if brotando and _hash(x / 2, y / 2) < 0.5:
				continue
			var nuevo: Color
			if es_suelo:
				var l := clampf((p.get_luminance() - 0.12) / 0.6, 0.0, 0.999)
				nuevo = rampa[int(l * rampa.size())]
				# grietas: algunos píxeles oscuros sueltos sobre la cara superior
				if y < 32 and _hash(x, y + 97) < 0.04:
					nuevo = rampa[0]
			else:
				nuevo = p.lerp(COLOR_AGUA_TURBIA, 0.6)
			nuevo.a = p.a
			img.set_pixel(x, y, nuevo)
	return img


static func _hash(x: int, y: int) -> float:
	var v := (x * 374761393 + y * 668265263) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v % 1000) / 1000.0
