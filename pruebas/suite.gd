extends SceneTree

## Pruebas de regresión de Faunetra (catálogo, trivias, grupos de fauna, guardado, biomas y controles).
## No ejecutar directamente sobre el proyecto: herramientas/pruebas.sh lo corre en una copia con
## otro nombre, para que el guardado de prueba nunca toque la partida real del jugador.
## Con `-s`, este script se compila antes de registrar los autoloads: por eso los casos están en
## pruebas/casos.gd y se cargan recién en el primer cuadro.


func _initialize() -> void:
	process_frame.connect(func() -> void: root.add_child(load("res://pruebas/casos.gd").new()), CONNECT_ONE_SHOT)
