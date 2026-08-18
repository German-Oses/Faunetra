extends Node2D


@onready var contenedor_especies: Node2D=$especies

func _ready() -> void:
	#bosque templado tiene id 1 
	GameState.bioma_actual_id = 1 
	
	var especies := EspecieLoader.cargar_especies_del_bioma(1)
	
	# Aquí definimos las posiciones donde aparecerán las plantas (ajustarlas cuando pongamos los sprites)
	var posiciones : Array[Vector2] = [Vector2(100, 100), Vector2(300, 150), Vector2(200, 300)]
	
	EspecieLoader.instanciar_especies(especies, contenedor_especies, posiciones)
