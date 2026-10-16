extends Control

## Identificación de un animal que llegó al refugio: el jugador lo observa y elige su nombre
## entre varias fichas. Reconocer la especie es lo que la registra en la Biopedia y da PR,
## así que el conocimiento es la forma de avanzar y no un peaje aparte (ver Habgood y
## Ainsworth, 2011, sobre integración intrínseca).
## - Las opciones incorrectas son otros animales, de preferencia del mismo bioma y grupo; su
##   cantidad la fija el modo de juego (ajuste "distractores").
## - Fallar no castiga: la ficha errada se descarta y se puede volver a intentar (con menos PR).
##   El primer error solo invita a observar de nuevo; desde el segundo aparece una pista
##   ecológica, que a veces delata bastante la respuesta. Cada intento queda en el registro.

const PR_PRIMER_INTENTO := 15
const PR_SIGUIENTES := 8
## Errores necesarios antes de mostrar la pista ecológica.
const ERRORES_PARA_PISTA := 2

var _data: EspecieData
var _intentos := 0
var _inicio_ms := 0
var _resuelta := false

var _imagen: TextureRect
var _texto: Label
var _pista: Label
var _opciones: GridContainer
var _resultado: RichTextLabel
var _continuar: Button
var _mas_tarde: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = TemaFaunetra.obtener()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TemaFaunetra.caja(TemaFaunetra.CREMA, TemaFaunetra.VERDE, 14, 3, 16))
	centro.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)

	var titulo := Label.new()
	titulo.text = "¿Quién llegó a tu refugio?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	columna.add_child(titulo)

	var marco := PanelContainer.new()
	marco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	marco.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color.WHITE, TemaFaunetra.BORDE, 12, 2, 8))
	columna.add_child(marco)
	_imagen = TextureRect.new()
	_imagen.custom_minimum_size = Vector2(150, 150)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marco.add_child(_imagen)

	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 14)
	columna.add_child(_texto)

	_opciones = GridContainer.new()
	_opciones.add_theme_constant_override("h_separation", 8)
	_opciones.add_theme_constant_override("v_separation", 8)
	columna.add_child(_opciones)

	_pista = Label.new()
	_pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pista.add_theme_font_size_override("font_size", 13)
	_pista.add_theme_color_override("font_color", TemaFaunetra.TEXTO_SUAVE)
	columna.add_child(_pista)

	_resultado = RichTextLabel.new()
	_resultado.bbcode_enabled = true
	_resultado.fit_content = true
	_resultado.add_theme_font_size_override("normal_font_size", 14)
	columna.add_child(_resultado)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 10)
	columna.add_child(botones)
	_mas_tarde = Button.new()
	_mas_tarde.text = "Más tarde"
	_mas_tarde.flat = true
	_mas_tarde.pressed.connect(_cerrar)
	botones.add_child(_mas_tarde)
	_continuar = Button.new()
	_continuar.text = "Continuar"
	_continuar.custom_minimum_size = Vector2(140, 38)
	_continuar.pressed.connect(_cerrar)
	botones.add_child(_continuar)

	EventBus.identificacion_solicitada.connect(abrir)
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _ajustar_ancho())
	hide()


func abrir(data: EspecieData) -> void:
	_data = data
	_intentos = 0
	_resuelta = false
	_inicio_ms = Time.get_ticks_msec()
	_imagen.texture = EspecieLoader.textura_de(data)
	_texto.text = "Observa al visitante y elige su nombre. Identificarlo lo registra en tu Biopedia (+%d PR)." % PR_PRIMER_INTENTO
	_pista.text = ""
	_pista.visible = false
	_resultado.text = ""
	_resultado.visible = false
	_continuar.visible = false
	_mas_tarde.visible = true
	for hijo in _opciones.get_children():
		hijo.queue_free()
	for opcion in _elegir_opciones(data):
		var b := Button.new()
		b.text = opcion.nombre_comun
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		TemaFaunetra.estilizar_chip(b)
		b.pressed.connect(_on_opcion.bind(opcion, b))
		_opciones.add_child(b)
	_ajustar_ancho()
	show()
	move_to_front()


func _ajustar_ancho() -> void:
	_opciones.columns = 1 if Pantalla.vertical else 2
	for nodo in [_texto, _pista, _resultado]:
		(nodo as Control).custom_minimum_size.x = 320 if Pantalla.vertical else 460


## La especie correcta más los distractores: primero animales del mismo bioma y grupo
## (lo más parecido es lo que obliga a observar), luego del mismo bioma y al final de otros.
func _elegir_opciones(data: EspecieData) -> Array[EspecieData]:
	var cantidad := int(GameState.ajuste("distractores"))
	var grupo := SintetizadorFauna.categoria(data)
	var candidatas: Array[EspecieData] = []
	var mismo_bioma := EspecieLoader.fauna_del_bioma(data.id_bioma).filter(func(d: EspecieData) -> bool: return d != data)
	mismo_bioma.shuffle()
	mismo_bioma.sort_custom(func(a: EspecieData, b: EspecieData) -> bool:
		return SintetizadorFauna.categoria(a) == grupo and SintetizadorFauna.categoria(b) != grupo)
	candidatas.append_array(mismo_bioma)
	var resto := EspecieLoader.toda_la_fauna().filter(func(d: EspecieData) -> bool: return d.id_bioma != data.id_bioma)
	resto.shuffle()
	candidatas.append_array(resto)
	var opciones: Array[EspecieData] = [data]
	opciones.append_array(candidatas.slice(0, cantidad))
	opciones.shuffle()
	return opciones


func _on_opcion(elegida: EspecieData, boton: Button) -> void:
	if _resuelta:
		return
	_intentos += 1
	var correcta := elegida == _data
	var pr := 0
	if correcta:
		_resuelta = true
		pr = PR_PRIMER_INTENTO if _intentos == 1 else PR_SIGUIENTES
	GameState.registrar({"tipo": "identificacion", "id_especie": _data.id_especie, "especie": _data.nombre_comun,
		"id_bioma": _data.id_bioma, "correcta": correcta,
		"tiempo_s": snappedf((Time.get_ticks_msec() - _inicio_ms) / 1000.0, 0.1), "pr": pr,
		"detalle": "intento=%d;eligio=%s" % [_intentos, elegida.nombre_comun]})
	if not correcta:
		Sonidos.reproducir("incorrecta")
		boton.disabled = true
		boton.add_theme_stylebox_override("disabled", TemaFaunetra.caja(Color("#F6D8CF"), Color("#C8463A"), 12, 2, 6))
		if _intentos >= ERRORES_PARA_PISTA:
			_pista.text = "No es %s. Pista: %s" % [elegida.nombre_comun, _primera_oracion(_data.rol_ecologico)]
		else:
			_pista.text = "No es %s. Observa de nuevo su forma y sus colores." % elegida.nombre_comun
		_pista.visible = true
		return

	Sonidos.reproducir("correcta")
	for b in _opciones.get_children():
		(b as Button).disabled = true
	boton.add_theme_stylebox_override("disabled", TemaFaunetra.caja(TemaFaunetra.VERDE_CLARO, TemaFaunetra.VERDE, 12, 3, 6))
	GameState.agregar_pr(pr, _data.id_bioma)
	var nueva: bool = GameState.descubrir_especie(_data)
	EventBus.fauna_identificada.emit(_data)
	_pista.visible = false
	_resultado.visible = true
	_resultado.text = "[b]¡Es %s![/b] [i](%s)[/i] · %s\n%s\n[color=#2E6B3F]+%d PR%s[/color]" % [
		_data.nombre_comun, _data.nombre_cientifico, EspecieData.NOMBRES_ESTADO.get(_data.estado_conservacion, ""),
		_data.rol_ecologico, pr, " · Nueva entrada en la Biopedia" if nueva else ""]
	_continuar.visible = true
	_mas_tarde.visible = false
	_continuar.grab_focus.call_deferred()


func _primera_oracion(texto: String) -> String:
	var fin := texto.find(". ")
	return texto if fin < 0 else texto.substr(0, fin + 1)


func _cerrar() -> void:
	if not _resuelta and _data:
		GameState.registrar({"tipo": "identificacion_pospuesta", "id_especie": _data.id_especie,
			"especie": _data.nombre_comun, "id_bioma": _data.id_bioma, "detalle": "intentos=%d" % _intentos})
	hide()
