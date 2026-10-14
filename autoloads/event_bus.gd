extends Node

signal especie_seleccionada(datos_especie: EspecieData)
## modo: "bioma" (trivia libre del bioma actual), "especie" (pista conceptual de una especie) o "repaso" (validación espaciada).
signal solicitar_trivia(modo: String, id_especie: int)
signal cambiar_bioma_solicitado(id_bioma: int)
signal bioma_cargado(id_bioma: int)
signal mensaje(texto: String)
## Acción realizada en el terreno: "disipar", "limpiar", "plantar" o "sanar".
signal accion_terreno(accion: String)
## Una herramienta del terreno no pudo usarse (falta de PR o parcela no válida).
signal accion_rechazada(motivo: String)
## Llegó un animal al refugio (aún sin identificar).
signal fauna_llego(data: EspecieData)
## El jugador tocó un animal que todavía no identifica: se abre la identificación.
signal identificacion_solicitada(data: EspecieData)
## El jugador identificó correctamente un animal del refugio.
signal fauna_identificada(data: EspecieData)
## Cada evaluación del refugio: plantas sanas por nombre normalizado y salud (para las pistas).
signal refugio_evaluado(id_bioma: int, sanas: Dictionary, salud: float)
