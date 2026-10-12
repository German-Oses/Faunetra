class_name TerrenoRefugio
extends Node2D

## Grilla interactiva del refugio, montada sobre el TileMapLayer isométrico del bioma.
## Cada parcela puede estar cubierta por la Niebla del Olvido, ocupada por un bloqueador
## ambiental (basura o especie exótica invasora), libre o con una planta nativa que crece,
## recibe sinergias de sus vecinas y puede marchitarse. La flora sana atrae fauna pasivamente.
## El estado de cada parcela vive en GameState, así que se guarda entre sesiones.

const RADIO_CLARO_INICIAL := 2.0      ## Claro sin niebla alrededor del centro al comenzar.
const RADIO_DISIPAR := 1.0            ## Parcelas que despeja cada uso de «Disipar» (3x3).
## En mapas más grandes que esto, el refugio jugable se limita a RADIO_REFUGIO alrededor del centro;
## el resto del mapa se muestra como bosque profundo sin explorar.
const CELDAS_MAPA_GRANDE := 600
const RADIO_REFUGIO := 6.0
const PROPORCION_BLOQUEADORES := 0.06
const MAX_BLOQUEADORES := 18
const BLOQUEADORES_EN_CLARO := 2
const INTERVALO_EVALUACION := 1.0

const COLOR_AURA := Color(0.35, 0.65, 1.0, 0.28)
const COLOR_MARCHITA := Color(0.45, 0.3, 0.1, 0.4)
const COLOR_VALIDO := Color(0.45, 1.0, 0.55)
const COLOR_INVALIDO := Color(1.0, 0.45, 0.35)
const ESCALA_FAUNA := 0.7
## Velocidad de paseo (px/s) según la animación de movimiento de cada animal.
const VELOCIDAD_POR_ANIMACION := {&"walk": 18.0, &"hop": 24.0, &"fly": 42.0, &"swim": 22.0}
const ANIMACIONES_MOVIMIENTO: Array[StringName] = [&"fly", &"swim", &"hop", &"walk"]
const RADIO_AGUA_NADADORES := 4  ## Los nadadores usan el agua hasta esta distancia del refugio.
const RADIO_PASEO := 3.0              ## Parcelas a las que se aleja un animal en cada paseo.
const ALTURA_VUELO := 14.0  ## Las escenas animadas están pensadas para verse solas; en la grilla se achican.
const COLOR_FUERA_REFUGIO := Color(0.03, 0.1, 0.05, 0.6)

var id_bioma := -1
var tilemap: TileMapLayer
var contenedor: Node2D
var estado: Dictionary
var celdas: Dictionary = {}         # Vector2i -> Dictionary {n, b, e, c, m} (referencia al guardado)

var _nodos_plantas: Dictionary = {}  # Vector2i -> especie
var _nodos_fauna: Dictionary = {}    # id_especie -> especie
var _paseos: Dictionary = {}         # id_especie -> estado del paseo (ver _iniciar_paseo)
var _auras: Dictionary = {}          # Vector2i -> nombre de la sinergia explícita que recibe
var _celda_hover := Vector2i.ZERO
var _hay_hover := false
var _presionado := false
var _acumulador := 0.0
var _tiempo := 0.0
var _centro := Vector2i.ZERO
var _zona: Array[Vector2i] = []       # Parcelas jugables del refugio
var _tipos: Dictionary = {}           # Vector2i -> tipo de parcela del GeneradorMapa ("suelo", "agua"...)
var _decoraciones: Dictionary = {}    # Vector2i -> Node2D decorativo dentro del refugio
var _niebla: NieblaOlvido
var _cursor: Node2D                    # contorno de la parcela bajo el puntero, sobre la niebla


## `mapa` es el resultado de GeneradorMapa.generar(); si viene vacío se usa el TileMapLayer tal cual.
func configurar(p_id_bioma: int, p_tilemap: TileMapLayer, p_contenedor: Node2D, mapa: Dictionary = {}) -> void:
	id_bioma = p_id_bioma
	tilemap = p_tilemap
	contenedor = p_contenedor
	_tipos = mapa.get("tipos", {})
	_decoraciones = mapa.get("decoraciones", {})
	position = tilemap.position
	z_index = 1
	contenedor.z_index = 2

	estado = GameState.estado_bioma(id_bioma)
	if mapa.has("zona"):
		_usar_zona_generada(mapa["zona"])
	else:
		_calcular_zona()
	if (estado["celdas"] as Dictionary).is_empty():
		_generar_estado_inicial()
	_indexar_celdas()
	estado["fauna_total"] = EspecieLoader.fauna_del_bioma(id_bioma).size()
	_aplicar_niebla_pendiente()

	for celda in celdas:
		_sincronizar_planta(celda)
	# La niebla va bajo las especies y decoraciones (z 2 del contenedor), para no tapar la caseta
	# ni el puente que sobresalen hacia atrás; el cursor sí va encima de todo.
	_niebla = NieblaOlvido.new()
	_niebla.name = "NieblaOlvido"
	add_child(_niebla)
	_niebla.configurar(self)
	_cursor = Node2D.new()
	_cursor.name = "Cursor"
	_cursor.z_index = 3
	add_child(_cursor)
	_cursor.draw.connect(_dibujar_cursor)
	_recalcular_auras()
	for id in estado["fauna"]:
		var animal := EspecieLoader.por_id(int(id))
		if animal:
			_aparecer_fauna(animal)
	_evaluar()


# --- Generación y carga ---------------------------------------------------------------

func _generar_estado_inicial() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * id_bioma + 17
	var usadas: Array[Vector2i] = _zona.duplicate()
	var tipos := ReglasEcosistema.bloqueadores_del_bioma(id_bioma)
	var datos_celdas: Dictionary = estado["celdas"]

	for celda in usadas:
		datos_celdas[_clave(celda)] = {
			"n": _distancia(celda, _centro) > RADIO_CLARO_INICIAL and not (tipo(celda) in GeneradorMapa.SIN_NIEBLA),
			"b": "", "e": 0, "c": 0.0, "m": false,
		}

	# Mezcla determinista (Fisher-Yates con semilla del bioma).
	for i in range(usadas.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := usadas[i]
		usadas[i] = usadas[j]
		usadas[j] = tmp

	var objetivo := mini(MAX_BLOQUEADORES, int(usadas.size() * PROPORCION_BLOQUEADORES))
	var colocados := 0
	var en_claro := 0
	for celda in usadas:
		if colocados >= objetivo or tipos.is_empty():
			break
		if celda == _centro or not es_plantable(celda):
			continue
		var dentro := _distancia(celda, _centro) <= RADIO_CLARO_INICIAL
		if dentro and en_claro >= BLOQUEADORES_EN_CLARO:
			continue
		datos_celdas[_clave(celda)]["b"] = str(tipos[rng.randi() % tipos.size()]["id"])
		colocados += 1
		if dentro:
			en_claro += 1
	estado["bloqueadores_iniciales"] = colocados
	GameState.marcar_cambios()


## Zona jugable entregada por el GeneradorMapa. Si el guardado es de una versión anterior
## del mapa, el refugio de ese bioma se regenera (los PR se conservan).
func _usar_zona_generada(zona: Array) -> void:
	_zona.assign(zona)
	_centro = Vector2i.ZERO
	if int(estado.get("version_mapa", 0)) != GeneradorMapa.VERSION:
		(estado["celdas"] as Dictionary).clear()
		(estado["fauna"] as Array).clear()
		estado["bloqueadores_iniciales"] = 0
		estado["niebla_pendiente"] = 0
		estado["version_mapa"] = GeneradorMapa.VERSION
		GameState.marcar_cambios()
	var capa := Node2D.new()
	capa.name = "LimiteRefugio"
	add_child(capa)
	capa.draw.connect(_dibujar_limite_refugio.bind(capa))


## Línea punteada que marca el borde del refugio jugable.
func _dibujar_limite_refugio(capa: Node2D) -> void:
	var r := GeneradorMapa.RADIO_JUGABLE
	var puntos := PackedVector2Array([
		tilemap.map_to_local(Vector2i(-r, -r)) + Vector2(0, -16),
		tilemap.map_to_local(Vector2i(r, -r)) + Vector2(32, 0),
		tilemap.map_to_local(Vector2i(r, r)) + Vector2(0, 16),
		tilemap.map_to_local(Vector2i(-r, r)) + Vector2(-32, 0),
	])
	for i in 4:
		capa.draw_dashed_line(puntos[i], puntos[(i + 1) % 4], Color(1, 1, 0.9, 0.55), 2.0, 8.0)


func tipo(celda: Vector2i) -> String:
	return _tipos.get(celda, "suelo")


func es_plantable(celda: Vector2i) -> bool:
	return tipo(celda) in GeneradorMapa.PLANTABLES


## Define las parcelas jugables. En mapas grandes solo el entorno del centro es refugio;
## si un guardado antiguo tiene parcelas fuera de la zona, el refugio se regenera.
func _calcular_zona() -> void:
	var usadas := tilemap.get_used_cells()
	_centro = _calcular_centro(usadas)
	_zona = usadas
	if usadas.size() > CELDAS_MAPA_GRANDE:
		_zona = usadas.filter(func(c: Vector2i) -> bool: return _distancia(c, _centro) <= RADIO_REFUGIO)
		_dibujar_fuera_del_refugio(usadas)

	var guardadas: Dictionary = estado["celdas"]
	if guardadas.size() > _zona.size():
		guardadas.clear()
		(estado["fauna"] as Array).clear()


func _dibujar_fuera_del_refugio(usadas: Array[Vector2i]) -> void:
	var zona := {}
	for c in _zona:
		zona[c] = true
	var capa := Node2D.new()
	capa.name = "BosqueProfundo"
	add_child(capa)
	var fuera: Array[Vector2i] = usadas.filter(func(c: Vector2i) -> bool: return not zona.has(c))
	capa.draw.connect(_dibujar_capa_fuera.bind(capa, fuera))


func _dibujar_capa_fuera(capa: Node2D, fuera: Array[Vector2i]) -> void:
	var tam := Vector2(tilemap.tile_set.tile_size) * 1.04
	for c in fuera:
		capa.draw_colored_polygon(_rombo(tilemap.map_to_local(c), tam), COLOR_FUERA_REFUGIO)


func _indexar_celdas() -> void:
	var datos_celdas: Dictionary = estado["celdas"]
	celdas.clear()
	for celda in _zona:
		var clave := _clave(celda)
		if not datos_celdas.has(clave):
			# El mapa creció desde la última partida: las parcelas nuevas empiezan con niebla.
			datos_celdas[clave] = {"n": true, "b": "", "e": 0, "c": 0.0, "m": false}
		celdas[celda] = datos_celdas[clave]


## La niebla acumulada durante el abandono avanza desde sus bordes hacia el claro.
func _aplicar_niebla_pendiente() -> void:
	var pendientes := int(estado.get("niebla_pendiente", 0))
	if pendientes <= 0:
		return
	estado["niebla_pendiente"] = 0
	for _i in pendientes:
		var candidatas: Array[Vector2i] = []
		var mas_lejana := Vector2i.ZERO
		var distancia_max := -1.0
		for celda in celdas:
			if celdas[celda]["n"]:
				continue
			var d := _distancia(celda, _centro)
			if d > distancia_max:
				distancia_max = d
				mas_lejana = celda
			for vecina in tilemap.get_surrounding_cells(celda):
				if celdas.has(vecina) and celdas[vecina]["n"]:
					candidatas.append(celda)
					break
		if distancia_max < 0.0:
			break
		var elegida: Vector2i = candidatas.pick_random() if not candidatas.is_empty() else mas_lejana
		celdas[elegida]["n"] = true
		_sincronizar_planta(elegida)
	GameState.marcar_cambios()


# --- Interacción ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var celda := _celda_en(event.position)
		_hay_hover = celdas.has(celda)
		_celda_hover = celda
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Se actúa al soltar (no al presionar) para distinguir un toque de un arrastre de cámara.
		if event.pressed:
			_presionado = true
			return
		if not _presionado:
			return
		_presionado = false
		if Bioma.arrastrando:
			get_viewport().set_input_as_handled()
			return
		var celda := _celda_en(event.position)
		if celdas.has(celda) and _usar_herramienta(celda):
			get_viewport().set_input_as_handled()


## Celda bajo una posición de pantalla (la del evento: sirve igual para mouse y para toques).
func _celda_en(pos_pantalla: Vector2) -> Vector2i:
	var mundo := get_viewport().get_canvas_transform().affine_inverse() * pos_pantalla
	return tilemap.local_to_map(tilemap.to_local(mundo))


## Devuelve true si la acción consumió el clic.
func _usar_herramienta(celda: Vector2i) -> bool:
	match GameState.herramienta_activa:
		"disipar":
			_disipar(celda)
		"limpiar":
			_limpiar(celda)
		"plantar":
			_plantar(celda)
		"sanar":
			_sanar(celda)
		_:
			return _identificar(celda)
	return true


func _disipar(celda: Vector2i) -> void:
	if not celdas[celda]["n"]:
		_rechazar("Esta parcela ya está libre de la Niebla del Olvido.")
		return
	var costo := ReglasEcosistema.costo_niebla()
	if not _pagar(costo):
		return
	var despejadas := 0
	for otra in celdas:
		if celdas[otra]["n"] and _distancia(otra, celda) <= RADIO_DISIPAR:
			celdas[otra]["n"] = false
			_sincronizar_planta(otra)
			despejadas += 1
	_niebla.refrescar(celda)
	EventBus.accion_terreno.emit("disipar")
	_tras_cambio("La Niebla del Olvido se disipa en %d parcelas (−%d PR)." % [despejadas, costo])


func _limpiar(celda: Vector2i) -> void:
	var c: Dictionary = celdas[celda]
	if c["n"]:
		_rechazar("Primero disipa la niebla para ver qué hay en esta parcela.")
		return
	if str(c["b"]) == "":
		_rechazar("No hay nada que limpiar aquí.")
		return
	var info := ReglasEcosistema.bloqueador(id_bioma, str(c["b"]))
	var costo := ReglasEcosistema.costo_limpiar(info)
	if not _pagar(costo):
		return
	c["b"] = ""
	EventBus.accion_terreno.emit("limpiar")
	_tras_cambio("Retiraste: %s (−%d PR)." % [info.get("nombre", "bloqueador"), costo])


func _plantar(celda: Vector2i) -> void:
	var c: Dictionary = celdas[celda]
	var data := GameState.especie_para_plantar
	if data == null or data.id_bioma != id_bioma:
		_rechazar("Elige una especie nativa en la barra de plantación.")
		return
	if c["n"]:
		_rechazar("No puedes plantar bajo la Niebla del Olvido.")
		return
	if not es_plantable(celda):
		_rechazar("Aquí no se puede plantar: %s." % _descripcion_tipo(celda))
		return
	if str(c["b"]) != "":
		_rechazar("Limpia primero: %s." % ReglasEcosistema.bloqueador(id_bioma, str(c["b"])).get("nombre", "bloqueador"))
		return
	if int(c["e"]) > 0:
		_rechazar("Esta parcela ya tiene una planta.")
		return
	var costo := ReglasEcosistema.costo_plantar(data)
	if not _pagar(costo):
		return
	c["e"] = data.id_especie
	c["c"] = 0.0
	c["m"] = false
	_sincronizar_planta(celda)
	GameState.descubrir_especie(data)
	var bonos := _bonos_de(celda)
	var detalle := ""
	for b in bonos:
		if b["explicita"]:
			detalle = " Sinergia activa: «%s» (+%d%%)." % [b["nombre"], int(b["bono"] * 100)]
			break
	EventBus.accion_terreno.emit("plantar")
	_tras_cambio("Plantaste %s (−%d PR).%s" % [data.nombre_comun, costo, detalle])


func _sanar(celda: Vector2i) -> void:
	var c: Dictionary = celdas[celda]
	if c["n"] or int(c["e"]) <= 0 or not c["m"]:
		_rechazar("Aquí no hay plantas marchitas que sanar.")
		return
	var costo := ReglasEcosistema.costo_sanar()
	if not _pagar(costo):
		return
	c["m"] = false
	_sincronizar_planta(celda)
	EventBus.accion_terreno.emit("sanar")
	_tras_cambio("La planta recupera su vitalidad (−%d PR)." % costo)


func _identificar(celda: Vector2i) -> bool:
	var c: Dictionary = celdas[celda]
	if c["n"]:
		_avisar("Niebla del Olvido: usa «Disipar niebla» (%d PR) para recuperar esta zona." % ReglasEcosistema.costo_niebla())
		return true
	if str(c["b"]) != "":
		var info := ReglasEcosistema.bloqueador(id_bioma, str(c["b"]))
		_avisar("%s: retíralo con «Limpiar» (%d PR)." % [info.get("nombre", "Bloqueador"), ReglasEcosistema.costo_limpiar(info)])
		return true
	if not es_plantable(celda):
		_avisar(_descripcion_tipo(celda).capitalize() + ".")
		return true
	var data := EspecieLoader.por_id(int(c["e"]))
	if data:
		var texto := "%s — crecimiento %d%%" % [data.nombre_comun, int(float(c["c"]) * 100)]
		if c["m"]:
			texto += " (marchita: usa «Sanar»)"
		var mult := _multiplicador_crecimiento(celda)
		if mult > 1.0:
			texto += " · bonificación de vecinas +%d%%" % int(round((mult - 1.0) * 100))
		_avisar(texto)
		EventBus.especie_seleccionada.emit(data)
		return true
	# Parcela libre: dejamos pasar el clic por si hay un animal encima.
	return false


func _descripcion_tipo(celda: Vector2i) -> String:
	match tipo(celda):
		"agua":
			return "agua; la fauna terrestre no la cruza, pero da vida a los humedales"
		"sendero":
			return "el sendero del guardaparque"
		"puente":
			return "el puente del sendero"
		"caseta":
			return "la caseta del guardaparque, tu base en el refugio"
		"estructura":
			return "un elemento del paisaje"
	return "terreno"


func _pagar(costo: int) -> bool:
	if GameState.gastar_pr(costo, id_bioma):
		return true
	_rechazar("Necesitas %d PR y tienes %d. Gana Esencia Vital en la Tableta: trivias y minijuegos." % [costo, GameState.obtener_pr(id_bioma)])
	return false


func _tras_cambio(texto: String) -> void:
	GameState.marcar_cambios()
	_recalcular_auras()
	_evaluar()
	_avisar(texto)


func _avisar(texto: String) -> void:
	EventBus.mensaje.emit(texto)


func _rechazar(texto: String) -> void:
	EventBus.accion_rechazada.emit()
	_avisar(texto)


func accion_valida(celda: Vector2i) -> bool:
	if not celdas.has(celda):
		return false
	var c: Dictionary = celdas[celda]
	match GameState.herramienta_activa:
		"disipar":
			return c["n"]
		"limpiar":
			return not c["n"] and str(c["b"]) != ""
		"plantar":
			return not c["n"] and es_plantable(celda) and str(c["b"]) == "" and int(c["e"]) == 0 and GameState.especie_para_plantar != null
		"sanar":
			return not c["n"] and int(c["e"]) > 0 and c["m"]
	return true


# --- Crecimiento y sinergias ----------------------------------------------------------------

func _process(delta: float) -> void:
	_tiempo += delta
	var crecio := false
	var tiempo_crecimiento := float(GameState.ajuste("tiempo_crecimiento"))
	for celda in _nodos_plantas:
		var c: Dictionary = celdas[celda]
		if c["m"] or float(c["c"]) >= 1.0:
			continue
		c["c"] = minf(1.0, float(c["c"]) + delta / tiempo_crecimiento * _multiplicador_crecimiento(celda))
		_nodos_plantas[celda].aplicar_estado_planta(float(c["c"]), false)
		crecio = true

	_mover_fauna(delta)

	_acumulador += delta
	if _acumulador >= INTERVALO_EVALUACION:
		_acumulador = 0.0
		if crecio:
			GameState.marcar_cambios()
		_evaluar()
	queue_redraw()


## Bonificaciones que recibe la planta de `celda` desde sus vecinas sanas.
func _bonos_de(celda: Vector2i) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var objetivo := EspecieLoader.por_id(int(celdas[celda]["e"]))
	if objetivo == null:
		return resultado
	for vecina in tilemap.get_surrounding_cells(celda):
		if not celdas.has(vecina):
			continue
		var cv: Dictionary = celdas[vecina]
		if int(cv["e"]) <= 0 or cv["n"] or cv["m"]:
			continue
		var fuente := EspecieLoader.por_id(int(cv["e"]))
		if fuente == null:
			continue
		var s := ReglasEcosistema.sinergia(fuente, objetivo)
		if not s.is_empty():
			resultado.append(s)
	return resultado


func _multiplicador_crecimiento(celda: Vector2i) -> float:
	var total := 1.0
	for b in _bonos_de(celda):
		total += float(b["bono"])
	return total


func _recalcular_auras() -> void:
	_auras.clear()
	for celda in _nodos_plantas:
		for b in _bonos_de(celda):
			if b["explicita"]:
				_auras[celda] = b["nombre"]
				break


func _sincronizar_planta(celda: Vector2i) -> void:
	var c: Dictionary = celdas[celda]
	if _decoraciones.has(celda):
		(_decoraciones[celda] as CanvasItem).visible = not c["n"]
	var id := int(c["e"])
	var nodo: especie = _nodos_plantas.get(celda)
	if id <= 0 or c["n"]:
		if nodo:
			nodo.queue_free()
			_nodos_plantas.erase(celda)
		return
	var data := EspecieLoader.por_id(id)
	if data == null:
		c["e"] = 0
		return
	if nodo == null or nodo.data != data:
		if nodo:
			nodo.queue_free()
		nodo = _instanciar(data, celda, Vector2(0, -6))
		_nodos_plantas[celda] = nodo
	nodo.aplicar_estado_planta(float(c["c"]), bool(c["m"]))


func _instanciar(data: EspecieData, celda: Vector2i, desfase: Vector2) -> especie:
	var nodo := EspecieLoader.instanciar(data)
	contenedor.add_child(nodo)
	nodo.global_position = tilemap.to_global(tilemap.map_to_local(celda)) + desfase
	return nodo


# --- Salud y fauna ---------------------------------------------------------------------------

func _evaluar() -> void:
	var salud := GameState.actualizar_salud(id_bioma)
	_evaluar_fauna(salud)


func _evaluar_fauna(salud: float) -> void:
	var sanas := {}  # nombre normalizado -> cantidad
	var total_sanas := 0
	for celda in _nodos_plantas:
		var c: Dictionary = celdas[celda]
		if c["m"] or float(c["c"]) < 1.0:
			continue
		var nombre := ReglasEcosistema.normalizar(EspecieLoader.por_id(int(c["e"])).nombre_comun)
		sanas[nombre] = int(sanas.get(nombre, 0)) + 1
		total_sanas += 1

	var presentes: Array = estado["fauna"]
	for animal in EspecieLoader.fauna_del_bioma(id_bioma):
		if presentes.has(animal.id_especie):
			continue
		var req := ReglasEcosistema.requisitos_fauna(animal)
		if salud < float(req["min_salud"]) or total_sanas < int(req["min_sanas"]):
			continue
		var cumple := true
		for nombre in req["plantas"]:
			if not sanas.has(ReglasEcosistema.normalizar(nombre)):
				cumple = false
				break
		if not cumple:
			continue
		presentes.append(animal.id_especie)
		_aparecer_fauna(animal)
		EventBus.fauna_llego.emit(animal)
		GameState.marcar_cambios()
		var nueva := GameState.descubrir_especie(animal)
		_avisar("¡%s llegó a tu refugio!%s" % [animal.nombre_comun, " Nueva entrada en la Biopedia." if nueva else ""])
		# La fauna cuenta para la salud: recalculamos para el siguiente animal.
		salud = GameState.actualizar_salud(id_bioma)


func _aparecer_fauna(animal: EspecieData) -> void:
	if _nodos_fauna.has(animal.id_especie):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = animal.id_especie * 104729 + id_bioma
	if _es_nadador(animal):
		var aguas := _celdas_de_agua()
		if not aguas.is_empty():
			aguas.sort()
			var nodo_agua := _instanciar(animal, aguas[rng.randi() % aguas.size()], Vector2(rng.randf_range(-8, 8), GeneradorMapa.DESNIVEL_AGUA - 2))
			nodo_agua.scale = Vector2.ONE * ESCALA_FAUNA
			_nodos_fauna[animal.id_especie] = nodo_agua
			_iniciar_paseo(animal.id_especie, nodo_agua)
			return
	var libres: Array[Vector2i] = []
	var despejadas: Array[Vector2i] = []
	for celda in celdas:
		var c: Dictionary = celdas[celda]
		if c["n"]:
			continue
		if tipo(celda) in GeneradorMapa.NO_TRANSITABLES:
			continue
		despejadas.append(celda)
		if str(c["b"]) == "" and int(c["e"]) == 0:
			libres.append(celda)
	var opciones: Array[Vector2i] = libres if not libres.is_empty() else despejadas
	if opciones.is_empty():
		return
	opciones.sort()
	var celda: Vector2i = opciones[rng.randi() % opciones.size()]
	var nodo := _instanciar(animal, celda, Vector2(rng.randf_range(-8, 8), -4))
	nodo.scale = Vector2.ONE * ESCALA_FAUNA
	_nodos_fauna[animal.id_especie] = nodo
	_iniciar_paseo(animal.id_especie, nodo)


## Especies acuáticas (animación "swim"): nadan en el lago, río u océano del mapa.
func _es_nadador(animal: EspecieData) -> bool:
	if animal.escena == null:
		return false
	var nodo := animal.escena.instantiate()
	var sprite := nodo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var nada := sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"swim")
	nodo.free()
	return nada


## Agua del mapa (dentro del refugio o cerca de su borde); dentro del refugio solo si no hay niebla.
func _celdas_de_agua() -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	var limite := GeneradorMapa.RADIO_JUGABLE + RADIO_AGUA_NADADORES
	for celda in _tipos:
		if _tipos[celda] != "agua" or maxi(absi(celda.x), absi(celda.y)) > limite:
			continue
		if celdas.has(celda) and celdas[celda]["n"]:
			continue
		resultado.append(celda)
	return resultado


# --- Paseo de la fauna -----------------------------------------------------------------------
# Cada animal alterna entre descansar y caminar hacia una parcela despejada cercana.
# Los voladores (animación "fly") pueden cruzar bloqueadores y se desplazan más alto.

func _iniciar_paseo(id_especie: int, nodo: especie) -> void:
	var sprite := nodo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var animacion: StringName = &""
	if sprite and sprite.sprite_frames:
		for nombre in ANIMACIONES_MOVIMIENTO:
			if sprite.sprite_frames.has_animation(nombre):
				animacion = nombre
				break
	var paseo := {
		"nodo": nodo,
		"sprite": sprite,
		"animacion": animacion,
		"vuela": animacion == &"fly",
		"nada": animacion == &"swim",
		"velocidad": float(VELOCIDAD_POR_ANIMACION.get(animacion, 16.0)) * randf_range(0.8, 1.2),
		"destino": nodo.global_position,
		"espera": randf_range(0.5, 3.0),
	}
	_paseos[id_especie] = paseo
	_detener(paseo)


func _mover_fauna(delta: float) -> void:
	for id in _paseos:
		var paseo: Dictionary = _paseos[id]
		var nodo: Node2D = paseo["nodo"]
		if not is_instance_valid(nodo):
			continue
		if paseo["espera"] > 0.0:
			paseo["espera"] -= delta
			if paseo["espera"] <= 0.0:
				paseo["destino"] = _elegir_destino_agua(nodo) if paseo.get("nada", false) else _elegir_destino(nodo, paseo["vuela"])
				_reanudar(paseo)
			continue
		var hacia: Vector2 = paseo["destino"] - nodo.global_position
		var paso: float = paseo["velocidad"] * delta
		if hacia.length() <= paso:
			nodo.global_position = paseo["destino"]
			paseo["espera"] = randf_range(1.5, 5.0)
			_detener(paseo)
		else:
			nodo.global_position += hacia.normalized() * paso
			var sprite: AnimatedSprite2D = paseo["sprite"]
			if sprite and absf(hacia.x) > 0.5:
				# Los sprites miran a la derecha: se espejan al ir hacia la izquierda.
				sprite.flip_h = hacia.x < 0.0


func _elegir_destino(nodo: Node2D, vuela: bool) -> Vector2:
	var actual := tilemap.local_to_map(tilemap.to_local(nodo.global_position))
	var opciones: Array[Vector2i] = []
	for celda in celdas:
		var c: Dictionary = celdas[celda]
		if c["n"] or celda == actual:
			continue
		if not vuela and (str(c["b"]) != "" or tipo(celda) in GeneradorMapa.NO_TRANSITABLES):
			continue
		if _distancia(celda, actual) <= RADIO_PASEO:
			opciones.append(celda)
	if opciones.is_empty():
		return nodo.global_position
	var destino: Vector2i = opciones.pick_random()
	var altura := ALTURA_VUELO if vuela else 4.0
	return tilemap.to_global(tilemap.map_to_local(destino)) + Vector2(randf_range(-10, 10), randf_range(-5, 3) - altura)


func _elegir_destino_agua(nodo: Node2D) -> Vector2:
	var actual := tilemap.local_to_map(tilemap.to_local(nodo.global_position))
	var opciones := _celdas_de_agua().filter(func(c: Vector2i) -> bool: return c != actual and _distancia(c, actual) <= RADIO_PASEO)
	if opciones.is_empty():
		return nodo.global_position
	var destino: Vector2i = opciones.pick_random()
	return tilemap.to_global(tilemap.map_to_local(destino)) + Vector2(randf_range(-10, 10), GeneradorMapa.DESNIVEL_AGUA + randf_range(-4, 2))


func _reanudar(paseo: Dictionary) -> void:
	var sprite: AnimatedSprite2D = paseo["sprite"]
	if sprite and paseo["animacion"] != &"":
		sprite.play(paseo["animacion"])


## En reposo la animación se congela en su primer cuadro; los insectos voladores siguen aleteando.
func _detener(paseo: Dictionary) -> void:
	var sprite: AnimatedSprite2D = paseo["sprite"]
	if sprite == null or paseo["animacion"] == &"":
		return
	if paseo["vuela"] and not sprite.sprite_frames.has_animation(&"walk"):
		return
	if paseo["vuela"]:
		sprite.animation = &"walk"  # Un ave posada (ej. Loro choroy) deja de aletear.
	sprite.pause()
	sprite.frame = 0


# --- Dibujo ---------------------------------------------------------------------------------------

func _draw() -> void:
	if tilemap == null or tilemap.tile_set == null:
		return
	var tam := Vector2(tilemap.tile_set.tile_size)
	for celda in celdas:
		var c: Dictionary = celdas[celda]
		var p := tilemap.map_to_local(celda)
		if c["n"]:
			continue   # la dibuja NieblaOlvido
		if str(c["b"]) != "":
			_dibujar_bloqueador(p, ReglasEcosistema.bloqueador(id_bioma, str(c["b"])), celda)
		elif _auras.has(celda):
			_dibujar_rombo(p, tam * 0.9, COLOR_AURA)
		if int(c["e"]) > 0 and c["m"]:
			_dibujar_rombo(p, tam * 0.8, COLOR_MARCHITA)
	if _cursor:
		_cursor.queue_redraw()


func _dibujar_cursor() -> void:
	if not _hay_hover:
		return
	var p := tilemap.map_to_local(_celda_hover)
	var color := COLOR_VALIDO if accion_valida(_celda_hover) else COLOR_INVALIDO
	var puntos := _rombo(p, Vector2(tilemap.tile_set.tile_size))
	puntos.append(puntos[0])
	_cursor.draw_polyline(puntos, color, 2.0)


func _rombo(centro: Vector2, tam: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		centro + Vector2(0, -tam.y * 0.5),
		centro + Vector2(tam.x * 0.5, 0),
		centro + Vector2(0, tam.y * 0.5),
		centro + Vector2(-tam.x * 0.5, 0),
	])


func _dibujar_rombo(centro: Vector2, tam: Vector2, color: Color) -> void:
	draw_colored_polygon(_rombo(centro, tam), color)


func _dibujar_bloqueador(p: Vector2, info: Dictionary, celda: Vector2i) -> void:
	var color := Color.html(str(info.get("color", "#7d6b55")))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(celda)
	if str(info.get("forma", "basura")) == "invasora":
		# Matorral espinoso: triángulos oscuros apiñados.
		for i in 5:
			var base := p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-4, 6))
			var alto := rng.randf_range(10, 18)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-5, 0), base + Vector2(5, 0), base + Vector2(0, -alto)]), color.darkened(i * 0.08))
	else:
		# Microbasural: bolsas y restos amontonados.
		for i in 4:
			var centro := p + Vector2(rng.randf_range(-12, 12), rng.randf_range(-6, 4))
			draw_circle(centro, rng.randf_range(3.5, 6.5), color.lightened(i * 0.1))
		draw_rect(Rect2(p + Vector2(-4, -8), Vector2(8, 5)), color.darkened(0.3))


# --- Utilidades ------------------------------------------------------------------------------------

func _clave(celda: Vector2i) -> String:
	return "%d,%d" % [celda.x, celda.y]


## Distancia isométrica en parcelas (vecinas = 1), independiente del layout del TileSet.
func _distancia(a: Vector2i, b: Vector2i) -> float:
	var d := tilemap.map_to_local(a) - tilemap.map_to_local(b)
	var mitad := Vector2(tilemap.tile_set.tile_size) * 0.5
	return (absf(d.x) / mitad.x + absf(d.y) / mitad.y) * 0.5


func _calcular_centro(usadas: Array[Vector2i]) -> Vector2i:
	if usadas.is_empty():
		return Vector2i.ZERO
	var suma := Vector2.ZERO
	for celda in usadas:
		suma += tilemap.map_to_local(celda)
	var promedio := suma / usadas.size()
	var mejor := usadas[0]
	var mejor_d := INF
	for celda in usadas:
		var d := tilemap.map_to_local(celda).distance_squared_to(promedio)
		if d < mejor_d:
			mejor_d = d
			mejor = celda
	return mejor


## Rectángulo global que ocupa la grilla (para encuadrar la cámara).
func rect_global() -> Rect2:
	var usadas := _zona
	if usadas.is_empty():
		return Rect2(tilemap.global_position, Vector2.ONE)
	var rect := Rect2(tilemap.to_global(tilemap.map_to_local(usadas[0])), Vector2.ZERO)
	for celda in usadas:
		rect = rect.expand(tilemap.to_global(tilemap.map_to_local(celda)))
	return rect.grow(64)
