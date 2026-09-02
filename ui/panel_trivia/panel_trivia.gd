extends Control

@onready var nombre_label: Label = $NombreLabel
@onready var rol_label: Label = $RolLabel
@onready var cerrar_button: Button = $CerrarButton

func _ready() -> void:
	# Nos conectamos al aviso global y al botón de cerrar
	EventBus.especie_seleccionada.connect(_on_especie_seleccionada)
	cerrar_button.pressed.connect(_on_cerrar_pressed)
	
	# Ocultamos el panel al iniciar el juego
	hide()

func _on_especie_seleccionada(datos: EspecieData) -> void:
	# Cuando tocamos una especie, llenamos los textos y mostramos el panel
	nombre_label.text = datos.nombre_comun
	rol_label.text = datos.rol_ecologico
	show()

func _on_cerrar_pressed() -> void:
	hide()
