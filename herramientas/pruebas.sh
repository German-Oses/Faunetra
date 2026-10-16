#!/bin/zsh
# Pruebas de regresión de Faunetra (catálogo, trivias, grupos de fauna, guardado, biomas y controles).
# Se ejecutan en una COPIA temporal del proyecto con otro nombre: así el guardado de prueba va a otra
# carpeta y nunca toca la partida real (con el nombre "Faunetra", abrir el juego la sobrescribe).
# Al final comprueba que la partida real no cambió.
# Uso (desde la carpeta del proyecto): ./herramientas/pruebas.sh [--limpia]
#   --limpia  copia el proyecto SIN la caché .godot, como un checkout recién clonado: verifica que
#             todo se importe desde cero (requiere Aseprite configurado, ver INSTALACION.md).
# Variable opcional: GODOT=/ruta/al/ejecutable/de/Godot
setopt NULL_GLOB
GODOT="${GODOT:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
PROYECTO="$(cd "$(dirname "$0")/.." && pwd)"
NOMBRE="FaunetraPruebas"
if [[ "$OSTYPE" == darwin* ]]; then
  DATOS="$HOME/Library/Application Support/Godot/app_userdata"
else
  DATOS="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata"
fi
GUARDADO_REAL="$DATOS/Faunetra/faunetra_guardado.json"
huella() { [[ -f "$GUARDADO_REAL" ]] && shasum "$GUARDADO_REAL" | cut -d' ' -f1 || echo "sin-guardado"; }
# Ejecuta Godot con un tiempo máximo (macOS no trae `timeout`).
godot() { perl -e 'alarm shift; exec @ARGV' 300 "$GODOT" --headless --path "$COPIA" "$@"; }

[[ -x "$GODOT" ]] || { echo "No se encontró Godot en $GODOT (define GODOT=...)"; exit 2; }
ANTES="$(huella)"
TMP="$(mktemp -d)"
COPIA="$TMP/proyecto"
trap 'rm -rf "$TMP" "$DATOS/$NOMBRE"' EXIT

EXCLUIR=(--exclude .git --exclude build --exclude "Desierto FAUNA")
[[ "$1" == "--limpia" ]] && EXCLUIR+=(--exclude .godot)
rsync -a "${EXCLUIR[@]}" "$PROYECTO/" "$COPIA/"
sed -i '' "s/^config\/name=\"Faunetra\"/config\/name=\"$NOMBRE\"/" "$COPIA/project.godot" 2>/dev/null \
  || sed -i "s/^config\/name=\"Faunetra\"/config\/name=\"$NOMBRE\"/" "$COPIA/project.godot"
grep -q "config/name=\"$NOMBRE\"" "$COPIA/project.godot" || { echo "No se pudo renombrar la copia; se cancela para no tocar la partida real."; exit 2; }
rm -rf "$DATOS/$NOMBRE"

echo "== Importando la copia${1:+ ($1)}…"
godot --import > "$TMP/importacion.log" 2>&1
ERRORES_IMPORTACION=$(grep -cE "ERROR|SCRIPT ERROR|Failed" "$TMP/importacion.log")
if [[ "$1" == "--limpia" ]]; then
  if (( ERRORES_IMPORTACION == 0 )); then echo "OK    importación desde cero sin errores"
  else echo "FALLA importación desde cero con $ERRORES_IMPORTACION error(es):"; grep -E "ERROR|Failed" "$TMP/importacion.log" | head -10
  fi
fi

echo "== Pruebas en un proceso"
godot -s res://pruebas/suite.gd 2>&1 | grep -E "^(OK|FALLA|RESULTADO)|SCRIPT ERROR"
FALLAS=${pipestatus[1]}
[[ "$1" == "--limpia" ]] && (( ERRORES_IMPORTACION > 0 )) && (( FALLAS += 1 ))

echo "== N01: progreso de trivias entre aperturas"
godot -s res://pruebas/n01_preparar.gd >/dev/null 2>&1
godot --quit-after 60 >/dev/null 2>&1
godot --quit-after 60 >/dev/null 2>&1
godot -s res://pruebas/n01_verificar.gd 2>&1 | grep -E "^(OK|FALLA)|SCRIPT ERROR"
(( FALLAS += ${pipestatus[1]} ))

echo "== Arranque y cierre del juego"
godot --quit-after 600 >/dev/null 2>&1
CIERRE=$?
if (( CIERRE == 0 )); then echo "OK    el juego arranca y se cierra sin caerse"; else echo "FALLA el juego terminó con código $CIERRE"; (( FALLAS += 1 )); fi

if [[ "$(huella)" == "$ANTES" ]]; then
  echo "OK    la partida real no se tocó"
else
  echo "FALLA la partida real cambió durante las pruebas"; (( FALLAS += 1 ))
fi
echo
(( FALLAS == 0 )) && echo "Todas las pruebas pasan." || echo "$FALLAS prueba(s) con fallas."
exit $FALLAS
