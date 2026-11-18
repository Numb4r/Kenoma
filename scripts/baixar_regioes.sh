#!/usr/bin/env bash
# Baixa os pacotes de região (0.26.0): os .bin de app/assets/regions/ não moram no git. Ficam na GitHub Release
# `regioes-dev` do repositório, e a lista versionada scripts/regioes.sha256 diz quais arquivos e com que SHA-256.
# Roda uma vez por máquina (e o build do Android roda antes de empacotar): o que já está no disco com o SHA certo fica;
# o que falta ou não confere é baixado de novo e conferido. Sai com erro se algum arquivo não bater.
# Uso: scripts/baixar_regioes.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$ROOT/scripts/regioes.sha256"
DEST="$ROOT/app/assets/regions"
URL="${KENOMA_REGIOES_URL:-https://github.com/Numb4r/Kenoma/releases/download/regioes-dev}"
mkdir -p "$DEST"
falhou=0
while read -r sha file; do
  [ -z "${file:-}" ] && continue
  alvo="$DEST/$file"
  if [ -f "$alvo" ] && [ "$(sha256sum "$alvo" | cut -d' ' -f1)" = "$sha" ]; then continue; fi
  echo "baixando $file"
  if ! curl -fsSL --retry 3 -o "$alvo.part" "$URL/$file"; then
    echo "ERRO: não baixou $file de $URL" >&2; rm -f "$alvo.part"; falhou=1; continue
  fi
  if [ "$(sha256sum "$alvo.part" | cut -d' ' -f1)" != "$sha" ]; then
    echo "ERRO: $file baixado não confere com o SHA-256 da lista" >&2; rm -f "$alvo.part"; falhou=1; continue
  fi
  mv "$alvo.part" "$alvo"
done < "$LIST"
[ "$falhou" = 0 ] && echo "pacotes de região ok ($(grep -c . "$LIST") arquivos)"
exit "$falhou"
