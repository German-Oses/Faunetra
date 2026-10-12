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
## - Además, todo el mundo pierde color con la salud baja (filtro de pantalla bajo el HUD).

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
const COLOR_AGUA_TURBIA := Color("#6B6450")
## Columnas del tileset que se degradan: suelo (0-2), agua (4-5) y suelo especial (6).
const COLUMNAS_SUELO: Array[int] = [0, 1, 2, 6]
const COLUMNAS_AGUA: Array[int] = [4, 5]

const SHADER_COLOR := """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float gris = dot(c, vec3(0.299, 0.587, 0.114));
	// Con poca vida: poca saturación, tono sepia apagado y algo más oscuro.
	vec3 apagado = mix(vec3(gris), c, 0.35) * vec3(1.0, 0.95, 0.86) * 0.93;
	COLOR = vec4(mix(apagado, c, vida), 1.0);
}
"""

var id_bioma := -1
var _capas: Array[TileMapLayer] = []
var _celdas: Array[Vector2i] = []
var _umbral: Dictionary = {}      # Vector2i -> salud (%) desde la que la parcela está sana
var _estado: Dictionary = {}      # Vector2i -> Estado mostrado
var _decoraciones: Dictionary = {}  # Vector2i -> Array[{sprite, tipo, textura, escala}]
var _pendientes: Array[Vector2i] = []
var _acumulado := 0.0
var _velocidad := CAMBIOS_POR_SEGUNDO
var _salud := 0.0
var _filtro: ShaderMaterial
var _tween_filtro: Tween


func configurar(p_id_bioma: int, tilemap: TileMapLayer, mapa: Dictionary) -> void:
	id_bioma = p_id_bioma
	_capas = [tilemap]
	_capas.append_array(mapa.get("capas", []))
	_agregar_fuentes(tilemap.tile_set)

	var r := GeneradorMapa.RADIO_JUGABLE
	var alcance := float(GeneradorMapa.RADIO_EXTERIOR - r)
	var meta := GameState.umbral_desbloqueo()
	for c: Vector2i in mapa.get("tipos", {}):
		var distancia := maxi(absi(c.x), absi(c.y)) - r
		if distancia <= 0:
			continue   # el refugio lo restaura el jugador parcela a parcela
		var t := clampf(distancia / alcance, 0.0, 1.0)
		var ruido := GeneradorMapa._ruido_suave(c.x, c.y, 17 * id_bioma) * 5.0 + GeneradorMapa._ruido(c.x, c.y, 3 * id_bioma) * 2.0
		_umbral[c] = clampf(lerpf(UMBRAL_MINIMO, meta - 1.0, t) + ruido, UMBRAL_MINIMO, meta - 1.0)
		_celdas.append(c)
	for item: Dictionary in mapa.get("paisaje", []):
		var s: Sprite2D = item["sprite"]
		var lista: Array = _decoraciones.get(item["celda"], [])
		lista.append({"sprite": s, "tipo": item["tipo"], "textura": s.texture, "escala": s.scale})
		_decoraciones[item["celda"]] = lista

	_crear_filtro()
	_salud = GameState.calcular_salud(id_bioma)
	# Al cargar, el paisaje aparece directamente en su estado (sin animar el avance).
	for c in _celdas:
		_aplicar(c, _estado_para(c, _salud), false)
	_filtro.set_shader_parameter("vida", _vida(_salud))
	GameState.salud_actualizada.connect(_on_salud)


func _on_salud(p_id_bioma: int, salud: float) -> void:
	if p_id_bioma != id_bioma or is_equal_approx(salud, _salud):
		return
	var subio := salud > _salud
	_salud = salud
	_pendientes.clear()
	for c in _celdas:
		if _estado_para(c, salud) != _estado[c]:
			_pendientes.append(c)
	# Lo verde avanza desde el refugio hacia afuera; la degradación, desde afuera hacia adentro.
	_pendientes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (_umbral[a] > _umbral[b]) if subio else (_umbral[a] < _umbral[b]))
	_velocidad = maxf(CAMBIOS_POR_SEGUNDO, _pendientes.size() / DURACION_AVANCE)
	if _tween_filtro:
		_tween_filtro.kill()
	_tween_filtro = create_tween()
	_tween_filtro.tween_method(func(v: float) -> void: _filtro.set_shader_parameter("vida", v),
		float(_filtro.get_shader_parameter("vida")), _vida(salud), 1.5)


func _process(delta: float) -> void:
	if _pendientes.is_empty():
		return
	_acumulado += delta * _velocidad
	while _acumulado >= 1.0 and not _pendientes.is_empty():
		_acumulado -= 1.0
		var c: Vector2i = _pendientes.pop_back()
		_aplicar(c, _estado_para(c, _salud), true)
	if _pendientes.is_empty():
		_acumulado = 0.0


func _estado_para(c: Vector2i, salud: float) -> Estado:
	var u: float = _umbral[c]
	if salud >= u:
		return Estado.SANO
	if salud >= u - MARGEN_BROTE:
		return Estado.BROTANDO
	return Estado.SECO


## Color del mundo: apagado al comenzar y pleno al llegar a la meta del bioma.
func _vida(salud: float) -> float:
	return smoothstep(0.0, 1.0, clampf(salud / GameState.umbral_desbloqueo(), 0.0, 1.0))


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


# --- Filtro de color -------------------------------------------------------------------------

## Capa de pantalla entre el mundo (capa 0) y el HUD (capa 1): solo afecta al paisaje.
func _crear_filtro() -> void:
	var capa := CanvasLayer.new()
	capa.name = "FiltroSalud"
	capa.layer = 0
	add_child(capa)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_COLOR
	_filtro = ShaderMaterial.new()
	_filtro.shader = shader
	rect.material = _filtro
	capa.add_child(rect)
