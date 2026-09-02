extends Node2D

@onready var contenedor_bioma: Node2D = $ContenedorBioma

func _ready() -> void:
	# Cuando arranque el juego, cargamos el bosque de prueba automáticamente
	cargar_bioma("res://biomas/bosque_templado/bosque_templado.tscn")

func cargar_bioma(ruta_escena: String) -> void:
	# 1. Limpiamos si había otro bioma cargado antes
	for hijo in contenedor_bioma.get_children():
		hijo.queue_free()
		
	# 2. Cargamos el nuevo bioma
	var escena_bioma = load(ruta_escena)
	var bioma_instanciado = escena_bioma.instantiate()
	
	# 3. Lo enchufamos en nuestro contenedor
	contenedor_bioma.add_child(bioma_instanciado)
