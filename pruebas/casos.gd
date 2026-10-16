extends Node

## Casos de prueba de regresión de Faunetra; los carga pruebas/suite.gd una vez que los autoloads
## (GameState, TriviaManager...) ya existen, para que las clases que dependen de ellos compilen.
## Imprime "OK" / "FALLA" por prueba y termina con el número de fallas como código de salida.

var GS: Node
var TM: Node
var fallas := 0
var total := 0


func ok(condicion: bool, nombre: String, detalle: Variant = "") -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("%s %s%s" % ["OK   " if condicion else "FALLA", nombre, ("  " + str(detalle)) if str(detalle) != "" else ""])


func _ready() -> void:
	await get_tree().process_frame
	GS = get_tree().root.get_node("GameState")
	TM = get_tree().root.get_node("TriviaManager")
	_catalogo()
	_trivias()
	_grupos_fauna()
	_guardado()
	await _biomas_y_controles()
	print("RESULTADO %d/%d pruebas pasan" % [total - fallas, total])
	get_tree().quit(fallas)


# --- Catálogo y trivias ---------------------------------------------------------------------

func _catalogo() -> void:
	var especies := EspecieLoader.cargar_todas()
	var ids := {}
	for d in especies:
		ids[d.id_especie] = true
	ok(especies.size() == 80 and ids.size() == 80, "catálogo: 80 especies con id único", especies.size())

	# Matrices de respaldo científico (auditoría A12): una fila por ficha y por regla del juego.
	var en_matriz := {}
	for fila in _leer_csv("res://documentacion/respaldo_cientifico/especies.csv"):
		en_matriz[int(fila.get("id_especie", -1))] = true
	var faltan := ids.keys().filter(func(id) -> bool: return not en_matriz.has(id))
	ok(not en_matriz.is_empty() and faltan.is_empty(), "respaldo científico: cada especie tiene su fila", faltan)
	var reglas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ecosistema/reglas_ecosistema.json"))
	var filas_reglas := _leer_csv("res://documentacion/respaldo_cientifico/relaciones.csv").size()
	var total_reglas: int = reglas["sinergias"].size() + reglas["atracciones"].size()
	ok(filas_reglas == total_reglas, "respaldo científico: cada sinergia y atracción tiene su fila", "%d de %d" % [filas_reglas, total_reglas])


func _leer_csv(ruta: String) -> Array[Dictionary]:
	var filas: Array[Dictionary] = []
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return filas
	var columnas := f.get_csv_line()
	while not f.eof_reached():
		var valores := f.get_csv_line()
		if valores.size() < columnas.size():
			continue
		var fila := {}
		for i in columnas.size():
			fila[columnas[i]] = valores[i]
		filas.append(fila)
	return filas


func _trivias() -> void:
	var banco: Array = TM.trivias_cargadas
	var malas := banco.filter(func(t) -> bool: return t.opciones.filter(func(o) -> bool: return o.es_correcta).size() != 1)
	ok(banco.size() == 55 and malas.is_empty(), "banco: 55 trivias con una sola correcta", "%d / malas %d" % [banco.size(), malas.size()])

	var invalidas := 0
	for d in EspecieLoader.cargar_todas():
		for nivel in [TriviaData.Dificultad.FACIL, TriviaData.Dificultad.MEDIO, TriviaData.Dificultad.DIFICIL]:
			var t: TriviaData = TM.generar_trivia(d, nivel)
			var textos := {}
			var correctas := 0
			for o in t.opciones:
				textos[o.texto] = true
				correctas += 1 if o.es_correcta else 0
			if correctas != 1 or t.opciones.size() < 3 or textos.size() != t.opciones.size():
				invalidas += 1
	ok(invalidas == 0, "240 preguntas generadas: una correcta, 3+ opciones, sin repetidas", "inválidas %d" % invalidas)

	# La correcta no puede quedar siempre primera (error encontrado en la beta).
	for modo in ["guardaparques", "cientifico"]:
		GS.modo = modo
		var posiciones := {}
		for i in 300:
			TM._mostradas.clear()
			var t: TriviaData = TM.obtener_trivia_adaptativa(0, [1, 2, 3, 4, 5].pick_random())
			for k in t.opciones.size():
				if t.opciones[k].es_correcta:
					posiciones[k] = posiciones.get(k, 0) + 1
		var minimo := 300
		for k in 3:
			minimo = mini(minimo, posiciones.get(k, 0))
		ok(minimo >= 45, "barajado (%s): la correcta aparece en todas las posiciones" % modo, posiciones)
	GS.modo = GS.MODO_POR_DEFECTO
	TM._mostradas.clear()


# --- Grupos de fauna (auditoría N02) --------------------------------------------------------

func _grupos_fauna() -> void:
	var sin_grupo: Array[String] = []
	var flora_con_grupo: Array[String] = []
	for d in EspecieLoader.cargar_todas():
		var flora := EspecieLoader.es_flora(d) or d.tipo == "hongo"
		if flora and d.grupo != "":
			flora_con_grupo.append(d.nombre_comun)
		elif not flora and not (d.grupo in EspecieData.GRUPOS):
			sin_grupo.append(d.nombre_comun)
	ok(sin_grupo.is_empty(), "toda la fauna tiene un grupo biológico válido", sin_grupo)
	ok(flora_con_grupo.is_empty(), "la flora no tiene grupo de fauna", flora_con_grupo)

	# Casos que la clasificación por texto resolvía mal.
	var esperado := {
		51: "mamifero",    # Gato montés argentino (su rol menciona aves)
		43: "insecto",     # Mosca florícola valdiviana («clave » contenía «ave »)
		15: "mamifero",    # Guanaco norteño («través» contenía «ave»)
		57: "crustaceo",   # Pancora patagónica (su rol menciona aves)
		1: "mamifero",     # Chinchilla cordillerana («cordillerana» contenía «rana»)
		27: "aracnido",    # Araña de Hualpén («araña» contenía «rana»)
		70: "aracnido",    # Seudoescorpión insular (su rol menciona insectos)
		50: "mamifero_marino",
		80: "reptil_marino",
	}
	var errores := {}
	for id in esperado:
		var obtenido := SintetizadorFauna.categoria(EspecieLoader.por_id(id))
		if obtenido != esperado[id]:
			errores[EspecieLoader.por_id(id).nombre_comun] = obtenido
	ok(errores.is_empty(), "regresión N02: grupos de las especies mal clasificadas antes", errores)

	var sin_sonido: Array[String] = []
	for d in EspecieLoader.toda_la_fauna():
		var wav := SintetizadorFauna.generar(d)
		if wav == null or wav.data.size() < 1000 or SintetizadorFauna.descripcion(d) == "":
			sin_sonido.append(d.nombre_comun)
	ok(sin_sonido.is_empty(), "cada animal tiene sonido simulado y explicación", sin_sonido)


# --- Guardado (auditoría A08, N03 y N04) ---------------------------------------------------

func _escribir(ruta: String, datos: Variant) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(datos if datos is String else JSON.stringify(datos))
	f.close()


func _limpiar_guardados() -> void:
	for sufijo in ["", ".bak", ".tmp", ".ilegible"]:
		if FileAccess.file_exists(GS.RUTA_GUARDADO + sufijo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.RUTA_GUARDADO + sufijo))
	GS.solo_lectura = false


func _guardado() -> void:
	_limpiar_guardados()
	GS.biomas = {}
	GS.estado_bioma(3)["pr"] = 123
	GS.guardar()
	GS.guardar()
	GS.biomas = {}
	GS.cargar()
	ok(int(GS.estado_bioma(3)["pr"]) == 123, "guardar y cargar conserva los PR")
	ok(FileAccess.file_exists(GS.RUTA_RESPALDO) and not FileAccess.file_exists(GS.RUTA_GUARDADO + ".tmp"),
		"el guardado deja respaldo .bak y no deja .tmp")

	# JSON ilegible → se recupera el respaldo.
	GS.codigo_participante = "RESPALDO"
	GS.guardar()
	GS.guardar()
	_escribir(GS.RUTA_GUARDADO, "{roto")
	GS.codigo_participante = ""
	GS.cargar()
	ok(GS.codigo_participante == "RESPALDO" and FileAccess.file_exists(GS.RUTA_GUARDADO + ".ilegible"),
		"JSON ilegible: se recupera el respaldo y el archivo dañado se aparta")

	# N03: JSON válido con estructuras internas inválidas → también se usa el respaldo.
	var casos := {
		"celda null": {"version": 1, "codigo_participante": "PRINCIPAL", "biomas": {"3": {"celdas": {"0,0": null}}}},
		"fauna con texto": {"version": 1, "codigo_participante": "PRINCIPAL", "biomas": {"3": {"fauna": ["x"]}}},
		"insignias null": {"version": 1, "codigo_participante": "PRINCIPAL", "trivia": {"insignias": null}},
		"validación rota": {"version": 1, "codigo_participante": "PRINCIPAL", "validaciones": {"5": "mal"}},
	}
	for nombre in casos:
		_limpiar_guardados()
		GS.codigo_participante = "RESPALDO"
		GS.guardar()
		GS.guardar()
		_escribir(GS.RUTA_GUARDADO, casos[nombre])
		GS.codigo_participante = ""
		GS.cargar()
		ok(GS.codigo_participante == "RESPALDO", "N03 (%s): se rechaza y se recupera el respaldo" % nombre)

	# N04: guardado de una versión más nueva → solo lectura, el archivo queda intacto.
	_limpiar_guardados()
	var futuro := JSON.stringify({"version": 99, "codigo_participante": "FUTURO", "campo_futuro": {"a": 1}})
	_escribir(GS.RUTA_GUARDADO, futuro)
	GS.cargar()
	GS.marcar_cambios()
	GS.guardar()
	ok(GS.solo_lectura and FileAccess.get_file_as_string(GS.RUTA_GUARDADO) == futuro
		and not FileAccess.file_exists(GS.RUTA_RESPALDO) and not FileAccess.file_exists(GS.RUTA_GUARDADO + ".ilegible"),
		"N04: un guardado de versión futura no se sobrescribe ni se renombra")
	_limpiar_guardados()

	# N01 dentro del proceso: guardar con TriviaManager listo exporta sus datos reales.
	TM.xp_acumulada = 4321
	GS.guardar()
	var guardado: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GS.RUTA_GUARDADO))
	ok(int(guardado["trivia"]["xp"]) == 4321, "guardar exporta el progreso de trivias")
	TM.reiniciar()
	_limpiar_guardados()


# --- Biomas y controles --------------------------------------------------------------------

func _biomas_y_controles() -> void:
	var rutas: Dictionary = load("res://main.gd").get_script_constant_map()["BIOMAS"]
	for id in rutas:
		var b: Bioma = load(rutas[id]).instantiate()
		get_tree().root.add_child(b)
		for i in 3:
			await get_tree().process_frame
		ok(b.terreno != null and b.terreno.celdas.size() > 0, "bioma %d carga su refugio" % id, b.terreno.celdas.size() if b.terreno else 0)
		if id == 3:
			await _controles(b)
		b.queue_free()
		await get_tree().process_frame


func _evento_mouse(p: Vector2, presionado: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = presionado
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if presionado else 0
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _mover_mouse(p: Vector2, rel: Vector2, apretado: bool) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apretado else 0
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _controles(b: Bioma) -> void:
	var cam := b.camara
	var centro := get_tree().root.get_visible_rect().size * 0.5
	# Clic en una parcela con herramienta y después mover sin botón: el mapa no debe seguir al mouse.
	GS.herramienta_activa = "limpiar"
	var antes := cam.global_position
	await _evento_mouse(centro, true)
	await _evento_mouse(centro, false)
	for k in 5:
		await _mover_mouse(centro + Vector2(k * 20, 0), Vector2(20, 0), false)
	ok(antes.distance_to(cam.global_position) < 1.0 and not Bioma.arrastrando,
		"tras un clic en una parcela el mapa no queda agarrado al mouse", antes.distance_to(cam.global_position))
	GS.herramienta_activa = "identificar"
	# Arrastre normal con el mouse: mueve la cámara y al soltar termina el arrastre.
	antes = cam.global_position
	await _evento_mouse(centro, true)
	for k in 6:
		await _mover_mouse(centro + Vector2((k + 1) * 15, 0), Vector2(15, 0), true)
	await _evento_mouse(centro + Vector2(90, 0), false)
	ok(antes.distance_to(cam.global_position) > 30.0 and not Bioma.arrastrando,
		"arrastrar con el mouse mueve el mapa y se suelta bien", antes.distance_to(cam.global_position))
