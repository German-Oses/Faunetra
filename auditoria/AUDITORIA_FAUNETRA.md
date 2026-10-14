# Auditoría de Faunetra

Fecha: 13 de octubre de 2026. Alcance: código actual del repositorio, catálogo, banco de preguntas, reglas ecológicas, configuración de exportación e informe `Oses-Vllavicencio-INF4556-12_v2.md`.

## Dictamen

Existe un prototipo funcional con una estructura reconocible y contenido suficiente para continuar el desarrollo. El catálogo tiene las 80 fichas comprometidas y el banco contiene 55 trivias. Sin embargo, hay problemas de estabilidad, fidelidad del contenido educativo, integridad del registro y coherencia documental que conviene resolver antes de una evaluación formal. No hay evidencia suficiente en los archivos revisados para afirmar eficacia educativa, cumplimiento de accesibilidad o rendimiento móvil.

La auditoría no cambia el código original ni el informe académico. Las ejecuciones y modificaciones de diagnóstico se hicieron en una copia temporal, con guardado independiente y migración de partidas desactivada. Los archivos de esta carpeta documentan los resultados.

Prioridades: P1 = resolver antes de una evaluación o entrega; P2 = corregir antes de ampliar pruebas; P3 = mantenimiento/editorial. Las prioridades expresan impacto, no una calificación académica.

## Hallazgos prioritarios

### A01 · P1 · Fallo nativo vinculado al ambiente sonoro

**Evidencia:** `autoloads/sonidos.gd:75–88` crea una tarea mediante `WorkerThreadPool` para generar el ambiente y llamar después a `_listo_ambiente`. En Godot 4.7.1, las ejecuciones headless de la copia con recursos ya importados terminan con código 134 y `recursive_mutex lock failed: Invalid argument`. El fallo también ocurre fuera del sandbox. Con un retorno anticipado exclusivamente en `iniciar_ambiente`, la misma escena finaliza con código 0.

**Impacto:** impide certificar estabilidad con la prueba automatizada utilizada. La comparación acota el problema a la ruta de generación del ambiente, pero no identifica todavía su causa exacta ni demuestra que ocurra en Web, Windows o la interfaz gráfica.

**Acción:** reproducir en ejecución interactiva y exportación Web; obtener backtrace; revisar el acceso al autoload desde la tarea, creación de recursos en segundo plano y ciclo de vida de las tareas. Conservar el ID de tarea y gestionar su finalización. No presentar la hipótesis de concurrencia como causa confirmada.

### A02 · P1 · Dos referencias bibliográficas incorrectas, verificadas externamente

**Evidencia:** informe, líneas 1045 y 1090.

- González e Inostroza (2025) se presenta como artículo de revista, con iniciales, volumen y páginas. El [registro oficial de la Universidad de Concepción](https://repositorio.udec.cl/items/03f99b7a-203b-4bc4-a184-2b7244817b07/full) identifica una tesis de Paulina González Salazar y Loreto Inostroza Venegas, con un título más extenso. Corregir autores, título, tipo de documento e institución.
- La revisión de Wäldchen y Mäder se atribuye a PLOS ONE y al DOI `10.1371/journal.pone.0195513`. Ese DOI corresponde a [un artículo sobre señalización ERK](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0195513). La [referencia correcta publicada por Springer](https://link.springer.com/article/10.1007/s11831-016-9206-z) es *Archives of Computational Methods in Engineering*, 25, 507–543, DOI `10.1007/s11831-016-9206-z`.

**Impacto:** debilita la trazabilidad del sustento teórico. Estos errores están confirmados; no implican que todas las referencias sean incorrectas.

**Acción:** revisar cada entrada contra su fuente original y cada afirmación contra el pasaje que la respalda. Las búsquedas de Méndez et al. (2023), del DOI de Vargas et al. y del DOI de descarga GBIF no permitieron confirmar las entradas: clasificarlas como pendientes, no como falsas. En particular, verificar la afirmación «menos del 40%» de la línea 179 antes de conservarla.

### A03 · P1 · Los sonidos sintéticos se presentan como identificación de especies

**Evidencia:** ninguna de las 80 fichas asigna `audio_canto`. `ui/minijuegos/asociacion_acustica.gd:76` usa entonces `SintetizadorFauna.generar`; la instrucción de la línea 80 pide elegir la especie que produce el sonido. El sintetizador modifica tono y ritmo según el ID y asigna categorías por palabras del nombre y rol ecológico.

**Impacto:** la actividad enseña asociaciones diseñadas por el programa que no acreditan reconocimiento de vocalizaciones reales. No debe utilizarse como evidencia de aprendizaje acústico de especies nativas.

**Acción:** incorporar grabaciones verificadas con procedencia y licencia, restringiendo la actividad a especies con audio adecuado; mientras tanto, rotular claramente la actividad como simulación de ambientes o grupos, y evaluar ese objetivo.

### A04 · P1 · Se mezclan extinción y extinción en estado silvestre

**Evidencia:** `ui/tableta/biopedia.gd:490` aplica el mismo mensaje a `EX` y `EW`: afirma que sobreviven en viveros y programas de conservación. La ficha `data/especies/palma_de_rapa_nui.tres` está clasificada `EX`, por lo que recibe ese mensaje. El propio modelo distingue «Extinta» de «Extinta en Estado Silvestre».

**Impacto:** la interfaz contradice su catálogo y enseña una distinción de conservación incorrecta.

**Acción:** separar los textos y las acciones de EX y EW; en EX, explicar la extinción y evitar sugerir observación de ejemplares vivos.

### A05 · P1 · El informe y el producto describen alcances diferentes

**Evidencia:** el objetivo general exige desarrollar un videojuego; RA01 habla de mockups interactivos; la sección 7.8 habla de prototipo visual estático. Los RNF02–04 describen Node.js, PostgreSQL, sincronización y Android/iOS. En el repositorio se observa persistencia JSON local y presets Web, Windows y macOS; no se localizaron implementación de backend ni presets Android/iOS.

**Impacto:** no queda claro qué se debe evaluar ni qué compromisos pertenecen a una fase futura. La ausencia de backend no constituye incumplimiento si RA01 lo excluye de la entrega actual, pero debe aclararse en requisitos y arquitectura.

**Acción:** declarar una fase y un alcance actuales; separar requisitos implementados, parciales y futuros. Reemplazar «frameworks de desarrollo nativo» del objetivo específico móvil por una descripción coherente con Godot si se mantiene ese motor.

### A06 · P1 · La evaluación prevista no demuestra retención a largo plazo

**Evidencia:** sección 7.8.4: reconocimiento de cinco especies, exposición de 20–30 minutos y post-test inmediato. El producto incluye repasos de 1, 3 y 7 días, pero el plan descrito no incorpora medición diferida. En los archivos revisados no se localizaron resultados de participantes ni instrumentos aplicados.

**Impacto:** permite explorar desempeño inmediato; no basta para afirmar consolidación duradera ni atribuir la mejora exclusivamente al juego. Repetir los mismos estímulos puede introducir aprendizaje del test.

**Acción:** definir variable principal, puntuación, formas equivalentes, exposición efectiva y seguimiento diferido. Separar el piloto de usabilidad del estudio de aprendizaje. Justificar el tamaño de muestra según la conclusión buscada; nueve participantes distribuidos en perfiles no son por sí solos evidencia de eficacia.

## Hallazgos de implementación y datos

### A07 · P2 · «Nueva partida» conserva datos internos de la sesión anterior

**Evidencia:** `autoloads/game_state.gd:565` vacía progreso y registro, pero no reinicia `_inicio_sesion_ms` ni limpia `_rapidos_avisados`. La prueba dirigida confirma `reloj_retenido=true` y `avisos_retenidos=true`.

**Impacto:** `t_sesion_s` puede incluir tiempo de la partida anterior; avisos de repaso de especies redescubiertas pueden quedar suprimidos. Afecta especialmente métricas como el tiempo hasta la primera planta.

**Acción:** reiniciar reloj y estado temporal junto con la partida; definir si el código de participante se conserva deliberadamente. Registrar el inicio de la nueva partida.

### A08 · P2 · Guardado sin recuperación y sin validación estructural completa

**Evidencia:** `autoloads/game_state.gd:595` abre el archivo principal directamente en escritura; no mantiene copia anterior. `cargar`, línea 639, comprueba que el JSON raíz sea un diccionario, pero asigna estructuras internas sin validar sus tipos ni usar la versión para migraciones.

**Impacto:** riesgo de pérdida del único guardado ante interrupción durante escritura; un JSON sintácticamente válido pero incompatible puede romper la carga. Es un riesgo identificado por inspección, no una pérdida observada en esta auditoría.

**Acción:** escribir primero un archivo temporal, comprobar el resultado, mantener respaldo y reemplazar el principal; validar esquema y versión antes de cargar. No sobrescribir automáticamente una partida irrecuperable sin conservarla.

### A09 · P2 · Una sinergia definida no puede activarse

**Evidencia:** `data/ecosistema/reglas_ecosistema.json:108` referencia Peumo → Quillay, pero ninguna de las 80 fichas tiene esos nombres. El cruce normalizó tildes y mayúsculas.

**Impacto:** regla inalcanzable en el catálogo actual. Las demás referencias nominales revisadas sí encuentran ficha; esto no valida científicamente las relaciones.

**Acción:** retirar la regla obsoleta o incorporar esas fichas dentro del alcance aprobado. Validar referencias al cargar y preferir IDs estables.

### A10 · P2 · Las preguntas asistidas y evaluativas necesitan distinguirse en el análisis

**Evidencia:** `ui/panel_trivia/panel_trivia.gd:243` muestra nombre común, científico y rol ecológico para especies ya descubiertas en modo ESPECIE. Las preguntas generadas consultan precisamente esos campos. El registro guarda modo y uso de pista, pero no una bandera explícita de ficha visible.

**Impacto:** acertar con la respuesta disponible en pantalla no mide recuperación autónoma. Puede ser una actividad formativa válida; sus aciertos no deben agruparse sin distinción con repasos o pruebas sin apoyo.

**Acción:** documentar la intención y registrar la exposición a ficha/imagen; separar resultados por modo y asistencia. Reservar instrumentos externos o condiciones sin respuestas visibles para evaluar reconocimiento autónomo.

### A11 · P2 · Repasos rápidos y espaciados muestran retroalimentación indistinta

**Evidencia:** `GameState.registrar_repaso` no avanza etapas en el repaso rápido y reprograma un fallo a cuatro minutos. El panel, líneas 298–310, comunica «Validación ... superada» o «próxima sesión» para cualquier modo REPASO.

**Impacto:** un acierto rápido puede anunciar «Validación 0/3 superada»; un fallo rápido informa un plazo diferente al real.

**Acción:** capturar el tipo de repaso antes de responder y presentar textos específicos después de actualizarlo.

### A12 · P2 · Falta trazabilidad científica por ficha y regla

**Evidencia:** `entities/especies/Especie_data.gd` incluye taxonomía, estado y rol, pero no fuente, fecha, autoridad de clasificación o ámbito geográfico. Las reglas ecológicas tampoco aportan referencias por relación. El informe declara estados oficiales vigentes.

**Impacto:** no puede reconstruirse de forma directa por qué cada categoría o relación está en el juego. No se certificó en esta auditoría la exactitud de las 80 taxonomías y estados.

**Acción:** añadir una matriz de respaldo con fuente original, fecha consultada, categoría y ámbito; revisión experta registrada. Distinguir relaciones científicas de simplificaciones de balance del juego.

### A13 · P2 · La importación depende de configuración personal

**Evidencia:** la copia sin `.godot` intentó importar `.aseprite` con una ruta local de Steam. Aseprite abortó en el entorno restringido; fallaron recursos y hubo errores de carga. Al conservar los imports y caché originales se eliminaron esos errores de recursos. Los errores de inferencia de la primera inicialización no se reprodujeron con la caché disponible: no se clasifican como fallos de compilación confirmados del código.

**Impacto:** no está comprobada la reproducción desde un checkout limpio en otro equipo. La limitación del entorno de importación no debe confundirse con archivos fuente inexistentes.

**Acción:** documentar versiones, instalación y configuración de AsepriteWizard; agregar una guía de importación limpia y una comprobación de arranque posterior. Evitar depender de la caché local para demostrar reproducibilidad.

### A14 · P3 · Errores editoriales y referencias teóricas ausentes

**Evidencia:** duplicación de 7.2.4 en líneas 418 y 422; duplicación de 8.3 para base de datos y wireframes; fragmentos cortados en 7.8.4; frase sobrante en 7.2.4; varias cabeceras vacías. Soga y Gaston, Rozzi, Wandersee y Schussler aparecen en el texto y no tienen entradas correspondientes en la bibliografía revisada.

**Impacto:** dificulta lectura y trazabilidad; transmite una edición incompleta.

**Acción:** corregir numeración, índice, fragmentos y correspondencia entre citas y bibliografía; regenerar el índice al cerrar la versión.

## Comprobaciones realizadas

| Comprobación | Resultado |
| --- | --- |
| Fichas `.tres` | 80; sin IDs duplicados |
| Distribución | Zona Central 15; Norte Árido 16; Bosque Templado 17; Patagonia 16; Insular 16 |
| Banco JSON | 55 preguntas; una opción correcta en cada una |
| Integridad banco/catálogo | IDs, nombres y biomas del banco coinciden con fichas |
| Preguntas generadas | 240 combinaciones, 80 × 3 niveles; una correcta y al menos tres opciones en cada una |
| Repaso espaciado fallido | No avanza etapa y bloquea reintento en la misma sesión |
| Siguiente sesión | El repaso fallido vuelve a estar disponible |
| Repaso acertado | Avanza de etapa 0 a 1 |
| Reinicio | Conserva indebidamente reloj y avisos previos |
| Audio real asignado | 0 fichas |
| Ambiente activo | Abort nativo en prueba headless, también fuera del sandbox |
| Ambiente desactivado en copia | Arranque y finalización con código 0 |

Las pruebas dirigidas se ejecutaron con un script SceneTree de auditoría. El log contiene un error de resolución de EventBus asociado a ese modo de carga y un aviso de escena actual nula porque el harness llama a reiniciar sin escena principal; no se interpretan como fallos de esos flujos en el juego normal. Los resultados numéricos son comprobaciones parciales, no aprobación de una suite completa.

No se realizaron pruebas visuales de interfaz, sesiones con usuarios, exportaciones móviles, mediciones de 60 FPS, certificación WCAG ni revisión científica exhaustiva. El cumplimiento de esos puntos queda pendiente de evidencia específica.

## Orden de corrección recomendado

1. Aislar y resolver el fallo de ambiente sonoro; verificar arranque y cierre de las plataformas de entrega.
2. Corregir referencias verificadamente erróneas, distinción EX/EW y presentación del audio sintético.
3. Alinear informe, objetivos, requisitos y alcance con la entrega actual.
4. Corregir reinicio, mensajes de repasos y recuperación de guardado.
5. Completar respaldo científico y condiciones de medición; preparar piloto de usabilidad y evaluación diferida.
6. Documentar importación limpia y cerrar la edición del informe.

El trabajo tiene implementación y contenido concreto. La próxima mejora de mayor valor es hacerlo reproducible, científicamente trazable y evaluable con un alcance consistente.
