#!/bin/zsh
# Exporta la versión web y la publica en https://inddigo.github.io/faunetra/ (repo inddigo/faunetra).
# También deja build/faunetra-web.zip para subirla a otro hosting.
# Uso (desde la carpeta del proyecto): ./herramientas/publicar_web.sh
set -e
GODOT="${GODOT:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
PROYECTO="$(cd "$(dirname "$0")/.." && pwd)"
PAGES="$(mktemp -d)"

cd "$PROYECTO"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
(cd build/web && rm -f ../faunetra-web.zip && zip -qr ../faunetra-web.zip .)

git clone -q --depth 1 https://github.com/inddigo/faunetra.git "$PAGES"
find "$PAGES" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R build/web/. "$PAGES"/
touch "$PAGES/.nojekyll"
cd "$PAGES"
git add -A
git commit -q -m "Versión web desde $(git -C "$PROYECTO" rev-parse --short HEAD)" || { echo "Sin cambios."; exit 0; }
git push -q
echo "Publicado: https://inddigo.github.io/faunetra/ (tarda ~1 min en actualizarse)"
