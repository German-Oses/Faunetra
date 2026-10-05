class_name GeneradorMapa
extends RefCounted

## Construye el mapa de cada bioma a partir de referencias de su paisaje real:
## - Norte Árido: laguna altiplánica rodeada de salar, volcanes nevados (tipo Licancabur).
## - Zona Central: estero que cruza el matorral, cerros con la cordillera detrás.
## - Bosques Templados: río valdiviano con puente, volcán cónico (tipo Osorno), troncos caídos.
## - Patagonia: lago turquesa y río, torres de granito (tipo Torres del Paine), nieve.
## - Territorios Insulares: océano y playa, volcán con cráter (tipo Rano Kau) y moáis.
## Todos tienen una caseta de guardaparque y un sendero que llega al claro inicial.
## Más allá del mapa base se extiende un anillo de paisaje (RADIO_EXTERIOR) con bosquecitos
## agrupados, para que el mundo llene la pantalla cuando la cámara está cerca. El agua se dibuja
## un escalón más abajo que el suelo, así las orillas muestran el canto de tierra.
##
## Usa coordenadas DIAMOND_DOWN: la celda (x, y) se dibuja en ((x - y) * 32, (x + y) * 16),
## así que "atrás" (arriba en pantalla) es x + y pequeño y "adelante" es x + y grande.

const VERSION := 2
const RADIO_MAPA := 13
const RADIO_JUGABLE := 8
## Paisaje decorativo alrededor del mapa base. Usa su propio generador aleatorio para no
## mover las rocas y el suelo especial del refugio en partidas guardadas.
const RADIO_EXTERIOR := RADIO_MAPA + 8
## Cuánto más abajo se dibuja la superficie del agua (px).
const DESNIVEL_AGUA := 8
## Biomas con agua dulce tranquila donde crecen nenúfares.
const BIOMAS_CON_NENUFARES: Array[int] = [1, 3, 4]
## Árboles nativos del paisaje, dos por bioma (arbol_<bioma>_a/b.png, 128x192 a la misma escala de
## píxel que las baldosas, generados con herramientas/aseprite/arboles_detallados.lua).
## La variante "a" es la más común.
const ARBOLES_PAISAJE := {
	1: ["arbol_1_a", "arbol_1_b"],  # Zona Central: quillay y espino
	2: ["arbol_2_a", "arbol_2_b"],  # Norte Árido: cardón adulto y joven
	3: ["arbol_3_a", "arbol_3_b"],  # Bosques del Sur: coigüe y alerce
	4: ["arbol_4_a", "arbol_4_b"],  # Patagonia: lenga y ñirre en otoño
	5: ["arbol_5_a", "arbol_5_b"],  # Islas (Juan Fernández): chonta y helecho arborescente
}
const PROPORCION_VARIANTE_A := 0.6

# Columnas del tileset Assets/tilesets/mapa_<id>.png (cada baldosa mide 64x48).
const SUELO: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const SENDERO := Vector2i(3, 0)
const AGUA := Vector2i(4, 0)           # animada: cuadros en las columnas 4 y 5
const ESPECIAL := Vector2i(6, 0)

## Tipos de parcela. Solo "suelo" y "especial" admiten plantas y bloqueadores.
const PLANTABLES: Array[String] = ["suelo", "especial"]
const NO_TRANSITABLES: Array[String] = ["agua", "caseta", "estructura"]
const SIN_NIEBLA: Array[String] = ["caseta", "sendero", "puente"]

const RUTA_DECORACION := "res://Assets/decoracion/%s.png"
const CASETA := Vector2i(2, -1)


## Genera el mapa sobre `tilemap` y coloca las decoraciones en `contenedor`.
## Devuelve {"zona": Array[Vector2i], "tipos": {Vector2i: String}, "decoraciones": {Vector2i: Node2D}}.
static func generar(id_bioma: int, tilemap: TileMapLayer, contenedor: Node2D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 * id_bioma + VERSION
	contenedor.y_sort_enabled = true
	tilemap.tile_set = _crear_tileset(id_bioma)
	tilemap.clear()

	var tipos: Dictionary = {}
	var zona: Array[Vector2i] = []
	for y in range(-RADIO_MAPA, RADIO_MAPA + 1):
		for x in range(-RADIO_MAPA, RADIO_MAPA + 1):
			var c := Vector2i(x, y)
			tipos[c] = "suelo"
			if absi(x) <= RADIO_JUGABLE and absi(y) <= RADIO_JUGABLE:
				zona.append(c)

	_agua_y_suelo_especial(id_bioma, tipos, rng, RADIO_MAPA)
	_sendero(tipos)

	var rng_exterior := RandomNumberGenerator.new()
	rng_exterior.seed = rng.seed + 1
	var exterior: Dictionary = {}
	for y in range(-RADIO_EXTERIOR, RADIO_EXTERIOR + 1):
		for x in range(-RADIO_EXTERIOR, RADIO_EXTERIOR + 1):
			if maxi(absi(x), absi(y)) > RADIO_MAPA:
				exterior[Vector2i(x, y)] = "suelo"
	_agua_y_suelo_especial(id_bioma, exterior, rng_exterior, RADIO_EXTERIOR)
	for y in range(RADIO_MAPA + 1, RADIO_EXTERIOR + 1):
		var c := Vector2i(-1, y)
		exterior[c] = "puente" if exterior.get(c) == "agua" else "sendero"
	tipos.merge(exterior)

	# Baldosas
	for c in tipos:
		match tipos[c]:
			"agua":
				tilemap.set_cell(c, 0, AGUA)
			"sendero", "puente", "caseta":
				tilemap.set_cell(c, 0, SENDERO)
			"especial":
				tilemap.set_cell(c, 0, ESPECIAL)
			_:
				var r := (rng_exterior if exterior.has(c) else rng).randf()
				tilemap.set_cell(c, 0, SUELO[0] if r < 0.7 else (SUELO[1] if r < 0.88 else SUELO[2]))

	var decoraciones := _decorar(id_bioma, tilemap, contenedor, tipos, rng, rng_exterior)
	return {"zona": zona, "tipos": tipos, "decoraciones": decoraciones}


static func _crear_tileset(id_bioma: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = load("res://Assets/tilesets/mapa_%d.png" % id_bioma)
	fuente.texture_region_size = Vector2i(64, 48)
	ts.add_source(fuente, 0)
	for coords in [SUELO[0], SUELO[1], SUELO[2], SENDERO, AGUA, ESPECIAL]:
		fuente.create_tile(coords)
		fuente.get_tile_data(coords, 0).texture_origin = Vector2i(0, -8 - (DESNIVEL_AGUA if coords == AGUA else 0))
	fuente.set_tile_animation_frames_count(AGUA, 2)
	fuente.set_tile_animation_frame_duration(AGUA, 0, 0.7)
	fuente.set_tile_animation_frame_duration(AGUA, 1, 0.7)
	return ts


static func _ruido(x: int, y: int, semilla: int) -> float:
	return sin(x * 0.61 + semilla) * 0.5 + sin(y * 0.47 + semilla * 1.7) * 0.5 + sin((x + y) * 0.29 + semilla * 0.3) * 0.4


## `radio`: extensión del área a recorrer (los ríos cruzan de borde a borde).
static func _agua_y_suelo_especial(id_bioma: int, tipos: Dictionary, rng: RandomNumberGenerator, radio: int) -> void:
	match id_bioma:
		2:  # Laguna altiplánica con salar alrededor
			for c in tipos:
				var d := pow((c.x - 6) / 3.6, 2) + pow((c.y + 5) / 2.6, 2)
				if d <= 1.0:
					tipos[c] = "agua"
				elif d <= 2.6:
					tipos[c] = "especial"
		3:  # Río valdiviano de dos parcelas de ancho y claros de musgo
			_manchas(tipos, 3, rng)
			_rio(tipos, func(x: int) -> float: return 4.0 + 2.0 * sin(x / 3.5), 2, radio)
		1:  # Estero angosto y manchas de tierra seca
			_manchas(tipos, 1, rng)
			_rio(tipos, func(x: int) -> float: return 5.0 + 2.0 * sin(x / 3.0), 1, radio)
		4:  # Lago turquesa al fondo, río que baja y nieve en las partes altas
			for c in tipos:
				var d := pow((c.x - 5) / 4.2, 2) + pow((c.y + 6) / 3.2, 2)
				if d <= 1.0:
					tipos[c] = "agua"
				elif c.x + c.y < -17:
					tipos[c] = "especial"
			_manchas(tipos, 4, rng)
			# río que baja desde el lago hacia el frente
			var previo := 5
			for y in range(-3, radio + 1):
				var x := roundi(5.0 + 1.5 * sin(y / 2.5))
				for xx in range(mini(previo, x), maxi(previo, x) + 1):
					if tipos.has(Vector2i(xx, y)):
						tipos[Vector2i(xx, y)] = "agua"
				previo = x
		5:  # Océano a la derecha, playa de arena en la costa
			for c in tipos:
				var costa := 9 + roundi(sin(c.y / 3.0) * 1.2)
				if c.x >= costa:
					tipos[c] = "agua"
				elif c.x >= costa - 1:
					tipos[c] = "especial"


## Manchas pequeñas e irregulares de suelo especial (musgo, tierra seca, nieve).
static func _manchas(tipos: Dictionary, semilla: int, rng: RandomNumberGenerator) -> void:
	for c in tipos:
		if tipos[c] == "suelo" and _ruido(c.x, c.y, semilla) > 0.95 and rng.randf() < 0.6:
			tipos[c] = "especial"


## Curso de agua continuo que cruza el mapa de izquierda a derecha (fila y = curva(x)).
static func _rio(tipos: Dictionary, curva: Callable, ancho: int, radio: int) -> void:
	var previo := roundi(curva.call(-radio))
	for x in range(-radio, radio + 1):
		var y := roundi(curva.call(x))
		for yy in range(mini(previo, y), maxi(previo, y) + ancho):
			var c := Vector2i(x, yy)
			if tipos.has(c):
				tipos[c] = "agua"
		previo = y


## Sendero desde el borde delantero hasta el claro, pasando junto a la caseta;
## si cruza agua se convierte en puente.
static func _sendero(tipos: Dictionary) -> void:
	var camino: Array[Vector2i] = [Vector2i(2, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 2)]
	for y in range(3, RADIO_MAPA + 1):
		camino.append(Vector2i(-1, y))
	for c in camino:
		tipos[c] = "puente" if tipos.get(c) == "agua" else "sendero"
	tipos[CASETA] = "caseta"


static func _decorar(id_bioma: int, tilemap: TileMapLayer, contenedor: Node2D, tipos: Dictionary,
		rng: RandomNumberGenerator, rng_exterior: RandomNumberGenerator) -> Dictionary:
	var decoraciones: Dictionary = {}
	var ocupadas: Dictionary = {}

	# Cordillera de fondo: montañas grandes a lo largo de los dos bordes traseros del paisaje,
	# para enmarcarlo. Antes se ubicaban en el borde del mapa base y usaban `rng`: consumimos
	# los mismos números para que las rocas del refugio queden donde estaban en partidas guardadas.
	var montanas_antes := 3 if id_bioma == 5 else 11
	for i in montanas_antes * 2:
		rng.randf()
	var fondo := RADIO_EXTERIOR + 2
	var puestos: Array[Vector2i] = []
	for k in range(-RADIO_EXTERIOR + 2, RADIO_EXTERIOR + 1, 6):
		puestos.append(Vector2i(-fondo, k))
		puestos.append(Vector2i(k, -fondo))
	puestos.append(Vector2i(-fondo, -fondo))
	if id_bioma == 5:
		# Una isla: pocos volcanes y océano alrededor.
		puestos = [Vector2i(-fondo, -fondo), Vector2i(-fondo, 6), Vector2i(6, -fondo)]
	for c in puestos:
		var cerca := absi(c.x + c.y) < 14
		_sprite(contenedor, tilemap, "montana_%d" % id_bioma, c, Vector2(rng_exterior.randf_range(-20, 20), 40),
			rng_exterior.randf_range(2.4, 2.9) if cerca else rng_exterior.randf_range(1.9, 2.3))

	# Caseta del guardaparque y cartel del sendero
	decoraciones[CASETA] = _sprite(contenedor, tilemap, "caseta", CASETA, Vector2(0, 10))
	_sombra(decoraciones[CASETA])
	var cartel := Vector2i(-2, 5)
	if tipos.get(cartel) == "suelo":
		tipos[cartel] = "estructura"
		decoraciones[cartel] = _sprite(contenedor, tilemap, "cartel", cartel, Vector2(0, 2))
	for c in tipos:
		if tipos[c] == "puente":
			decoraciones[c] = _sprite(contenedor, tilemap, "puente", c, Vector2(0, 14))

	# Moáis mirando hacia la isla, junto a la costa
	if id_bioma == 5:
		for y in [-6, -3, 0]:
			var c := Vector2i(7, y)
			if tipos.get(c) in PLANTABLES:
				tipos[c] = "estructura"
				decoraciones[c] = _sprite(contenedor, tilemap, "moai", c, Vector2(0, 4))
				_sombra(decoraciones[c])

	# Rocas y troncos dentro del refugio (no se pueden plantar ni limpiar)
	var dentro := 0
	for c in tipos:
		if dentro >= 5 or ocupadas.has(c):
			continue
		var en_zona := absi(c.x) <= RADIO_JUGABLE and absi(c.y) <= RADIO_JUGABLE
		var lejos_del_centro := maxi(absi(c.x), absi(c.y)) >= 4
		if en_zona and lejos_del_centro and tipos[c] == "suelo" and rng.randf() < 0.02:
			tipos[c] = "estructura"
			var pieza := "tronco" if (id_bioma == 3 and dentro % 2 == 0) else "roca_%d" % id_bioma
			decoraciones[c] = _sprite(contenedor, tilemap, pieza, c, Vector2(0, 6))
			_sombra(decoraciones[c])
			dentro += 1

	# Borde del mundo: bosquecitos del árbol típico del bioma, agrupados con ruido y con
	# claros entre ellos, más rocas sueltas. Nunca dentro de la zona jugable.
	var densidad := {1: 0.5, 2: 0.12, 3: 0.75, 4: 0.55, 5: 0.45}
	for c in tipos:
		if absi(c.x) <= RADIO_JUGABLE and absi(c.y) <= RADIO_JUGABLE:
			continue
		if ocupadas.has(c) or not (tipos[c] in PLANTABLES):
			continue
		if _taparia_el_refugio(c):
			continue
		var bosque := smoothstep(-0.3, 0.7, _ruido(c.x, c.y, 11 * id_bioma + 3))
		var r := rng_exterior.randf()
		if r < lerpf(0.03, densidad.get(id_bioma, 0.5), bosque):
			var especies: Array = ARBOLES_PAISAJE.get(id_bioma, ARBOLES_PAISAJE[3])
			var nombre: String = especies[0] if rng_exterior.randf() < PROPORCION_VARIANTE_A else especies[1]
			# Un árbol alto tapa más filas detrás de él: el margen depende de lo que mide su dibujo.
			if _taparia_el_refugio(c, ceili(_alto_visible(nombre) / 32.0)):
				continue
			var arbol := _sprite(contenedor, tilemap, nombre, c,
				Vector2(rng_exterior.randi_range(-8, 8), rng_exterior.randi_range(2, 10)))
			arbol.flip_h = rng_exterior.randf() < 0.5
			_sombra(arbol)
		elif r > 0.97:
			_sombra(_sprite(contenedor, tilemap, "roca_%d" % id_bioma, c, Vector2(0, 6)))
		elif id_bioma == 3 and r > 0.94:
			_sombra(_sprite(contenedor, tilemap, "tronco", c, Vector2(0, 6)))

	_plantas_de_agua(id_bioma, tilemap, contenedor, tipos, rng_exterior)
	return decoraciones


## Un adorno alto tapa las parcelas que quedan detrás de él (`filas` hacia arriba en pantalla, cada
## una de 32 px): no se pone donde ocultaría la zona jugable.
static func _taparia_el_refugio(c: Vector2i, filas := 3) -> bool:
	for dy in filas:
		for dx in filas:
			if absi(c.x - dx) <= RADIO_JUGABLE and absi(c.y - dy) <= RADIO_JUGABLE:
				return true
	return false


## Nenúfares en el agua dulce y juncos en las orillas, fuera de la zona jugable
## (dentro quedarían por encima de la Niebla del Olvido).
static func _plantas_de_agua(id_bioma: int, tilemap: TileMapLayer, contenedor: Node2D, tipos: Dictionary,
		rng: RandomNumberGenerator) -> void:
	if id_bioma == 5:
		return
	var vecinas: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in tipos:
		if tipos[c] != "agua" or (absi(c.x) <= RADIO_JUGABLE and absi(c.y) <= RADIO_JUGABLE):
			continue
		var orilla := false
		for v in vecinas:
			if tipos.get(c + v, "agua") != "agua":
				orilla = true
		var r := rng.randf()
		var desfase := Vector2(rng.randi_range(-12, 12), DESNIVEL_AGUA + rng.randi_range(-3, 4))
		if orilla and r < 0.3:
			_sprite(contenedor, tilemap, "juncos", c, desfase).flip_h = rng.randf() < 0.5
		elif id_bioma in BIOMAS_CON_NENUFARES and r > 0.86:
			var hoja := _sprite(contenedor, tilemap, "nenufar", c, desfase + Vector2(0, 4))
			hoja.z_index = -1


## Coloca una decoración apoyada sobre la parcela (su base inferior en el centro de la celda).
static func _sprite(contenedor: Node2D, tilemap: TileMapLayer, nombre: String, celda: Vector2i,
		desfase: Vector2 = Vector2.ZERO, escala: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Deco_%s_%d_%d" % [nombre, celda.x, celda.y]
	s.texture = load(RUTA_DECORACION % nombre)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height())
	s.scale = Vector2.ONE * escala
	contenedor.add_child(s)
	s.global_position = tilemap.to_global(tilemap.map_to_local(celda)) + desfase
	return s


static var _textura_sombra: Texture2D
static var _ancho_visible: Dictionary = {}  # ruta de textura -> ancho de la parte dibujada (px)
static var _altos_visibles: Dictionary = {}  # nombre de decoración -> alto de la parte dibujada (px)


static func _alto_visible(nombre: String) -> int:
	if not _altos_visibles.has(nombre):
		var tex: Texture2D = load(RUTA_DECORACION % nombre)
		_altos_visibles[nombre] = tex.get_image().get_used_rect().size.y
	return _altos_visibles[nombre]

## Sombra ovalada bajo una decoración, corrida hacia la derecha (la luz viene de arriba a la izquierda).
static func _sombra(s: Sprite2D) -> void:
	if _textura_sombra == null:
		var img := Image.create(32, 10, false, Image.FORMAT_RGBA8)
		for y in 10:
			for x in 32:
				var d := pow((x - 15.5) / 16.0, 2) + pow((y - 4.5) / 5.0, 2)
				if d <= 1.0:
					img.set_pixel(x, y, Color(0.04, 0.1, 0.06, 0.32 if d < 0.55 else 0.2))
		_textura_sombra = ImageTexture.create_from_image(img)
	var sombra := Sprite2D.new()
	sombra.texture = _textura_sombra
	sombra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sombra.show_behind_parent = true
	# La sombra es hija del sprite (hereda su escala) y se ajusta al ancho de lo dibujado, no del lienzo:
	# un cardón angosto no lleva la sombra de un árbol frondoso.
	var ruta := s.texture.resource_path
	if not _ancho_visible.has(ruta):
		_ancho_visible[ruta] = s.texture.get_image().get_used_rect().size.x
	sombra.scale = Vector2(maxf(12.0, _ancho_visible[ruta] * 0.9) / 28.0, 1.0)
	sombra.position = Vector2(4, -3)
	s.add_child(sombra)
