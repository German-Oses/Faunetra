extends Node

const BASE_URL := "https://tu-proyecto.supabase.co"
const API_KEY := "tu-anon-key-aqui"

@onready var http_request: HTTPRequest = $HTTPRequest


func especie_data_desde_json(json: Dictionary) -> EspecieData:
	var data := EspecieData.new()
	data.id_especie = json.get("id_especie")
	data.nombre_cientifico = json.get("nombre_cientifico")
	data.nombre_comun = json.get("nombre_comun")
	data.tipo = json.get("tipo")
	data.estado_conservacion = json.get("estado_conservacion")
	data.umbral_desbloqueo = json.get("umbral_desbloqueo", 0)
	data.id_bioma = json.get("id_bioma")
	return data


func cargar_especies_del_bioma_remoto(id_bioma: int) -> Array[EspecieData]:
	var respuesta := await _get("/rest/v1/especie?id_bioma=eq.%d" % id_bioma)
	var resultado: Array[EspecieData] = []
	for fila in respuesta:
		resultado.append(especie_data_desde_json(fila))
	return resultado
