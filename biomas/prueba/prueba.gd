extends Node2D


func _ready() -> void:
	var especies :=EspecieLoader.cargar_especies_del_bioma(1)
	print("especies cargadas: ",especies.size())
	var posiciones : Array[Vector2] =[Vector2(0,0), Vector2(150,0),Vector2(300,0)]
	EspecieLoader.instanciar_especies(especies ,self, posiciones)
