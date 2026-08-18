extends Node

var bioma_actual_id: int= -1
var pr_sesion: int = 0
var herramienta_activa : String = "identificar" 
signal pr_actualizado(nuevo_total:int )


func agregar_pr(cantidad: int )-> void:
	pr_sesion += cantidad
	pr_actualizado.emit(pr_sesion)
