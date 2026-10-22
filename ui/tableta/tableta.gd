extends VentanaModal

## Tableta de Campo del Guardián: Biopedia, trivias (fuente principal de PR),
## repasos de validación espaciada, el Escáner de Especies (Lente Ancestral) y la pestaña Juegos
## (Paisaje Sonoro, Rompecabezas y Memorice).

enum Pestana { BIOPEDIA, TRIVIAS, REPASOS, LENTE, JUEGOS }

const Biopedia := preload("res://ui/tableta/biopedia.gd")
const EscanerEspecies := preload("res://ui/minijuegos/escaner_especies.gd")
const Juegos := preload("res://ui/minijuegos/juegos.gd")

var _tabs: TabContainer
var _biopedia: Biopedia
var _escaner: EscanerEspecies
var _juegos: Juegos
var _estado_tutor: Label
var _lista_repasos: VBoxContainer


func _ready() -> void:
	set_titulo("Tableta de Campo del Guardián")
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_on_tab_changed)
	contenido.add_child(_tabs)

	_biopedia = Biopedia.new()
	_biopedia.name = "Biopedia"
	_tabs.add_child(_biopedia)
	_tabs.add_child(_construir_trivias())
	_tabs.add_child(_construir_repasos())
	_escaner = EscanerEspecies.new()
	_escaner.name = "Escáner de Especies"
	_escaner.abrir_puzzle_acustico.connect(func() -> void:
		_tabs.current_tab = Pestana.JUEGOS
		_juegos.mostrar(Juegos.Juego.SONIDO))
	_tabs.add_child(_escaner)
	_juegos = Juegos.new()
	_tabs.add_child(_juegos)

	GameState.repasos_actualizados.connect(_on_repasos_actualizados)
	Pantalla.orientacion_cambiada.connect(_titular_pestanas)
	_titular_pestanas(Pantalla.vertical)


## En vertical (480 px lógicos) los nombres largos se acortan para que las cinco pestañas
## quepan sin flechas de desplazamiento.
func _titular_pestanas(vertical: bool) -> void:
	_tabs.set_tab_title(Pestana.LENTE, "Escáner" if vertical else "Escáner de Especies")
	_tabs.set_tab_title(Pestana.JUEGOS, "Juegos")


func abrir(pestana: Pestana = Pestana.BIOPEDIA) -> void:
	show()
	if _tabs.current_tab == pestana:
		_on_tab_changed(pestana)
	else:
		_tabs.current_tab = pestana


func _on_tab_changed(indice: int) -> void:
	if not visible:
		return
	match indice:
		Pestana.BIOPEDIA:
			_biopedia.refrescar()
		Pestana.TRIVIAS:
			_refrescar_tutor()
		Pestana.REPASOS:
			_refrescar_repasos()
		Pestana.LENTE:
			_escaner.al_mostrar()
		Pestana.JUEGOS:
			_juegos.al_mostrar()


func _on_repasos_actualizados() -> void:
	if visible and _tabs.current_tab == Pestana.REPASOS:
		_refrescar_repasos()


# --- Trivias ---------------------------------------------------------------------------

func _construir_trivias() -> Control:
	var caja := VBoxContainer.new()
	caja.name = "Trivias"
	caja.add_theme_constant_override("separation", 12)

	var texto := Label.new()
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.text = "Aprender genera Esencia Vital. Cada trivia correcta suma Puntos de Restauración (PR) al bioma en el que estás; con ellos disipas la niebla, limpias el terreno y plantas especies nativas. Fallar nunca resta PR."
	caja.add_child(texto)

	var boton := Button.new()
	boton.text = "Comenzar trivia del bioma"
	boton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	boton.pressed.connect(_lanzar_trivia.bind("bioma", 0))
	caja.add_child(boton)

	_estado_tutor = Label.new()
	_estado_tutor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_estado_tutor)
	return caja


func _refrescar_tutor() -> void:
	var nivel: String = TriviaManager.NOMBRES_DIFICULTAD[TriviaManager.nivel_actual_jugador]
	var lineas: Array[String] = [
		"Nivel adaptativo actual: %s" % nivel,
		"Trivias respondidas: %d · XP Biodiversidad: %d · Insignias: %d" % [
			TriviaManager.total_trivias_respondidas, TriviaManager.xp_acumulada, TriviaManager.insignias_desbloqueadas.size()],
	]
	for categoria in ["flora", "fauna"]:
		var reg: Dictionary = TriviaManager.desempeno_por_categoria.get(categoria, {})
		lineas.append("Preguntas de %s: %d aciertos, %d errores" % [categoria, int(reg.get("aciertos", 0)), int(reg.get("errores", 0))])
	if TriviaManager.necesita_apoyo():
		lineas.append("\nEl tutor notó algunas dificultades: te ofrecerá preguntas más sencillas, pistas e imágenes de referencia.")
	elif TriviaManager.nivel_actual_jugador == TriviaData.Dificultad.DIFICIL:
		lineas.append("\nDemuestras dominio: las preguntas abordan roles ecológicos y relaciones tróficas.")
	_estado_tutor.text = "\n".join(PackedStringArray(lineas))


func _lanzar_trivia(modo: String, id_especie: int) -> void:
	hide()
	EventBus.solicitar_trivia.emit(modo, id_especie)


# --- Repasos (repetición espaciada) ----------------------------------------------------------

func _construir_repasos() -> Control:
	var caja := VBoxContainer.new()
	caja.name = "Repasos"
	var texto := Label.new()
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.text = "Para que lo aprendido perdure, cada especie descubierta tiene un repaso rápido a los pocos minutos y luego se valida a las 24 horas, a los 3 días y a los 7 días de su primer avistamiento. Si fallas, no pierdes nada: el repaso vuelve más adelante."
	caja.add_child(texto)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	_lista_repasos = VBoxContainer.new()
	_lista_repasos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista_repasos)
	return caja


func _refrescar_repasos() -> void:
	for hijo in _lista_repasos.get_children():
		hijo.queue_free()

	var pendientes: Array[int] = GameState.repasos_pendientes()
	_agregar_titulo("Repasos disponibles (%d)" % pendientes.size())
	if pendientes.is_empty():
		_agregar_texto("No tienes repasos pendientes ahora mismo.")
	for id in pendientes:
		var data := EspecieLoader.por_id(id)
		if data == null:
			continue
		var fila := HBoxContainer.new()
		var etiqueta := Label.new()
		if GameState.es_repaso_rapido(id):
			etiqueta.text = "%s — repaso rápido" % data.nombre_comun
		else:
			etiqueta.text = "%s — validación %d/%d" % [data.nombre_comun, GameState.etapa_validacion(id) + 1, GameState.INTERVALOS_REPASO_DIAS.size()]
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var boton := Button.new()
		boton.text = "Repasar (+%d PR extra)" % TriviaManager.PR_BONO_REPASO
		boton.pressed.connect(_lanzar_trivia.bind("repaso", id))
		fila.add_child(boton)
		_lista_repasos.add_child(fila)

	_agregar_titulo("\nPróximas validaciones")
	var hay_proximas := false
	for clave in GameState.validaciones:
		var id := int(clave)
		var etapa: int = GameState.etapa_validacion(id)
		var data := EspecieLoader.por_id(id)
		if data == null or pendientes.has(id):
			continue
		hay_proximas = true
		if etapa >= GameState.INTERVALOS_REPASO_DIAS.size():
			_agregar_texto("%s — conocimiento consolidado (3/3)" % data.nombre_comun)
		else:
			_agregar_texto("%s — validación %d/%d: %s" % [data.nombre_comun, etapa + 1,
				GameState.INTERVALOS_REPASO_DIAS.size(), _cuando(GameState.proximo_repaso(id))])
	if not hay_proximas:
		_agregar_texto("Descubre especies para programar sus validaciones.")


func _cuando(timestamp: float) -> String:
	var faltan := timestamp - Time.get_unix_time_from_system()
	if faltan <= 0.0:
		return "en tu próxima sesión"
	var horas := int(ceil(faltan / 3600.0))
	if horas < 24:
		return "en %d h" % horas
	return "en %d días" % int(ceil(faltan / GameState.SEGUNDOS_DIA))


func _agregar_titulo(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 17)
	_lista_repasos.add_child(l)


func _agregar_texto(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lista_repasos.add_child(l)
