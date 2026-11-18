#!/usr/bin/env bash
# Sobe os pacotes de região na GitHub Release `regioes-dev` (0.26.0) e atualiza a lista scripts/regioes.sha256.
# Depois de regerar um pacote na pipeline: copie o .bin para app/assets/regions/, rode este script e commite a lista.
# Precisa do GitHub CLI autenticado (`gh auth login`, uma vez). Publica arquivos no repositório público: só com o pedido do dono.
# Uso: scripts/subir_regioes.sh [--todos | arquivo.bin ...]   (sem argumentos: os que mudaram em relação à lista)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$ROOT/scripts/regioes.sha256"
DIR="$ROOT/app/assets/regions"
TAG=regioes-dev
command -v gh >/dev/null || { echo "instale o GitHub CLI (gh) e rode gh auth login" >&2; exit 2; }
cd "$DIR"
if [ "${1:-}" = "--todos" ]; then files=(*.bin); elif [ "$#" -gt 0 ]; then files=("$@"); else
  mapfile -t files < <(for f in *.bin; do grep -q "^$(sha256sum "$f" | cut -d' ' -f1)  $f\$" "$LIST" 2>/dev/null || echo "$f"; done)
fi
gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --title "Pacotes de região (desenvolvimento)" --notes "Os .bin de app/assets/regions/. Baixe com scripts/baixar_regioes.sh; a lista de SHA-256 é scripts/regioes.sha256."
[ "${#files[@]}" -gt 0 ] && gh release upload "$TAG" "${files[@]}" --clobber
sha256sum *.bin > "$LIST"
echo "lista atualizada: ${#files[@]} arquivo(s) enviado(s); commite scripts/regioes.sha256"
