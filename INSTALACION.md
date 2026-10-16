# Instalación de Faunetra

Guía para abrir, probar y exportar el proyecto en un computador nuevo, desde un clon limpio del repositorio.

## Requisitos

| Herramienta | Versión probada | Para qué |
| --- | --- | --- |
| [Godot](https://godotengine.org/download/archive/) | **4.7.1 stable** (renderer *Compatibility*) | Motor del juego. Usar esta versión: otras pueden reimportar distinto. |
| [Aseprite](https://www.aseprite.org/) | 1.3.18 | Godot lo usa para importar los `.aseprite` (sprites de especies y plantas). |
| Plantilla de exportación Web de Godot 4.7.1 | — | Solo para exportar la versión web (*Editor → Manage Export Templates*). |
| `git`, `zsh`, `rsync`, `perl` | — | Scripts de `herramientas/` (vienen con macOS; en Linux, instalarlos con el gestor de paquetes). |

El complemento **AsepriteWizard 9.8.0** ya viene en `addons/AsepriteWizard` y está activado en el proyecto.

## Pasos

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/German-Oses/Faunetra.git
   ```
2. **Indicar dónde está Aseprite.** La ruta se guarda en la configuración del editor de cada computador (no en el proyecto), así que hay que hacerlo una vez por equipo:
   - Abrir el proyecto en Godot (si aparecen errores de importación de `.aseprite`, ignorarlos por ahora).
   - *Editor → Editor Settings → Aseprite → General → Command Path*: ruta al ejecutable de Aseprite, por ejemplo:
     - macOS (Steam): `~/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite`
     - macOS (instalador): `/Applications/Aseprite.app/Contents/MacOS/aseprite`
     - Windows (Steam): `C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe`
   - Cerrar y volver a abrir el proyecto para que se reimporten los sprites.
3. **Comprobar la instalación** con las pruebas (corren en una copia temporal, no tocan ninguna partida):
   ```bash
   ./herramientas/pruebas.sh --limpia
   ```
   `--limpia` importa todo desde cero, como en un clon nuevo. Debe terminar con «Todas las pruebas pasan». Si Godot no está en `~/Downloads/Godot.app`, indicar la ruta: `GODOT=/ruta/a/Godot ./herramientas/pruebas.sh --limpia`.

## Uso diario

| Tarea | Cómo |
| --- | --- |
| Jugar en el editor | Abrir el proyecto en Godot y presionar *Play* (F5). |
| Pruebas de regresión | `./herramientas/pruebas.sh` (rápido, usa la caché de importación). |
| Publicar la versión web | `./herramientas/publicar_web.sh` (exporta a `build/web` y la sube a GitHub Pages; requiere permisos en el repositorio `inddigo/faunetra`). |
| Regenerar arte | Scripts Lua de `herramientas/aseprite/` (ver la cabecera de cada uno), con `aseprite -b --script <script>` desde la carpeta del proyecto o con el MCP de Aseprite. |

## Dónde guarda las partidas

Godot guarda en `user://`, que depende del nombre del proyecto (`Faunetra`):

- macOS: `~/Library/Application Support/Godot/app_userdata/Faunetra/`
- Windows: `%APPDATA%\Godot\app_userdata\Faunetra\`
- Linux: `~/.local/share/godot/app_userdata/Faunetra/`
- Web: almacenamiento del navegador del sitio (se borra al borrar los datos del sitio).

`faunetra_guardado.json` es la partida y `faunetra_guardado.json.bak` la versión anterior (respaldo automático). **No ejecutar scripts de prueba directamente sobre el proyecto**: abrir el juego con el nombre real sobrescribe la partida. Por eso `pruebas.sh` trabaja en una copia llamada `FaunetraPruebas`.

## Problemas frecuentes

- **Sprites de especies en blanco o errores `Aseprite command not found`:** falta el paso 2.
- **Errores «Cannot infer the type» al abrir por primera vez:** no deberían aparecer (se tiparon las variables que los causaban). Si vuelven, ejecutar `./herramientas/pruebas.sh --limpia` para ver dónde, y declarar el tipo explícito en esa variable.
- **La versión web no muestra los cambios publicados:** el navegador guarda la versión anterior. Cerrar todas las pestañas del juego (y la app si se instaló en la pantalla de inicio) y volver a abrir; si sigue igual, borrar los datos del sitio.
