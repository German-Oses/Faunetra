# Segunda auditoría de Faunetra

**Fecha:** 16 de octubre de 2026. **Revisión:** `4a9b6ea1a73d78f4d01060bbe7f690d34f588fbb`.

## Dictamen

El código incorpora correcciones materiales respecto al 13 de octubre: seis hallazgos anteriores se consideran corregidos dentro del alcance revisado y dos están parcialmente resueltos. La prueba headless de arranque y cierre ya termina correctamente con el ambiente activo. Sin embargo, se confirmó una pérdida de progreso del gestor de trivias al volver a abrir una partida y una clasificación incorrecta de organismos utilizada por el sistema acústico. Son las prioridades antes de evaluar el prototipo con usuarios.

Se emplearon tres agentes en paralelo: código/persistencia, contenido educativo y documentación. La revisión principal ejecutó Godot 4.7.1 sobre una copia temporal con el guardado y respaldo dirigidos a archivos de prueba. No se modificó código de producción ni partidas del usuario. Se conservó la caché de importación del proyecto: esto no equivale a validar instalación limpia.

## 1. Hallazgos nuevos y residuales reproducidos

### N01 · P1 · Se pierde el progreso de TriviaManager al reabrir

**Ubicación:** `autoloads/game_state.gd:127–134,610–613`; `autoloads/trivia_manager.gd:40–42`.

**Reproducción:** se preparó un guardado válido con nivel 2, 77 respuestas y 12.345 XP. Se abrió normalmente durante 15 frames y se inspeccionó el JSON persistido. La salida fue código 0, pero los XP quedaron en 0. El motor no reporta este fallo como error de script.

**Causa:** GameState carga el snapshot y guarda antes de que TriviaManager ejecute su `_ready`. El nodo de TriviaManager ya existe; `guardar()` exporta sus valores iniciales, reemplaza `datos_trivia` y luego TriviaManager importa ese estado vacío. Afecta XP, total, nivel, rachas, insignias y desempeño del tutor.

**Control de diagnóstico:** en la copia, diferir exclusivamente el primer guardado conserva nivel 2, total 77, XP 12345 y una insignia de prueba. Este cambio se revirtió en la copia después del diagnóstico; no se aplicó al repositorio.

**Recomendación:** exportar TriviaManager únicamente después de su inicialización (`is_node_ready()` o bandera posterior a `importar`); hasta entonces conservar el snapshot cargado. Verificar dos reaperturas con valores distintivos de todos sus campos. No invertir simplemente los autoloads, porque TriviaManager necesita el GameState cargado.

**Evidencia:** `persistencia_dda.log`, `pruebas_guardados.json`, `diagnostico_orden_inicio.json`.

### N02 · P1 · El sistema acústico clasifica especies por fragmentos de texto

**Ubicación:** `ui/minijuegos/sintetizador_fauna.gd:25–38,76–80`; consumidores en `asociacion_acustica.gd:114–120` e `identificacion_fauna.gd:150–155`.

El algoritmo busca subcadenas en el nombre y en el rol ecológico, incluyendo descripciones de presas. El orden de las condiciones puede asignar un grupo ajeno al organismo. El cruce literal del algoritmo con las fichas arroja:

| Especie | Grupo obtenido | Coincidencia que lo causa |
| --- | --- | --- |
| Gato montés argentino | ave | El rol menciona aves pequeñas |
| Mosca florícola valdiviana | ave | «clave » contiene «ave » |
| Guanaco norteño | ave | «través » normalizado contiene «ave » |
| Pancora patagónica | ave | El rol menciona aves |
| Chinchilla cordillerana | anfibio | «cordillerana» contiene «rana» |
| Araña de Hualpén | anfibio | «araña» normalizado contiene «rana» |
| Seudoescorpión insular | insecto | El rol menciona sus presas |

**Impacto:** selecciona sonidos y explicaciones incorrectas y altera la selección de distractores. Rotular el audio como simulado no corrige el grupo biológico equivocado.

**Recomendación:** definir un grupo explícito por ficha, revisado, sin deducirlo de textos libres ni de las presas mencionadas. Añadir casos de regresión para estas especies.

### N03 · P2 · Un JSON válido con celdas inválidas evita la recuperación

**Ubicación:** `autoloads/game_state.gd:695–705,761–763`.

**Reproducción:** principal con `{"version":1,"biomas":{"3":{"celdas":{"0,0":null}}}}` y respaldo válido. La raíz pasa la validación, pero `cargar()` intenta asignar null a Dictionary y produce error en la línea 762. No utiliza el respaldo por este fallo estructural. El proceso puede terminar con código 0 pese al error: debe inspeccionarse el log.

**Recomendación:** validar estructuras anidadas antes de mutar el estado activo; decidir si se rechaza el archivo y recupera respaldo o se sanea con una regla explícita. Revisar también los tipos de `fauna_identificada` y los datos internos importados por TriviaManager. Es un residual de A08, cuya escritura temporal y respaldo sí mejoraron.

**Evidencia:** `celda_invalida.log` y `pruebas_guardados.json`.

### N04 · P2 · Una partida de versión futura se sobrescribe como versión 1

**Ubicación:** `autoloads/game_state.gd:706–707,134,615–635`.

**Reproducción:** guardado con `version:2` y `campo_futuro`. Al abrir, se emite una advertencia, pero el archivo principal se reescribe con versión 1 y pierde el campo desconocido.

**Recomendación:** ante versión superior, preservar el archivo y bloquear escritura o rechazar la carga de manera controlada. Una advertencia no evita degradar el formato. Actualmente VERSION_GUARDADO es 1; este problema afecta compatibilidad con una versión posterior, no todas las partidas actuales.

**Evidencia:** `version_futura.log` y `pruebas_guardados.json`.

## 2. Seguimiento de la auditoría anterior

| ID | Estado actual | Evidencia y alcance |
| --- | --- | --- |
| A01 · fallo sonoro | Corregido en prueba realizada | La tarea tiene ID y espera al salir, `sonidos.gd:91–121`; arranque/cierre headless con ambiente activo termina 0 |
| A02 · bibliografía | Pendiente | Informe 1045/1090 conserva las dos referencias incorrectas, recontrastadas con fuentes originales |
| A03 · simulación acústica | Parcial | `asociacion_acustica.gd:94–101` ahora informa sonido simulado y registra tipo; escáner 279–280/382–387 no lo rotula igual; informe 415 aún promete sonidos reales; además N02 |
| A04 · EX/EW | Corregido por inspección | `biopedia.gd:494–507` separa estados y EX evita acciones de avistamiento |
| A05 · alcance/arquitectura | Pendiente | Informe describe mockups estáticos y también aplicación móvil con backend; no distingue fases |
| A06 · evaluación | Pendiente | Plan inmediato de cinco especies sin instrumentos/resultados localizados en repo; necesita delimitación de conclusiones |
| A07 · reinicio | Corregido y probado | Reloj, avisos y evento nueva_partida comprobados |
| A08 · guardado | Parcial | Temporal, respaldo y recuperación de JSON ilegible pasan; N03 muestra validación interna incompleta |
| A09 · sinergia ausente | Corregido | Palma chilena → Orquídea reemplaza referencias ausentes; cruce de referencias pasa |
| A10 · asistencia en medición | Corregido en instrumentación | Ficha e imagen visibles se registran/exportan; separar condiciones en análisis sigue siendo necesario |
| A11 · mensajes de repasos | Corregido por inspección | Captura tipo antes de mutarlo y distingue rápido/espaciado, panel 300–318 |
| A12 · fuentes por ficha | Pendiente | Modelo sin fuente/fecha/autoridad/ámbito; relaciones sin citas por regla |
| A13 · instalación limpia | Pendiente de verificación | No se localizó guía completa; esta ejecución conserva caché y no certifica importación limpia |
| A14 · edición | Pendiente | Numeración repetida, párrafos truncados y citas sin entradas continúan |

Los seis cierres corresponden a A01, A04, A07, A09, A10 y A11. No equivalen a certificación de todas las plataformas o condiciones de uso.

## 3. Observaciones académicas que permanecen

- **Referencias:** González e Inostroza (informe 1045) figura como artículo con datos incorrectos. El [registro oficial UdeC](https://repositorio.udec.cl/items/03f99b7a-203b-4bc4-a184-2b7244817b07/full) corresponde a tesis de Paulina González Salazar y Loreto Inostroza Venegas. Wäldchen y Mäder (1090) conserva publicación y DOI erróneos; [Springer](https://link.springer.com/article/10.1007/s11831-016-9206-z) confirma *Archives of Computational Methods in Engineering*, 25, 507–543, DOI 10.1007/s11831-016-9206-z. Corregir y rastrear las afirmaciones que sustentan.
- **Arquitectura actual frente a futura:** RNF02–04, líneas 493–497, RA01 508 y la descripción de prototipo estático 641 siguen sin alinearse. `ApiClient.gd` se describe en 559/713, pero no se localizó ese script. Los presets son Web/Windows/macOS. Expresar qué está implementado y qué se proyecta evita declarar componentes inexistentes como actuales.
- **Medición:** líneas 684–688 proponen pre/post inmediato. La línea 688 declara correctamente corto plazo; no se le atribuye una pretensión explícita de medir largo plazo. Sin control del efecto del test ni seguimiento, no permite concluir causalidad ni permanencia. No encontrar resultados en este repositorio no prueba que no existan fuera de él.
- **Edición:** duplicación 7.2.4 (418/422), sección 8.3 repetida (883/1015), texto truncado (682/688) y citas Soga/Gaston, Rozzi y Wandersee/Schussler sin entradas correspondientes. Rehacer índice tras editar.

## 4. Pruebas y límites

**22 comprobaciones funcionales pasan:** catálogo 80, banco 55, 240 preguntas generadas con una correcta, al menos tres opciones y sin textos duplicados; roundtrip de PR; recuperación desde respaldo tras romper deliberadamente la sintaxis del principal; repaso rápido sin avance, fallo bloqueado en sesión, disponibilidad posterior y avance al acertar; carga de cada bioma; salud 100% en cinco mapas restaurados artificialmente; reinicio de reloj, avisos y registro.

La restauración artificial demuestra que el cálculo puede alcanzar 100% con flora/fauna presentes. No mide tiempo real de progresión, equilibrio económico ni facilidad para lograrlo jugando. Las 22 comprobaciones no detectan por sí solas la pérdida de TriviaManager entre procesos: ese fallo se encontró con una prueba adicional de reapertura.

**Integridad estática:** 80 IDs de especie y 55 IDs de trivia únicos; banco coherente con fichas; 0 grabaciones `audio_canto`; referencias de sinergias resueltas; 46 atracciones con referencias existentes y flora del mismo bioma.

**Casos adversos:** reapertura de XP/DDA pierde datos; versión futura pierde campos; celda null produce error de script. Un caso con insignias null no provocó error en esa ejecución, porque el primer guardado sustituyó los datos antes de importarlos: no se interpreta como validación de ese esquema.

Los logs contienen un aviso de certificados del entorno macOS y errores JSON deliberadamente inducidos. La prueba funcional también informa objetos pendientes al salir; no se atribuye sin aislamiento a un defecto del juego. Un primer harness fue corregido porque se recargaba junto a la escena: sus ejecuciones preliminares no se incluyen como resultados finales. El harness final se mueve a la raíz antes del reinicio y conserva sus resultados.

No se realizaron auditoría visual completa, pruebas táctiles en dispositivo, exportaciones nuevas, benchmark móvil, validación WCAG, ensayo con participantes ni revisión taxonómica exhaustiva. No se publicó ni desplegó el proyecto.

## 5. Orden recomendado

1. Corregir N01 y probar persistencia de todos los campos de TriviaManager durante dos reaperturas.
2. Sustituir la heurística de grupos de N02 por datos explícitos y consistentes.
3. Completar validación/recuperación de guardados y protección de versiones futuras.
4. Corregir bibliografía y alinear alcance, arquitectura y audio en el informe.
5. Completar fuentes científicas, instalación reproducible y pruebas visuales/táctiles antes del piloto.

Este informe registra hallazgos; las correcciones de producción quedan fuera de esta solicitud de auditoría.
