class_name EspecieLoader
extends RefCounted


const RUTA_DATOS := "res://data/especies/"
const ESCENA_ESPECIE := preload("res://entities/especies/especie.tscn")
const TIPOS_FLORA := ["planta", "hongo"]

static var _todas: Array[EspecieData] = []
static var _por_id: Dictionary = {}
static var _texturas: Dictionary = {}


## Carga (una sola vez) todas las fichas de especies, ordenadas por id.
static func cargar_todas() -> Array[EspecieData]:
	if not _todas.is_empty():
		return _todas
	var dir := DirAccess.open(RUTA_DATOS)
	if dir == null:
		push_error("No se pudo abrir la carpeta de especies: %s" % RUTA_DATOS)
		return _todas

	var vistos := {}
	for archivo in dir.get_files():
		# En builds exportados los recursos aparecen como ".tres.remap".
		var nombre := archivo.trim_suffix(".remap")
		if not nombre.ends_with(".tres") or vistos.has(nombre):
			continue
		vistos[nombre] = true
		var data := load(RUTA_DATOS + nombre) as EspecieData
		if data:
			_todas.append(data)
			_por_id[data.id_especie] = data
	_todas.sort_custom(func(a: EspecieData, b: EspecieData) -> bool: return a.id_especie < b.id_especie)
	return _todas


static func por_id(id_especie: int) -> EspecieData:
	cargar_todas()
	return _por_id.get(id_especie)


static func cargar_especies_del_bioma(id_bioma: int) -> Array[EspecieData]:
	var resultado: Array[EspecieData] = []
	for data in cargar_todas():
		if data.id_bioma == id_bioma:
			resultado.append(data)
	return resultado


static func es_flora(data: EspecieData) -> bool:
	return data.tipo in TIPOS_FLORA


static func flora_del_bioma(id_bioma: int) -> Array[EspecieData]:
	return cargar_especies_del_bioma(id_bioma).filter(func(d: EspecieData) -> bool: return es_flora(d))


## Flora que el jugador puede plantar (las especies extintas solo existen en la Biopedia).
static func flora_plantable(id_bioma: int) -> Array[EspecieData]:
	return flora_del_bioma(id_bioma).filter(func(d: EspecieData) -> bool: return d.estado_conservacion != "EX")


static func fauna_del_bioma(id_bioma: int) -> Array[EspecieData]:
	return cargar_especies_del_bioma(id_bioma).filter(func(d: EspecieData) -> bool: return not es_flora(d))


static func toda_la_fauna() -> Array[EspecieData]:
	return cargar_todas().filter(func(d: EspecieData) -> bool: return not es_flora(d))


## Imagen representativa: la textura de la ficha o el primer frame de su escena animada.
static func textura_de(data: EspecieData) -> Texture2D:
	if data.textura:
		return data.textura
	if _texturas.has(data.id_especie):
		return _texturas[data.id_especie]
	var tex: Texture2D = null
	if data.escena:
		var nodo := data.escena.instantiate()
		var sprite := nodo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite and sprite.sprite_frames:
			var anim: StringName = sprite.animation
			if not sprite.sprite_frames.has_animation(anim):
				var nombres := sprite.sprite_frames.get_animation_names()
				anim = StringName(nombres[0]) if not nombres.is_empty() else &""
			if anim != &"" and sprite.sprite_frames.get_frame_count(anim) > 0:
				tex = sprite.sprite_frames.get_frame_texture(anim, 0)
		nodo.free()
	_texturas[data.id_especie] = tex
	return tex


static func instanciar(data: EspecieData) -> especie:
	var escena: PackedScene = data.escena if data.escena else ESCENA_ESPECIE
	var instancia := escena.instantiate() as especie
	instancia.data = data
	return instancia


static func instanciar_especies(lista: Array[EspecieData], contenedor: Node2D, posiciones: Array[Vector2]) -> void:
	# Calculamos cuántas especies podemos instanciar como máximo (evita el out of bounds(que hayan especies que no pueden estar por tamaño)
	var cantidad_a_instanciar = min(lista.size(), posiciones.size())

	for i in cantidad_a_instanciar:
		var instancia := instanciar(lista[i])
		instancia.position = posiciones[i]
		contenedor.add_child(instancia)
