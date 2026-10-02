class_name GeneradorMapa
extends RefCounted

## Construye el mapa de cada bioma a partir de referencias de su paisaje real:
## - Norte Árido: laguna altiplánica rodeada de salar, volcanes nevados (tipo Licancabur).
## - Zona Central: estero que cruza el matorral, cerros con la cordillera detrás.
## - Bosques Templados: río valdiviano con puente, volcán cónico (tipo Osorno), troncos caídos.
## - Patagonia: lago turquesa y río, torres de granito (tipo Torres del Paine), nieve.
## - Territorios Insulares: océano y playa, volcán con cráter (tipo Rano Kau) y moáis.
## Todos tienen una caseta de guardaparque y un sendero que llega al claro inicial.
##
## Usa coordenadas DIAMOND_DOWN: la celda (x, y) se dibuja en ((x - y) * 32, (x + y) * 16),
## así que "atrás" (arriba en pantalla) es x + y pequeño y "adelante" es x + y grande.

const VERSION := 2
const RADIO_MAPA := 13
const RADIO_JUGABLE := 8

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

	_agua_y_suelo_especial(id_bioma, tipos, rng)
	_sendero(tipos)

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
				var r := rng.randf()
				tilemap.set_cell(c, 0, SUELO[0] if r < 0.7 else (SUELO[1] if r < 0.88 else SUELO[2]))

	var decoraciones := _decorar(id_bioma, tilemap, contenedor, tipos, rng)
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
		fuente.get_tile_data(coords, 0).texture_origin = Vector2i(0, -8)
	fuente.set_tile_animation_frames_count(AGUA, 2)
	fuente.set_tile_animation_frame_duration(AGUA, 0, 0.7)
	fuente.set_tile_animation_frame_duration(AGUA, 1, 0.7)
	return ts


static func _ruido(x: int, y: int, semilla: int) -> float:
	return sin(x * 0.61 + semilla) * 0.5 + sin(y * 0.47 + semilla * 1.7) * 0.5 + sin((x + y) * 0.29 + semilla * 0.3) * 0.4


static func _agua_y_suelo_especial(id_bioma: int, tipos: Dictionary, rng: RandomNumberGenerator) -> void:
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
			_rio(tipos, func(x: int) -> float: return 4.0 + 2.0 * sin(x / 3.5), 2)
		1:  # Estero angosto y manchas de tierra seca
			_manchas(tipos, 1, rng)
			_rio(tipos, func(x: int) -> float: return 5.0 + 2.0 * sin(x / 3.0), 1)
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
			for y in range(-3, RADIO_MAPA + 1):
				var x := roundi(5.0 + 1.5 * sin(y / 2.5))
				for xx in range(mini(previo, x), maxi(previo, x) + 1):
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
static func _rio(tipos: Dictionary, curva: Callable, ancho: int) -> void:
	var previo := roundi(curva.call(-RADIO_MAPA))
	for x in range(-RADIO_MAPA, RADIO_MAPA + 1):
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
		rng: RandomNumberGenerator) -> Dictionary:
	var decoraciones: Dictionary = {}
	var ocupadas: Dictionary = {}

	# Cordillera de fondo: montañas grandes a lo largo de los dos bordes traseros del mapa,
	# más allá de las parcelas, para enmarcar el paisaje.
	var fondo := RADIO_MAPA + 2
	var puestos: Array[Vector2i] = []
	for k in range(-RADIO_MAPA + 2, RADIO_MAPA + 1, 6):
		puestos.append(Vector2i(-fondo, k))
		puestos.append(Vector2i(k, -fondo))
	puestos.append(Vector2i(-fondo, -fondo))
	if id_bioma == 5:
		# Una isla: pocos volcanes y océano alrededor.
		puestos = [Vector2i(-fondo, -fondo), Vector2i(-fondo, 4), Vector2i(-4, -fondo)]
	for c in puestos:
		var cerca := absi(c.x + c.y) < 10
		_sprite(contenedor, tilemap, "montana_%d" % id_bioma, c, Vector2(rng.randf_range(-20, 20), 40),
			rng.randf_range(2.4, 2.9) if cerca else rng.randf_range(1.9, 2.3))

	# Caseta del guardaparque y cartel del sendero
	decoraciones[CASETA] = _sprite(contenedor, tilemap, "caseta", CASETA, Vector2(0, 10))
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
			dentro += 1

	# Borde del mundo: árboles típicos del bioma y rocas, fuera de la zona jugable
	var densidad := {1: 0.3, 2: 0.14, 3: 0.45, 4: 0.3, 5: 0.25}
	for c in tipos:
		if absi(c.x) <= RADIO_JUGABLE and absi(c.y) <= RADIO_JUGABLE:
			continue
		if ocupadas.has(c) or not (tipos[c] in PLANTABLES):
			continue
		var r := rng.randf()
		if r < densidad.get(id_bioma, 0.3):
			_sprite(contenedor, tilemap, "arbol_%d" % id_bioma, c, Vector2(rng.randf_range(-6, 6), 6), rng.randf_range(0.85, 1.15))
		elif r < densidad.get(id_bioma, 0.3) + 0.05:
			_sprite(contenedor, tilemap, "roca_%d" % id_bioma, c, Vector2(0, 6))
		elif id_bioma == 3 and r < densidad[3] + 0.08:
			_sprite(contenedor, tilemap, "tronco", c, Vector2(0, 6))
	return decoraciones


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
