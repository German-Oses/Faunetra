# Correcciones propuestas al informe

**Documento:** `Oses-Vllavicencio-INF4556-12_v2.md` (no se modificó).
**Origen:** hallazgos A02, A03, A05, A06 y A14 de las auditorías del 13 y 16 de octubre de 2026 (`auditoria/`).
**Preparado:** 16 de octubre de 2026, sobre el commit `4a9b6ea` y las correcciones de código posteriores.

Los números de línea corresponden a la versión actual del informe; cambian al editar, así que conviene aplicar las correcciones de abajo hacia arriba o buscar por el texto citado. Cada referencia nueva o corregida se comprobó en su fuente (Crossref, doi.org o el repositorio de la institución); lo que no se pudo comprobar está marcado como **pendiente**.

## Resumen

| # | Hallazgo | Qué hacer | Prioridad |
| --- | --- | --- | --- |
| 1 | A02 | Corregir dos referencias con datos erróneos (González e Inostroza; Wäldchen y Mäder). | Antes de entregar |
| 2 | A02 | Tres referencias **no verificables**: Méndez et al. (2023), Vargas et al. (2021) y GBIF (2024). Los DOI de Vargas y GBIF no existen. | Antes de entregar |
| 3 | A14 | Agregar a la bibliografía Soga y Gaston (2016), Wandersee y Schussler (1999) y Rozzi (2013), que se citan pero no tienen entrada. | Antes de entregar |
| 4 | A03 | El informe promete sonidos reales; el juego usa sonidos simulados y lo dice. | Antes de entregar |
| 5 | A05 | Separar lo implementado (prototipo web en Godot, guardado local) de lo proyectado (backend, apps nativas, `ApiClient.gd`). | Antes de entregar |
| 6 | A06 | Delimitar qué permite concluir el pre/post inmediato y, si se puede, agregar una medición diferida. | Antes del estudio |
| 7 | A14 | Secciones duplicadas, párrafos truncados, encabezados vacíos e índice. | Antes de entregar |
| 8 | A12 | Mencionar la matriz de respaldo científico y su estado. | Antes de entregar |

---

## 1. Referencias con datos erróneos (A02)

### 1.1 González e Inostroza (2025): es una tesis, no un artículo

**Línea 1045 — antes:**
> González, F., & Inostroza, P. (2025). Conocimientos y actitudes sobre la biodiversidad en estudiantes del electivo Biología de los Ecosistemas. *Revista de Educación Ambiental*, 12(3), 45-60.

**Después** (datos del [registro oficial de la Universidad de Concepción](https://repositorio.udec.cl/handle/11594/12553)):
> González Salazar, P., & Inostroza Venegas, L. (2025). *Conocimientos y actitudes sobre la biodiversidad en estudiantes del electivo Biología de los Ecosistemas de establecimientos educacionales de la comuna de Los Ángeles* [Tesis de pregrado, Universidad de Concepción]. Repositorio Institucional UdeC. https://repositorio.udec.cl/handle/11594/12553

**Línea 177 — cita en el texto:** cambiar `(González & Inostroza, 2025)` por `(González Salazar & Inostroza Venegas, 2025)`.

**Revisar además:** que la tesis efectivamente use el concepto de «ceguera hacia lo nativo» que se le atribuye en la línea 177. Si no lo usa, citarla solo para lo que sí sostiene.

### 1.2 Wäldchen y Mäder (2018): revista y DOI equivocados

**Línea 1090 — antes:**
> Wäldchen, J., & Mäder, P. (2018). Plant species identification using computer vision techniques: A systematic literature review. PLOS ONE, 13(4), e0195513. https://doi.org/10.1371/journal.pone.0195513

**Después** (verificado en Crossref; el DOI anterior corresponde a otro artículo):
> Wäldchen, J., & Mäder, P. (2018). Plant species identification using computer vision techniques: A systematic literature review. *Archives of Computational Methods in Engineering, 25*(2), 507–543. https://doi.org/10.1007/s11831-016-9206-z

**Nota:** esta referencia no se cita en el texto. Hay que citarla donde corresponda (por ejemplo, en la sección de tecnologías de identificación junto a Van Horn et al., 2018) o quitarla.

## 2. Referencias que no se pudieron verificar (A02) — pendiente

Comprobado el 16 de octubre de 2026. Que no se encuentren no prueba que no existan, pero una tesis no puede sostener afirmaciones en referencias que nadie puede localizar. Si el equipo no tiene el documento original a mano, recomiendo reemplazarlas.

| Referencia | Línea | Qué se comprobó | Recomendación |
| --- | --- | --- | --- |
| Méndez, M., Silva, R., & Castro, J. (2023). *Gayana Botánica*, 80(2), 112-125. | 1047 (citada en 179) | No aparece en Crossref ni en búsquedas de *Gayana Botánica*. | Localizar el artículo original. Si no existe, quitar la cita y la cifra que sostiene (ver abajo). Para el concepto de homogeneización biocultural, la fuente reconocida es Rozzi (ver 3.3). |
| Vargas, R., Garin, G., Pizarro, J., & Delgado, J. (2021). *Revista Chilena de Historia Natural*, 94(1). DOI 10.1186/s40693-021-00090-7 | 1088 | **El DOI no existe** (doi.org responde 404). Además, la referencia no se cita en el texto. | Quitarla, o reemplazarla por una fuente verificada si se necesita para el relevamiento de especies. |
| Global Biodiversity Information Facility [GBIF]. (2024). *Occurrence records — Chile*. DOI 10.15468/dl.chile2024 | 1059 | **El DOI no existe** (404). Los DOI de descarga de GBIF son códigos generados al descargar (formato `10.15468/dl.xxxxxx`), no nombres. | Citar la descarga real que se usó con su DOI, o citar el portal: «GBIF.org (2024). *GBIF Home Page*. https://www.gbif.org». |

**Línea 179 — afirmación que depende de Méndez et al.:**
> Investigaciones recientes indican que menos del 40% de la población chilena logra identificar correctamente especies nativas en peligro de extinción (Méndez et al., 2023).

Si no se encuentra la fuente original, eliminar esta oración. El párrafo se sostiene sin la cifra.

## 3. Citas sin entrada en la bibliografía (A14)

Se citan en el texto pero no aparecen en la sección 9. Entradas verificadas en Crossref:

### 3.1 Soga y Gaston (2016) — líneas 185 y 226
> Soga, M., & Gaston, K. J. (2016). Extinction of experience: The loss of human–nature interactions. *Frontiers in Ecology and the Environment, 14*(2), 94–101. https://doi.org/10.1002/fee.1225

### 3.2 Wandersee y Schussler (1999) — línea 220
> Wandersee, J. H., & Schussler, E. E. (1999). Preventing plant blindness. *The American Biology Teacher, 61*(2), 82–86. https://doi.org/10.2307/4450624

### 3.3 Rozzi (2013) — líneas 187 y 228 — pendiente

No se pudo confirmar qué texto de 2013 se cita. El candidato más probable es el libro que Rozzi coeditó ese año. Si se cita un capítulo, hay que poner el capítulo, sus páginas y su DOI.
> Rozzi, R., Pickett, S. T. A., Palmer, C., Armesto, J. J., & Callicott, J. B. (Eds.). (2013). *Linking ecology and ethics for a changing world: Values, philosophy, and action* (Ecology and Ethics, Vol. 1). Springer.

Para el concepto de homogeneización biocultural (línea 179), la obra de referencia es:
> Rozzi, R., May, R. H., Chapin, F. S., Massardo, F., Gavin, M. C., Klaver, I. J., Pauchard, A., Nuñez, M. A., & Simberloff, D. (Eds.). (2018). *From biocultural homogenization to biocultural conservation* (Ecology and Ethics, Vol. 3). Springer. https://doi.org/10.1007/978-3-319-99513-7

Verificar en el libro la lista exacta de editores antes de usarla.

### 3.4 Referencias de productos

Juegos y aplicaciones (Terra Nil, Alba, Picture Bird, Kurrüf, eBird/Sullivan et al., CONAF) se mencionan por su nombre en el texto. En APA conviene que la cita incluya autor y año, por ejemplo «Terra Nil (Free Lives, 2023)». Sullivan et al. (2009) aparece en la bibliografía, pero en el texto eBird se cita como «Kahl et al.»; revisar a cuál corresponde cada afirmación.

## 4. Sonidos del juego (A03)

**Línea 415 — antes:**
> **Puzzles de asociación acústica:** Módulos en la tableta donde el jugador escucha paisajes sonoros reales (cantos de aves, sonidos de anfibios) y debe asociarlos con su respectiva ficha visual en la Biopedia.

**Después:**
> **Puzzles de asociación acústica:** Módulos en la tableta donde el jugador escucha un paisaje sonoro y debe asociarlo con la ficha de la especie. En el prototipo actual los sonidos son **simulados**: se generan por programa a partir del grupo biológico de cada animal (aves, anfibios, mamíferos, insectos…) y el juego lo indica en pantalla. Los animales que no vocalizan, como caracoles, crustáceos y arañas, se representan con el sonido de su ambiente. Incorporar grabaciones reales, con procedencia y licencia verificadas (por ejemplo, de xeno-canto o de la Macaulay Library), queda como trabajo futuro. Por eso, los resultados de este minijuego no se usan como evidencia de reconocimiento acústico de especies.

Lo mismo aplica a cualquier otra mención de «cantos reales» o «sonidos reales» en el informe.

## 5. Alcance: lo implementado y lo proyectado (A05)

El informe mezcla tres alcances: mockups estáticos (líneas 508 y 641), una aplicación móvil con backend (RNF02–RNF04) y el prototipo funcional que existe hoy. Propongo declarar las fases explícitamente.

### 5.1 Nuevo párrafo al inicio de 7.5.2 (antes de RNF01)
> Los requerimientos se clasifican según su estado en el prototipo funcional entregado: **[Implementado]** está disponible y verificado en el repositorio; **[Parcial]** funciona con limitaciones declaradas; **[Proyectado]** corresponde a una fase posterior y no forma parte de la entrega actual.

### 5.2 Requerimientos no funcionales (líneas 493–497)

| RNF | Texto propuesto |
| --- | --- |
| RNF01 [Implementado] | El sistema se desarrolla íntegramente en **Godot Engine 4.7** (GDScript, renderizador *Compatibility*), usando su arquitectura de nodos para la interfaz y el ecosistema. |
| RNF02 [Proyectado] | Una fase posterior podrá incorporar un servicio *backend* (API REST con base de datos relacional) para sincronizar progreso y reunir los datos de investigación. El prototipo actual no lo incluye: toda la persistencia es local. |
| RNF03 [Implementado / Proyectado] | El prototipo se publica como **aplicación web** (HTML5/WebAssembly) que funciona en navegadores de celulares (en vertical) y de computadores, con exportaciones adicionales para Windows y macOS. Las aplicaciones nativas para Android (APK/AAB) e iOS (IPA) quedan proyectadas. |
| RNF04 [Implementado / Proyectado] | El progreso se guarda localmente en el dispositivo (archivo JSON con escritura segura y respaldo automático), sin requerir conexión después de la carga inicial. La sincronización con un servidor queda proyectada junto con RNF02. |
| RNF05 [Parcial] | Mantener 60 FPS en dispositivos de gama media. Pendiente de medición en dispositivos reales. |
| RNF06 [Parcial] | Accesibilidad visual según las pautas WCAG. Pendiente de evaluación formal de contraste. |

### 5.3 RA01 (línea 508)

Reemplazar «se circunscribe a la entrega de un prototipo de alta fidelidad —mockups interactivos y documentación técnica—» por:
> se circunscribe a la entrega de un **prototipo funcional jugable** (versión web con los cinco biomas, las 80 fichas de especies, el sistema de trivias adaptativas y el registro de aprendizaje) y su documentación técnica, sin incluir el *backend* ni las aplicaciones nativas, que quedan proyectados (ver RNF02–RNF04).

Si el alcance comprometido con la institución era efectivamente un prototipo estático, conviene decirlo explícitamente y presentar el prototipo funcional como un avance adicional.

### 5.4 Sección 7.8 (línea 641)

Reemplazar «Dado que la presente fase del proyecto contempla la entrega de un prototipo visual estático (mockups de alta fidelidad)» por:
> Dado que la presente fase del proyecto entrega un prototipo funcional jugable,

### 5.5 Arquitectura de autoloads (líneas 555–559)

La descripción de `ApiClient.gd` (cliente HTTP hacia Supabase) corresponde a un componente que **no existe** en el repositorio. Reemplazar la lista por los autoloads reales:
> *   **`GameState.gd`:** estado de la partida (biomas, PR, descubrimientos, repasos espaciados, modo de juego), registro de investigación y guardado local con escritura segura y respaldo.
> *   **`EventBus.gd`:** bus de señales globales que desacopla el terreno, las especies y la interfaz.
> *   **`TriviaManager.gd`:** banco de trivias, generación de preguntas desde las fichas, dificultad adaptativa y progreso del jugador.
> *   **`Sonidos.gd`:** efectos y ambiente sonoro de cada bioma.
> *   **`Pantalla.gd`:** orientación (vertical u horizontal) y adaptación de la interfaz.
>
> Un cliente HTTP para sincronizar con un *backend* queda proyectado (RNF02).

Actualizar también el diagrama de secuencia siguiente si muestra llamadas a la API.

### 5.6 Módulo de persistencia (línea 713)

Reemplazar «Gestiona la persistencia local en el sistema de guardado de Godot y la comunicación remota con PostgreSQL vía `ApiClient.gd` (`HTTPRequest`)» por:
> Gestiona la persistencia local en el sistema de archivos de Godot (`user://`): escritura en un archivo temporal, verificación y reemplazo, con la versión anterior como respaldo; validación de la estructura al cargar; y protección de partidas guardadas por versiones más nuevas. La comunicación con una base de datos remota queda proyectada.

### 5.7 Sección 8.3, esquema de base de datos (línea 883)

La nota ya dice que el esquema es preliminar. Agregar: «Este modelo corresponde al *backend* proyectado (RNF02); el prototipo actual no lo implementa.»

## 6. Evaluación del aprendizaje (A06)

La línea 688 declara correctamente que se mide la retención a corto plazo. Lo que falta es delimitar qué se puede concluir y, si el cronograma lo permite, medir la retención.

### 6.1 Reemplazo propuesto para 7.8.4 (líneas 678–688)
> Para estimar el efecto del prototipo sobre el reconocimiento de especies se aplicará un diseño pre-test / post-test en un solo grupo:
>
> **Instrumento:** reconocimiento de especies nativas del bioma jugado, en dos **formas equivalentes** (A y B) con especies distintas de dificultad comparable, para reducir el efecto de aprender el test. La mitad de los participantes responde A antes y B después, y la otra mitad al revés.
>
> **Pre-test:** forma A (o B), sin apoyo.
>
> **Exposición:** sesión de 20 a 30 minutos con el prototipo. El juego registra el tiempo efectivo de juego y si cada respuesta se dio con la ficha o la imagen de la especie visible (`ficha_visible`, `imagen_apoyo`), para separar aciertos con apoyo de la recuperación autónoma.
>
> **Post-test inmediato:** la otra forma, sin apoyo.
>
> **Post-test diferido (recomendado):** la forma del pre-test, 7 días después. El juego programa repasos espaciados a 1, 3 y 7 días; esta medición permite saber si el reconocimiento se mantiene.
>
> **Alcance de las conclusiones:** sin grupo de control, el diseño permite describir el cambio en el reconocimiento de los participantes, pero no atribuirlo exclusivamente al juego ni generalizarlo a la población. Con una muestra pequeña (por ejemplo, nueve participantes distribuidos en tres perfiles), los resultados son exploratorios.

### 6.2 Separar dos estudios
- **Piloto de usabilidad:** comprensión de la interfaz, controles táctiles y tutorial. Puede hacerse antes y con menos participantes.
- **Estudio de aprendizaje:** el diseño de 6.1, sobre una versión estable del juego.

### 6.3 Datos que entrega el juego

En *Perfil → Exportar registro (CSV)* el juego exporta un CSV con cada evento: participante, sesión, tiempo, trivia, acierto, uso de pista, apoyo del tutor, ficha o imagen visible, y si el sonido era real o simulado. Conviene mencionarlo en el plan de análisis.

## 7. Correcciones de edición (A14)

| Línea | Problema | Corrección |
| --- | --- | --- |
| 418 y 422 | La sección **7.2.4** está duplicada con textos casi iguales. | Dejar la primera (dice «la Niebla del Olvido vuelve a avanzar», que coincide con el juego) y borrar la segunda. Completar la última oración, que está cortada en ambas («Esta mecánica busca i…»). |
| 682 | Fragmento suelto: «n de datos científicos y las mecánicas de aprendizaje.» | Quitarlo o completar la oración de la que proviene. Si se adopta la sección 6.1 de este documento, desaparece. |
| 688 | Oración truncada: «…validando así la efectividad de la presentació». | Reemplazar por la versión de 6.1, o completar: «…de la presentación de datos científicos y de las mecánicas de aprendizaje.» |
| 690–692 | Encabezados vacíos (`#`). | Eliminarlos. |
| 883 y 1015 | Hay dos secciones **8.3** (base de datos y wireframes). | Renumerar: wireframes pasa a 8.4 y se corren las siguientes. |
| Índice | Quedará desactualizado con todo lo anterior. | Regenerarlo al final. |

## 8. Respaldo científico (A12)

Se creó `documentacion/respaldo_cientifico/` con dos matrices:
- **`especies.csv`:** las 80 fichas, con columnas para la categoría oficial, la autoridad (RCE del Ministerio del Medio Ambiente o UICN), el ámbito, la fuente, la fecha de consulta y la revisión.
- **`relaciones.csv`:** las 73 relaciones ecológicas (27 sinergias y 46 atracciones), con una columna para indicar si cada una es científica o una simplificación del juego.

El README de esa carpeta explica cómo llenarlas.

Sugerencia de texto para la sección 7.3 (base de datos de especies):
> El respaldo de cada ficha (categoría de conservación, autoridad que la asigna, ámbito nacional o global, fuente y fecha de consulta) y el de cada relación ecológica se registra en una matriz de trazabilidad (`documentacion/respaldo_cientifico/`), que distingue las relaciones documentadas en la literatura de las simplificaciones introducidas por diseño de juego. Al cierre de esta versión, la revisión de las fuentes está [en curso / completa].

Las categorías del juego **no se han contrastado** todavía con las fuentes oficiales. Ese trabajo lo debe hacer el equipo, idealmente con la revisión de alguien con formación en biología. Hasta entonces, el informe no debería afirmar que los estados de conservación están verificados.
