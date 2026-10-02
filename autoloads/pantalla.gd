extends Node

## Pantalla - Adapta el área lógica de la interfaz a la orientación de la ventana.
## En horizontal (PC) el área lógica es 1152x648; en vertical (teléfono) es 480x854, así los
## textos y botones conservan un tamaño legible y cómodo para los dedos. Con el estiramiento
## "expand" del proyecto, el lado sobrante de la pantalla agranda el área en vez de dejar franjas.
## Las interfaces que se reacomodan escuchan `orientacion_cambiada` o leen `vertical`.

signal orientacion_cambiada(vertical: bool)

const TAMANO_HORIZONTAL := Vector2i(1152, 648)
const TAMANO_VERTICAL := Vector2i(480, 854)

var vertical := false


func _ready() -> void:
	get_tree().root.size_changed.connect(_actualizar)
	_actualizar()


func _actualizar() -> void:
	var ventana := get_tree().root
	var es_vertical := ventana.size.y > ventana.size.x
	ventana.content_scale_size = TAMANO_VERTICAL if es_vertical else TAMANO_HORIZONTAL
	if es_vertical != vertical:
		vertical = es_vertical
		orientacion_cambiada.emit(vertical)
