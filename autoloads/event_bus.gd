extends Node

signal especie_seleccionada(datos_especie: EspecieData)
## modo: "bioma" (trivia libre del bioma actual), "especie" (pista conceptual de una especie) o "repaso" (validación espaciada).
signal solicitar_trivia(modo: String, id_especie: int)
signal cambiar_bioma_solicitado(id_bioma: int)
signal bioma_cargado(id_bioma: int)
signal mensaje(texto: String)
## Acción realizada en el terreno: "disipar", "limpiar", "plantar" o "sanar".
signal accion_terreno(accion: String)
