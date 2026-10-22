extends VBoxContainer

## Memorice de especies: cartas boca abajo con parejas «imagen de la especie ↔ su nombre». Se
## dan vuelta dos por turno; si forman pareja quedan descubiertas. En modo Científico la pareja de
## la imagen es el nombre científico. Explorador juega con 4 parejas; los demás modos, con 6.
##
## Recompensa: la primera partida ganada en la sesión da RECOMPENSA_PR; las siguientes,
## RECOMPENSA_REPETIDA (para que sea un repaso y no una fuente infinita de PR).

const PAREJAS_POR_MODO := {"explorador": 4, "guardaparques": 6, "cientifico": 6}
const RECOMPENSA_PR := 30
const RECOMPENSA_REPETIDA := 5
const ESPERA_ERROR := 0.9   ## segundos que se ven dos cartas que no son pareja antes de voltearse

var _instrucciones: Label
var _tablero: GridContainer
var _resultado: Label
## Cartas: {"especie": EspecieData, "imagen": bool, "boton": Button, "descubierta": bool}
var _cartas: Array[Dictionary] = []
var _volteadas: Array[int] = []
var _bloqueado := false
var _intentos := 0
var _encontradas := 0
var _parejas := 6
var _terminado := false
var _inicio_ms := 0
var _cientifico := false
var _ganadas_en_sesion := 0


func _ready() -> void:
	name = "Memorice"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_instrucciones = Label.new()
	_instrucciones.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_instrucciones)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_tablero = GridContainer.new()
	_tablero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tablero.add_theme_constant_override("h_separation", 6)
	_tablero.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_tablero)

	_resultado = Label.new()
	_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_resultado)

	var nuevo := Button.new()
	nuevo.text = "Nueva partida"
	nuevo.size_flags_horizontal = Control.SIZE_SHRINK_END
	nuevo.pressed.connect(nueva_ronda)
	add_child(nuevo)
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _ajustar_columnas())


## Al abrir: conserva la partida en curso y solo reparte otra si no hay una pendiente.
func al_mostrar() -> void:
	if _cartas.is_empty() or _terminado:
		nueva_ronda()


func nueva_ronda() -> void:
	for hijo in _tablero.get_children():
		_tablero.remove_child(hijo)
		hijo.queue_free()
	_cartas.clear()
	_volteadas.clear()
	_bloqueado = false
	_intentos = 0
	_encontradas = 0
	_terminado = false
	_resultado.text = ""
	_cientifico = GameState.modo == "cientifico"
	_parejas = PAREJAS_POR_MODO.get(GameState.modo, 6)

	var id_bioma := GameState.bioma_actual_id if GameState.bioma_actual_id > 0 else GameState.ORDEN_BIOMAS[0]
	var especies := EspecieLoader.cargar_especies_del_bioma(id_bioma).filter(
		func(d: EspecieData) -> bool: return EspecieLoader.textura_de(d) != null)
	especies.shuffle()
	especies = especies.slice(0, _parejas)
	_parejas = especies.size()
	if _parejas < 2:
		_instrucciones.text = "Este bioma todavía no tiene suficientes especies con imagen."
		return
	for d in especies:
		_cartas.append({"especie": d, "imagen": true, "descubierta": false})
		_cartas.append({"especie": d, "imagen": false, "descubierta": false})
	_cartas.shuffle()
	for i in _cartas.size():
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(0, 96)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.expand_icon = true
		boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boton.add_theme_font_size_override("font_size", 13)
		boton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		boton.clip_text = true
		# Texto oscuro sobre la carta crema (el tema de los botones usa texto claro sobre verde).
		for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			boton.add_theme_color_override(estado, TemaFaunetra.TEXTO)
		boton.pressed.connect(_on_carta.bind(i))
		_tablero.add_child(boton)
		_cartas[i]["boton"] = boton
		_mostrar(i, false)
	_ajustar_columnas()
	_instrucciones.text = "Encuentra las %d parejas: cada especie con su %s. Da vuelta dos cartas por turno. (+%d PR al ganar)" % [
		_parejas, "nombre científico" if _cientifico else "nombre", RECOMPENSA_PR if _ganadas_en_sesion == 0 else RECOMPENSA_REPETIDA]
	_inicio_ms = Time.get_ticks_msec()


func _ajustar_columnas() -> void:
	var n := _cartas.size()
	if Pantalla.vertical:
		_tablero.columns = 3 if n <= 9 or n % 3 == 0 else 4
	else:
		_tablero.columns = 4 if n <= 8 else 6


## Muestra la carta boca arriba (imagen o nombre) o boca abajo.
func _mostrar(i: int, arriba: bool) -> void:
	var carta := _cartas[i]
	var boton: Button = carta["boton"]
	var d: EspecieData = carta["especie"]
	if not arriba:
		boton.icon = TemaFaunetra.icono("hoja")
		boton.text = ""
		boton.add_theme_stylebox_override("normal", TemaFaunetra.caja(TemaFaunetra.VERDE, TemaFaunetra.VERDE_PRESIONADO, 10, 2, 6))
		boton.add_theme_stylebox_override("hover", TemaFaunetra.caja(TemaFaunetra.VERDE_HOVER, TemaFaunetra.VERDE_PRESIONADO, 10, 2, 6))
		return
	var fondo := TemaFaunetra.VERDE_CLARO if carta["descubierta"] else TemaFaunetra.CREMA
	boton.add_theme_stylebox_override("normal", TemaFaunetra.caja(fondo, TemaFaunetra.BORDE, 10, 2, 6))
	boton.add_theme_stylebox_override("hover", TemaFaunetra.caja(fondo, TemaFaunetra.BORDE, 10, 2, 6))
	if carta["imagen"]:
		boton.icon = EspecieLoader.textura_de(d)
		boton.text = ""
	else:
		boton.icon = null
		boton.text = d.nombre_cientifico if _cientifico else d.nombre_comun


func _on_carta(i: int) -> void:
	if _bloqueado or _terminado or _cartas[i]["descubierta"] or _volteadas.has(i):
		return
	_volteadas.append(i)
	_mostrar(i, true)
	Sonidos.reproducir("clic")
	if _volteadas.size() < 2:
		return
	_intentos += 1
	var a := _cartas[_volteadas[0]]
	var b := _cartas[_volteadas[1]]
	if a["especie"] == b["especie"] and a["imagen"] != b["imagen"]:
		a["descubierta"] = true
		b["descubierta"] = true
		_mostrar(_volteadas[0], true)
		_mostrar(_volteadas[1], true)
		_volteadas.clear()
		_encontradas += 1
		Sonidos.reproducir("correcta")
		var d: EspecieData = a["especie"]
		_resultado.text = "¡Pareja! %s (%s): %s" % [d.nombre_comun, d.nombre_cientifico, d.rol_ecologico]
		if _encontradas == _parejas:
			_ganar()
		return
	_bloqueado = true
	await get_tree().create_timer(ESPERA_ERROR).timeout
	if not is_inside_tree() or _volteadas.size() < 2:
		_bloqueado = false
		return
	for j in _volteadas:
		if j < _cartas.size():
			_mostrar(j, false)
	_volteadas.clear()
	_bloqueado = false


func _ganar() -> void:
	_terminado = true
	var pr := RECOMPENSA_PR if _ganadas_en_sesion == 0 else RECOMPENSA_REPETIDA
	_ganadas_en_sesion += 1
	GameState.agregar_pr(pr)
	var nombres := PackedStringArray()
	for c in _cartas:
		if c["imagen"]:
			nombres.append((c["especie"] as EspecieData).nombre_comun)
	GameState.registrar({"tipo": "memorice", "correcta": true, "pr": pr,
		"tiempo_s": snappedf((Time.get_ticks_msec() - _inicio_ms) / 1000.0, 0.1),
		"detalle": "parejas=%d;intentos=%d;nombres=%s;especies=%s" % [
			_parejas, _intentos, "cientifico" if _cientifico else "comun", "|".join(nombres)]})
	Sonidos.reproducir("desbloquear")
	_resultado.text = "¡Encontraste las %d parejas en %d intentos! +%d PR." % [_parejas, _intentos, pr]
