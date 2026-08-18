class_name player
extends CharacterBody2D

@export var speed: float = 220.0
@export var acceleration: float = 900.0
@export var friction: float = 1000.0
@onready var interaction_area: Area2D = $InteractionArea
# NOTA: Si usaste un Sprite2D normal, cambia AnimatedSprite2D a Sprite2D aquí abajo
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing_direction: Vector2 = Vector2.DOWN
var especies_cercanas: Array[especie] = []
func _ready() -> void:
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		facing_direction = input_direction
		# _reproducir_animacion("caminar") # Descomenta cuando tengas tus animaciones
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# _reproducir_animacion("idle") # Descomenta cuando tengas tus animaciones
	move_and_slide()
	if Input.is_action_just_pressed("interact"):
		_interactuar_con_mas_cercana()
func _interactuar_con_mas_cercana() -> void:
	if especies_cercanas.is_empty():
		return
	var mas_cercana := especies_cercanas[0]
	var distancia_minima := global_position.distance_to(mas_cercana.global_position)
	for especie in especies_cercanas:
		var distancia := global_position.distance_to(especie.global_position)
		if distancia < distancia_minima:
			distancia_minima = distancia
			mas_cercana = especie
	
	print("Interactuando con especie!")
	mas_cercana.interactuar()
func _on_area_entered(area: Area2D) -> void:
	var nodo_especie := area.get_parent() as especie
	if nodo_especie:
		especies_cercanas.append(nodo_especie)
func _on_area_exited(area: Area2D) -> void:
	var nodo_especie := area.get_parent() as especie
	if nodo_especie:
		especies_cercanas.erase(nodo_especie)
