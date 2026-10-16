# Respaldo científico de Faunetra

Responde al hallazgo **A12** de las auditorías: poder reconstruir por qué cada especie tiene la categoría, el nombre y el bioma que muestra el juego, y en qué se basa cada relación ecológica.

Esta carpeta tiene un `.gdignore`: Godot no la importa ni la incluye en las exportaciones.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `especies.csv` | Una fila por cada una de las 80 fichas de `data/especies/`. |
| `relaciones.csv` | Una fila por cada sinergia y atracción de `data/ecosistema/reglas_ecosistema.json` (27 + 46). |

Las columnas que vienen llenas (`id_especie`, `nombre_comun`, `nombre_cientifico`, `tipo`, `grupo_fauna`, `id_bioma`, `estado_en_el_juego`, y en relaciones `especie_a`, `especie_b`, `efecto_en_el_juego`) son **lo que el juego usa hoy**. Las demás quedan vacías, con `estado_revision = pendiente`, hasta que alguien las verifique contra la fuente original. Ninguna fuente se completó de antemano: un dato sin verificar no debe parecer respaldado.

`pruebas/casos.gd` comprueba que ambas matrices cubran todas las fichas y reglas del juego; si se agrega una especie o una regla, hay que agregar su fila.

## Cómo completar `especies.csv`

| Columna | Qué poner |
| --- | --- |
| `estado_verificado` | Categoría oficial vigente (CR, EN, VU, NT, LC, EW, EX, DD o NE). |
| `autoridad` | Quién la asigna. Para Chile, el **Reglamento de Clasificación de Especies (RCE) del Ministerio del Medio Ambiente**, indicando el proceso y el decreto. Si no tiene categoría nacional, la **Lista Roja de la UICN** (global). |
| `ambito` | `nacional` (RCE) o `global` (UICN). No mezclar: una especie puede tener categorías distintas en cada ámbito. |
| `fuente`, `url`, `fecha_consulta` | Cita de la fuente original, enlace a la ficha y fecha en que se consultó (AAAA-MM-DD). |
| `nombre_cientifico_aceptado` | Nombre aceptado hoy, si difiere del que usa el juego (sinonimias, cambios de género). |
| `presencia_en_bioma_verificada` | `si` / `no`: la especie realmente habita el bioma del juego (`id_bioma`: 1 Zona Central, 2 Norte Árido, 3 Bosques Templados, 4 Patagonia, 5 Territorios Insulares). |
| `revisado_por`, `fecha_revision` | Persona que revisó (idealmente con formación en biología) y fecha. |
| `estado_revision` | `pendiente` → `verificado` (coincide) o `corregir` (el juego debe cambiar; detallar en `observaciones`). |

Fuentes de referencia:

- Inventario Nacional de Especies de Chile y fichas del RCE (Ministerio del Medio Ambiente): https://clasificacionespecies.mma.gob.cl/
- Lista Roja de la UICN: https://www.iucnredlist.org/
- Flora: Rodríguez, R. et al. (2018). *Catálogo de las plantas vasculares de Chile*. Gayana Botánica 75(1): 1–430.
- Registros de presencia: iNaturalist y GBIF (apoyo; no reemplazan a la autoridad de clasificación).

## Cómo completar `relaciones.csv`

| Columna | Qué poner |
| --- | --- |
| `clasificacion` | `cientifica`: la relación está documentada (polinización, dispersión, alimento, refugio, microclima…). `simplificacion`: es una mecánica del juego inspirada en el ecosistema pero no documentada como tal. Ambas son válidas en un juego; lo importante es no presentar una simplificación como hecho. |
| `fuente`, `url`, `fecha_consulta` | Solo para `cientifica`: publicación o ficha que documenta la relación. |
| `revisado_por`, `observaciones`, `estado_revision` | Igual que en especies. |

Cuando una relación quede como `simplificacion`, conviene que la Biopedia no la describa como un hecho comprobado.

## Cambios en el juego derivados de la revisión

Si una fila queda en `corregir`, se cambia la ficha (`data/especies/<especie>.tres`) o la regla (`reglas_ecosistema.json`), se vuelve a correr `./herramientas/pruebas.sh` y se marca la fila como `verificado`.
