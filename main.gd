extends Node2D

const BIOMAS := {
	1: "res://biomas/zona_central/zona_central.tscn",
	2: "res://biomas/desierto/desierto.tscn",
	3: "res://biomas/bosque_templado/bosque_templado.tscn",
	4: "res://biomas/patagonia/patagonia.tscn",
	5: "res://biomas/territorios_insulares/territorios_insulares.tscn",
}

@onready var contenedor_bioma: Node2D = $ContenedorBioma
@onready var hud: Control = $CanvasLayer/HUD


func _ready() -> void:
	EventBus.cambiar_bioma_solicitado.connect(cargar_bioma_por_id)
	cargar_bioma_por_id(_bioma_inicial())
	_mostrar_avisos_de_inicio.call_deferred()


func _bioma_inicial() -> int:
	if BIOMAS.has(GameState.ultimo_bioma) and GameState.esta_desbloqueado(GameState.ultimo_bioma):
		return GameState.ultimo_bioma
	return GameState.ORDEN_BIOMAS[0]


func _unhandled_input(event: InputEvent) -> void:
	# Atajos de desarrollo (solo en builds de depuración):
	# 1-5 cambian de bioma sin respetar el desbloqueo, F7 da +100 PR y F8 simula 3 días de abandono.
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F7:
				GameState.agregar_pr(100)
				EventBus.mensaje.emit("[Dev] +100 PR")
			KEY_F8:
				GameState.simular_inactividad(3)
				cargar_bioma_por_id(GameState.bioma_actual_id)
				_mostrar_informe_degradacion()
			_:
				var id: int = event.keycode - KEY_0
				if BIOMAS.has(id):
					cargar_bioma_por_id(id)


func cargar_bioma_por_id(id_bioma: int) -> void:
	GameState.ultimo_bioma = id_bioma
	GameState.marcar_cambios()
	cargar_bioma(BIOMAS[id_bioma])


func cargar_bioma(ruta_escena: String) -> void:
	# 1. Limpiamos si había otro bioma cargado antes (lo sacamos del árbol de inmediato
	#    para que su cámara y su grilla no convivan con las del nuevo).
	for hijo in contenedor_bioma.get_children():
		contenedor_bioma.remove_child(hijo)
		hijo.queue_free()

	# 2. Cargamos el nuevo bioma
	var escena_bioma = load(ruta_escena)
	var bioma_instanciado = escena_bioma.instantiate()

	# 3. Lo enchufamos en nuestro contenedor
	contenedor_bioma.add_child(bioma_instanciado)


func _mostrar_avisos_de_inicio() -> void:
	hud.abrir_menu()
	if GameState.primera_partida:
		GameState.primera_partida = false
		GameState.marcar_cambios()
	else:
		_mostrar_informe_degradacion()
	# El tutorial guiado reemplaza el texto de bienvenida y se retoma si quedó a medias.
	hud.iniciar_tutorial()


func _mostrar_informe_degradacion() -> void:
	if GameState.informe_degradacion.is_empty():
		var repasos := GameState.repasos_pendientes().size()
		if repasos > 0:
			EventBus.mensaje.emit("Tienes %d repasos de validación pendientes en la Tableta." % repasos)
		return
	hud.mostrar_dialogo("Tus refugios te extrañaron",
		"Pasaron %d días desde tu última visita.\n\n%s\n\nReinvierte PR para sanar las plantas marchitas (herramienta «Sanar») y despejar la niebla; la fauna volverá cuando el hábitat se recupere." % [
			GameState.dias_inactivo, "\n".join(PackedStringArray(GameState.informe_degradacion))])
	GameState.informe_degradacion.clear()
