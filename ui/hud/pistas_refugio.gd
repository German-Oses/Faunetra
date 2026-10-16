extends VBoxContainer

## Panel «Pistas del refugio»: los próximos visitantes del bioma y qué necesita cada uno
## (plantas sanas y salud mínima), marcando lo que ya se cumple. Convierte las relaciones
## ecológicas en la estrategia del jugador: para atraer al pudú hay que plantar quila y arrayán.
## Se pliega con su botón; en vertical (teléfono) empieza plegado para no tapar el terreno.

const VISITANTES := 3
const RUTA_CHECK := "res://Assets/UI/iconos/check.png"
const COLOR_FALTA := "#8A6A55"
const COLOR_LISTO := "#2E6B3F"

var _boton: Button
var _lista: VBoxContainer
var _panel: PanelContainer
var _ultimo := ""   # firma del contenido mostrado, para no reconstruir si nada cambió


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	_boton = Button.new()
	_boton.icon = TemaFaunetra.icono("lupa")
	_boton.toggle_mode = true
	_boton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_boton.toggled.connect(func(abierto: bool) -> void:
		_panel.visible = abierto
		_actualizar_texto_boton())
	add_child(_boton)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TemaFaunetra.caja(Color(TemaFaunetra.CREMA, 0.94), TemaFaunetra.VERDE, 12, 2, 8))
	_panel.custom_minimum_size.x = 270
	add_child(_panel)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	_panel.add_child(_lista)

	EventBus.refugio_evaluado.connect(_on_refugio_evaluado)
	EventBus.bioma_cargado.connect(func(_id: int) -> void: _ultimo = "")
	Pantalla.orientacion_cambiada.connect(func(_v: bool) -> void: _reacomodar())
	_reacomodar()


func _reacomodar() -> void:
	_boton.set_pressed_no_signal(not Pantalla.vertical)
	_panel.visible = _boton.button_pressed
	_actualizar_texto_boton()


func _actualizar_texto_boton() -> void:
	_boton.text = "Pistas" if _boton.button_pressed else "Pistas del refugio"


func _on_refugio_evaluado(id_bioma: int, sanas: Dictionary, salud: float) -> void:
	var presentes: Array = GameState.estado_bioma(id_bioma).get("fauna", [])
	# Primero los que están más cerca de llegar: menos salud exigida y más requisitos cumplidos.
	var candidatos: Array[EspecieData] = []
	for animal in EspecieLoader.fauna_del_bioma(id_bioma):
		if not presentes.has(animal.id_especie):
			candidatos.append(animal)
	candidatos.sort_custom(func(a: EspecieData, b: EspecieData) -> bool:
		return _cercania(a, sanas, salud) > _cercania(b, sanas, salud))
	var proximos: Array[EspecieData] = candidatos.slice(0, VISITANTES)
	var firma := "%s|%s|%d" % [str(proximos.map(func(a: EspecieData) -> int: return a.id_especie)), str(sanas), int(salud)]
	if firma == _ultimo:
		return
	_ultimo = firma
	for hijo in _lista.get_children():
		hijo.queue_free()
	var titulo := Label.new()
	titulo.text = "Próximos visitantes"
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", TemaFaunetra.VERDE)
	_lista.add_child(titulo)
	if proximos.is_empty():
		var listo := Label.new()
		listo.text = "¡Toda la fauna del bioma ya visita tu refugio!"
		listo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		listo.add_theme_font_size_override("font_size", 13)
		_lista.add_child(listo)
		return
	for animal in proximos:
		_lista.add_child(_fila(animal, sanas, salud))


## 0..1: fracción de plantas pedidas que ya crecen sanas, descontando la salud que falta.
func _cercania(animal: EspecieData, sanas: Dictionary, salud: float) -> float:
	var req := ReglasEcosistema.requisitos_fauna(animal)
	var plantas: Array = req["plantas"]
	var listas := 0
	for nombre in plantas:
		if sanas.has(ReglasEcosistema.normalizar(nombre)):
			listas += 1
	var fraccion := float(listas) / plantas.size() if not plantas.is_empty() else 0.5
	return fraccion - maxf(0.0, float(req["min_salud"]) - salud) / 100.0


func _fila(animal: EspecieData, sanas: Dictionary, salud: float) -> Control:
	var conocida: bool = GameState.esta_descubierta(animal.id_especie)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var icono := TextureRect.new()
	icono.texture = EspecieLoader.textura_de(animal)
	icono.custom_minimum_size = Vector2(34, 34)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not conocida:
		icono.modulate = Color(0.16, 0.2, 0.17, 0.85)   # silueta, como en la Biopedia
	fila.add_child(icono)

	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.add_theme_font_size_override("normal_font_size", 12)
	texto.add_theme_font_size_override("bold_font_size", 13)
	var req := ReglasEcosistema.requisitos_fauna(animal)
	var partes: Array[String] = []
	for nombre in req["plantas"]:
		partes.append(_requisito(nombre, sanas.has(ReglasEcosistema.normalizar(nombre))))
	if (req["plantas"] as Array).is_empty() and int(req["min_sanas"]) > 0:
		var total := 0
		for n in sanas.values():
			total += int(n)
		partes.append(_requisito("%d plantas sanas (%d)" % [int(req["min_sanas"]), total], total >= int(req["min_sanas"])))
	if float(req["min_salud"]) > 0.0:
		partes.append(_requisito("salud %d%%" % int(req["min_salud"]), salud >= float(req["min_salud"])))
	texto.text = "[b]%s[/b]\n%s" % [animal.nombre_comun if conocida else "Visitante por descubrir", " · ".join(PackedStringArray(partes))]
	fila.add_child(texto)
	return fila


func _requisito(texto: String, cumplido: bool) -> String:
	if cumplido:
		return "[img=12x12]%s[/img] [color=%s]%s[/color]" % [RUTA_CHECK, COLOR_LISTO, texto]
	return "[color=%s]%s[/color]" % [COLOR_FALTA, texto]
