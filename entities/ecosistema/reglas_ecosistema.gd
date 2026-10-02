class_name ReglasEcosistema
extends RefCounted

## Reglas del ecosistema leídas desde data/ecosistema/reglas_ecosistema.json:
## costos en PR, bloqueadores ambientales por bioma, sinergias de adyacencia y
## combinaciones de flora que atraen a cada especie de fauna.
## Las especies se referencian por su nombre común (sin importar tildes ni mayúsculas);
## una regla que nombra una especie inexistente simplemente se ignora.

const RUTA := "res://data/ecosistema/reglas_ecosistema.json"
const COSTO_NIEBLA_DEFECTO := 20
const COSTO_SANAR_DEFECTO := 15
const COSTO_PLANTAR_DEFECTO := 30

static var _datos: Dictionary = {}


static func datos() -> Dictionary:
	if _datos.is_empty():
		var json = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
		if json is Dictionary:
			_datos = json
		else:
			push_error("[ReglasEcosistema] No se pudo leer %s" % RUTA)
	return _datos


static func normalizar(texto: String) -> String:
	var t := texto.to_lower().strip_edges()
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		t = t.replace(par[0], par[1])
	return t


static func costo_niebla() -> int:
	return int(datos().get("costos", {}).get("niebla", COSTO_NIEBLA_DEFECTO))


static func costo_sanar() -> int:
	return int(datos().get("costos", {}).get("sanar", COSTO_SANAR_DEFECTO))


## Plantar especies más amenazadas cuesta más: su reintroducción es más delicada.
static func costo_plantar(data: EspecieData) -> int:
	var tabla: Dictionary = datos().get("costo_plantar_por_estado", {})
	return int(tabla.get(data.estado_conservacion, COSTO_PLANTAR_DEFECTO))


static func bloqueadores_del_bioma(id_bioma: int) -> Array:
	var todos: Dictionary = datos().get("bloqueadores", {})
	return todos.get(str(id_bioma), todos.get("default", []))


static func bloqueador(id_bioma: int, id_bloqueo: String) -> Dictionary:
	for b in bloqueadores_del_bioma(id_bioma):
		if str(b["id"]) == id_bloqueo:
			return b
	return {"id": id_bloqueo, "nombre": "Bloqueador ambiental", "forma": "basura", "costo": 35, "color": "#7d6b55"}


## Bonificación de crecimiento que `fuente` aporta a un `objetivo` adyacente.
## Devuelve {} si no hay sinergia (misma especie: los monocultivos no se potencian).
static func sinergia(fuente: EspecieData, objetivo: EspecieData) -> Dictionary:
	if fuente.id_especie == objetivo.id_especie:
		return {}
	var n_fuente := normalizar(fuente.nombre_comun)
	var n_objetivo := normalizar(objetivo.nombre_comun)
	for s in datos().get("sinergias", []):
		if normalizar(str(s["fuente"])) == n_fuente and normalizar(str(s["objetivo"])) == n_objetivo:
			return {"bono": float(s.get("bono", 0.2)), "nombre": str(s.get("nombre", "Sinergia")), "explicita": true}
	return {"bono": float(datos().get("bono_biodiversidad", 0.1)), "nombre": "Biodiversidad", "explicita": false}


## Descripciones de las sinergias explícitas en que participa una planta (para la Biopedia).
static func descripciones_sinergias(data: EspecieData) -> Array[String]:
	var resultado: Array[String] = []
	var n := normalizar(data.nombre_comun)
	for s in datos().get("sinergias", []):
		var bono := int(round(float(s.get("bono", 0.2)) * 100.0))
		if normalizar(str(s["fuente"])) == n:
			resultado.append("Genera «%s»: +%d%% de crecimiento a %s adyacente." % [s.get("nombre", "Sinergia"), bono, s["objetivo"]])
		elif normalizar(str(s["objetivo"])) == n:
			resultado.append("Crece +%d%% junto a %s («%s»)." % [bono, s["fuente"], s.get("nombre", "Sinergia")])
	return resultado


## Requisitos para que un animal visite el refugio:
## {"plantas": nombres de flora que deben estar sanas, "min_sanas": int, "min_salud": float}
static func requisitos_fauna(animal: EspecieData) -> Dictionary:
	var flora := EspecieLoader.flora_plantable(animal.id_bioma)
	var nombres_flora := {}
	for f in flora:
		nombres_flora[normalizar(f.nombre_comun)] = f.nombre_comun

	var n_animal := normalizar(animal.nombre_comun)
	for regla in datos().get("atracciones", []):
		if normalizar(str(regla["animal"])) != n_animal:
			continue
		var plantas: Array[String] = []
		for nombre in regla.get("requiere", []):
			var clave := normalizar(str(nombre))
			if nombres_flora.has(clave):
				plantas.append(nombres_flora[clave])
		if not plantas.is_empty():
			var min_salud := maxf(float(animal.umbral_desbloqueo), float(regla.get("min_salud", 0.0)))
			return {"plantas": plantas, "min_sanas": plantas.size(), "min_salud": min_salud}

	# Regla general: cada animal del bioma exige un refugio un poco más sano que el anterior.
	var fauna := EspecieLoader.fauna_del_bioma(animal.id_bioma)
	var indice := maxi(0, fauna.find(animal))
	var min_sanas := 0 if flora.is_empty() else 2 + indice
	var min_salud := maxf(float(animal.umbral_desbloqueo), minf(60.0, 8.0 * (indice + 1)))
	var sin_plantas: Array[String] = []
	return {"plantas": sin_plantas, "min_sanas": min_sanas, "min_salud": min_salud}


static func texto_requisitos(animal: EspecieData) -> String:
	var req := requisitos_fauna(animal)
	var plantas: Array = req["plantas"]
	var texto := ""
	if not plantas.is_empty():
		texto = "Llegará cuando en el refugio crezcan sanas: %s" % ", ".join(PackedStringArray(plantas))
	else:
		texto = "Llegará cuando haya %d plantas nativas sanas" % int(req["min_sanas"])
	if float(req["min_salud"]) > 0.0:
		texto += " y el bioma tenga al menos %d%% de salud" % int(req["min_salud"])
	return texto + "."
