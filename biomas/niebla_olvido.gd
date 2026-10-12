class_name NieblaOlvido
extends Node2D

## La Niebla del Olvido sobre el refugio. En lugar de un rombo por parcela, se dibuja una sola
## capa con un shader:
## - Una máscara de una celda por parcela (1 = niebla) filtrada en forma bilineal da la forma
##   general; ruido animado deforma sus bordes, así la niebla tiene orillas suaves e irregulares
##   y se mueve lentamente.
## - Es algo translúcida, para que se adivine el terreno dormido debajo, y sube unos píxeles
##   sobre las parcelas para que tenga volumen.
## - Al disipar, cada parcela se desvanece con un retraso según su distancia al punto tocado:
##   la niebla se abre en círculo desde ahí.

const RELLENO := 2            ## Celdas vacías alrededor de la máscara, para que el borde se difumine.
const DURACION_DISIPAR := 0.7
const RETRASO_POR_CELDA := 0.12
## La niebla sube sobre las parcelas (px), como una capa con espesor.
const ALTURA := 14.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D mascara : filter_linear;
uniform vec2 celda_min;      // celda de la esquina (0, 0) de la máscara
uniform vec2 tam_mascara;
uniform vec2 centro_origen;  // posición local del centro de la celda (0, 0)
uniform float altura = 14.0;
uniform vec4 color_luz : source_color = vec4(0.93, 0.94, 0.97, 1.0);
uniform vec4 color_sombra : source_color = vec4(0.78, 0.80, 0.88, 1.0);
varying vec2 local;

void vertex() {
	local = VERTEX;
}

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x),
		mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

float densidad(vec2 p) {
	vec2 q = p - centro_origen;
	vec2 c = vec2(q.x / 32.0 + q.y / 16.0, q.y / 16.0 - q.x / 32.0) * 0.5;
	return texture(mascara, (c - celda_min + 0.5) / tam_mascara).r;
}

void fragment() {
	// Píxeles de 2x2 para que la niebla tenga la misma granularidad que el arte.
	vec2 p = floor(local / 2.0) * 2.0;
	float t = TIME;
	float d = max(densidad(p), densidad(p + vec2(0.0, altura)));
	float n = fbm(p * 0.018 + vec2(t * 0.035, t * 0.012));
	float n2 = fbm(p * 0.022 - vec2(t * 0.02, -t * 0.03) + 40.0);
	float forma = smoothstep(0.40, 0.66, d + (n - 0.5) * 0.6);
	float alfa = forma * mix(0.78, 0.94, n2);
	// Bancos de niebla suaves: casi todo claro, con sombras leves donde el ruido es bajo.
	vec3 col = mix(color_sombra.rgb, color_luz.rgb, smoothstep(0.25, 0.65, n2));
	COLOR = vec4(col, alfa);
}
"""

var _terreno: TerrenoRefugio
var _minimo := Vector2i.ZERO
var _tam := Vector2i.ONE
var _valores: Dictionary = {}     # Vector2i -> densidad mostrada 0..1
var _animando: Dictionary = {}    # Vector2i -> {"desde", "hasta", "t"} (t negativo = esperando)
var _imagen: Image
var _textura: ImageTexture
var _rect := Rect2()


func configurar(terreno: TerrenoRefugio) -> void:
	_terreno = terreno
	var celdas: Dictionary = terreno.celdas
	var a := Vector2i(1 << 20, 1 << 20)
	var b := -a
	for c: Vector2i in celdas:
		a = Vector2i(mini(a.x, c.x), mini(a.y, c.y))
		b = Vector2i(maxi(b.x, c.x), maxi(b.y, c.y))
	_minimo = a - Vector2i.ONE * RELLENO
	_tam = b - a + Vector2i.ONE * (RELLENO * 2 + 1)
	_imagen = Image.create(_tam.x, _tam.y, false, Image.FORMAT_L8)
	for c: Vector2i in celdas:
		_valores[c] = 1.0 if celdas[c]["n"] else 0.0
		_escribir(c)
	_borde_exterior()
	_textura = ImageTexture.create_from_image(_imagen)

	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("mascara", _textura)
	mat.set_shader_parameter("celda_min", Vector2(_minimo))
	mat.set_shader_parameter("tam_mascara", Vector2(_tam))
	mat.set_shader_parameter("centro_origen", terreno.tilemap.map_to_local(Vector2i.ZERO))
	mat.set_shader_parameter("altura", ALTURA)
	material = mat

	# Rectángulo que cubre el rombo de la máscara, más la altura de la niebla.
	var tilemap := terreno.tilemap
	var puntos: Array[Vector2] = []
	for esquina in [Vector2i(0, 0), Vector2i(_tam.x, 0), Vector2i(0, _tam.y), _tam]:
		puntos.append(tilemap.map_to_local(_minimo + esquina))
	_rect = Rect2(puntos[0], Vector2.ZERO)
	for p in puntos:
		_rect = _rect.expand(p)
	_rect = _rect.grow(48)
	queue_redraw()


## Sincroniza con el estado de las parcelas. Con `origen`, los cambios se animan en círculo desde ahí.
func refrescar(origen: Variant = null) -> void:
	for c: Vector2i in _terreno.celdas:
		var objetivo := 1.0 if _terreno.celdas[c]["n"] else 0.0
		var actual: float = _animando[c]["hasta"] if _animando.has(c) else _valores[c]
		if is_equal_approx(objetivo, actual):
			continue
		if origen == null:
			_animando.erase(c)
			_valores[c] = objetivo
			_escribir(c)
		else:
			var distancia := Vector2(c - (origen as Vector2i)).length()
			_animando[c] = {"desde": _valores[c], "hasta": objetivo, "t": -distancia * RETRASO_POR_CELDA}
	if origen == null:
		_textura.update(_imagen)


func _process(delta: float) -> void:
	if _animando.is_empty():
		return
	for c: Vector2i in _animando.keys():
		var a: Dictionary = _animando[c]
		a["t"] += delta / DURACION_DISIPAR
		if a["t"] <= 0.0:
			continue
		var t := minf(1.0, a["t"])
		_valores[c] = lerpf(a["desde"], a["hasta"], ease(t, 0.6))
		_escribir(c)
		if t >= 1.0:
			_animando.erase(c)
	_textura.update(_imagen)


## Fuera del refugio la niebla se deshilacha una o dos parcelas, para que su borde exterior no
## sea un rombo recto: cada celda del relleno toma una fracción de la vecina más densa.
func _borde_exterior() -> void:
	for anillo in RELLENO:
		var nuevos := {}
		for y in _tam.y:
			for x in _tam.x:
				var c := _minimo + Vector2i(x, y)
				if _terreno.celdas.has(c) or _imagen.get_pixel(x, y).r > 0.0:
					continue
				var vecina := 0.0
				for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + v
					if q.x >= 0 and q.y >= 0 and q.x < _tam.x and q.y < _tam.y:
						vecina = maxf(vecina, _imagen.get_pixel(q.x, q.y).r)
				if vecina > 0.0:
					nuevos[Vector2i(x, y)] = vecina * (0.62 if anillo == 0 else 0.4)
		for q: Vector2i in nuevos:
			_imagen.set_pixel(q.x, q.y, Color(nuevos[q], nuevos[q], nuevos[q]))


func _escribir(c: Vector2i) -> void:
	var p := c - _minimo
	_imagen.set_pixel(p.x, p.y, Color(_valores[c], _valores[c], _valores[c]))


func _draw() -> void:
	draw_rect(_rect, Color.WHITE)
