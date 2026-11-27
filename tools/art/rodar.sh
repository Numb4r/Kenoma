#!/bin/bash
# Roda scripts de arte em lote, sem MCP (a execução padrão do agente `executor`; o MCP fica para ajuste fino pontual).
#   tools/art/rodar.sh <arquivo.lua> [...]   Aseprite em modo batch, com KENOMA_ART definido (o build.lua de cada pasta)
#   tools/art/rodar.sh <arquivo.py> [...]    Python 3 (PIL), da raiz do repo
#   tools/art/rodar.sh --blender <arq.py>    Blender headless (bpy)
# Um arquivo por vez, na ordem; para no primeiro erro.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ASEPRITE="${ASEPRITE_PATH:-$HOME/aseprite/build/bin/aseprite}"
BLENDER="${BLENDER_PATH:-$(command -v blender || echo "$HOME/.local/bin/blender")}"
blender=0
for a in "$@"; do
  [ "$a" = --blender ] && { blender=1; continue; }
  f="$(cd "$(dirname "$a")" && pwd)/$(basename "$a")"
  case "$f" in
    *.lua)
      tmp=$(mktemp --suffix=.lua)
      printf "KENOMA_ART='%s/tools/art/'\ndofile('%s')\n" "$ROOT" "$f" > "$tmp"
      "$ASEPRITE" -b --script "$tmp"; rm -f "$tmp" ;;
    *.py)
      if [ "$blender" = 1 ]; then "$BLENDER" -b --python "$f"; else (cd "$ROOT" && python3 "$f"); fi ;;
    *) echo "não sei rodar: $a" >&2; exit 1 ;;
  esac
done
