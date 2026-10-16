extends SceneTree

## Auditoría N01 (paso 3 de 3): tras dos aperturas normales del juego, el guardado debe conservar
## todos los campos de TriviaManager preparados por n01_preparar.gd.

const Preparar := preload("res://pruebas/n01_preparar.gd")


func _initialize() -> void:
	process_frame.connect(_verificar, CONNECT_ONE_SHOT)


func _verificar() -> void:
	# Se lee el archivo tal como lo dejó la última apertura (este proceso no guarda antes de leerlo:
	# GameState ya cargó y guardó al iniciar, y debe haber conservado lo mismo).
	var gs := root.get_node("GameState")
	var guardado = JSON.parse_string(FileAccess.get_file_as_string(gs.RUTA_GUARDADO))
	var trivia: Dictionary = guardado.get("trivia", {}) if guardado is Dictionary else {}
	var perdidos := {}
	for clave in Preparar.ESPERADO:
		if not _iguales(trivia.get(clave), Preparar.ESPERADO[clave]):
			perdidos[clave] = trivia.get(clave)
	var tm := root.get_node("TriviaManager")
	var en_memoria := int(tm.xp_acumulada) == 12345 and int(tm.total_trivias_respondidas) == 77
	var bien := perdidos.is_empty() and en_memoria
	print("%s N01: el progreso de trivias se conserva tras reabrir el juego%s" % [
		"OK   " if bien else "FALLA", "" if bien else "  perdidos=%s en_memoria=%s" % [perdidos, en_memoria]])
	quit(0 if bien else 1)


## Comparación profunda; JSON devuelve los enteros como float, así que 4.0 == 4.
func _iguales(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _iguales(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in b:
			if not a.has(k) or not _iguales(a[k], b[k]):
				return false
		return true
	return a == b
