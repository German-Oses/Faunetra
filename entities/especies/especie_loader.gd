class_name EspecieLoader
extends RefCounted


const RUTA_DATOS := "res://entities/especies/"
const ESCENA_ESPECIE := preload("res://entities/especies/especie.tscn")

static func cargar_especies_del_bioma(id_bioma: int) -> Array[EspecieData]:
	var resultado: Array[EspecieData] = []
	var dir := DirAccess.open(RUTA_DATOS)
	if dir == null:
		push_error("No se pudo abrir la carpeta de especies: %s" % RUTA_DATOS)
		return resultado

	for archivo in dir.get_files():
		if archivo.ends_with(".tres"):
			var data: EspecieData = load(RUTA_DATOS + archivo)
			if data.id_bioma == id_bioma:
				resultado.append(data)
	return resultado


static func instanciar_especies(lista: Array[EspecieData], contenedor: Node2D, posiciones: Array[Vector2]) -> void:
	for i in lista.size():
		var instancia := ESCENA_ESPECIE.instantiate() as especie
		instancia.data = lista[i]
		instancia.position = posiciones[i]
		contenedor.add_child(instancia)
