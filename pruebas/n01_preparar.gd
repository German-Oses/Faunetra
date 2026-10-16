extends SceneTree

## Auditoría N01 (paso 1 de 3): deja un guardado con valores distintivos en todos los campos de
## TriviaManager. herramientas/pruebas.sh abre luego el juego dos veces y n01_verificar.gd revisa
## que nada se haya perdido.

const ESPERADO := {
	"nivel": 2, "racha_aciertos": 3, "racha_errores": 1, "total": 77, "xp": 12345,
	"insignias": ["insignia_prueba"], "desempeno": {"ave": {"aciertos": 4, "intentos": 6}},
}


func _initialize() -> void:
	process_frame.connect(_preparar, CONNECT_ONE_SHOT)


func _preparar() -> void:
	var gs := root.get_node("GameState")
	var datos := {"version": gs.VERSION_GUARDADO, "codigo_participante": "N01", "primera_partida": false,
		"modo_elegido": true, "trivia": ESPERADO}
	var f := FileAccess.open(gs.RUTA_GUARDADO, FileAccess.WRITE)
	f.store_string(JSON.stringify(datos))
	f.close()
	if FileAccess.file_exists(gs.RUTA_RESPALDO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.RUTA_RESPALDO))
	quit()
