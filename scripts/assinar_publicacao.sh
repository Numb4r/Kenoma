#!/usr/bin/env bash
# Assina epochs.json e events.json com Ed25519 e deixa tudo em docs/pages/ (NÃO publica nada).
# Uso: scripts/assinar_publicacao.sh [epochs.json] [events.json]
#   padrão: app/assets/data/epochs.json e docs/pages/events.json
# A chave privada fica em ~/.kenoma-signing/publicacao_ed25519.pem (criada na primeira execução, permissão 600),
# nunca no repositório. A assinatura vai em X.json.sig: 128 caracteres hex (64 bytes), sobre os bytes exatos do arquivo.
set -euo pipefail
cd "$(dirname "$0")/.."
KEY_DIR="$HOME/.kenoma-signing"
KEY="$KEY_DIR/publicacao_ed25519.pem"
OUT="docs/pages"
EPOCHS="${1:-app/assets/data/epochs.json}"
EVENTS="${2:-$OUT/events.json}"

mkdir -p "$KEY_DIR" "$OUT"
chmod 700 "$KEY_DIR"
if [ ! -f "$KEY" ]; then
  (umask 077 && openssl genpkey -algorithm ED25519 -out "$KEY")
  chmod 600 "$KEY"
  echo "Chave nova criada em $KEY (faça backup dela junto com o keystore: scripts/backup_signing_key.sh)."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
openssl pkey -in "$KEY" -pubout -out "$TMP/pub.pem"
PUB_HEX="$(openssl pkey -in "$KEY" -pubout -outform DER | tail -c 32 | od -An -v -tx1 | tr -d ' \n')"

for src in "$EPOCHS" "$EVENTS"; do
  dst="$OUT/$(basename "$src")"
  [ "$(realpath "$src")" = "$(realpath -m "$dst")" ] || cp "$src" "$dst"
  openssl pkeyutl -sign -rawin -inkey "$KEY" -in "$dst" -out "$TMP/sig.bin"
  od -An -v -tx1 "$TMP/sig.bin" | tr -d ' \n' > "$dst.sig"
  openssl pkeyutl -verify -rawin -pubin -inkey "$TMP/pub.pem" -in "$dst" -sigfile "$TMP/sig.bin" > /dev/null
  echo "assinado e conferido: $dst (e $dst.sig)"
done

cat <<MSG

Chave pública (hex, 32 bytes), a que o app embute em app/lib/net/feed_config.dart:
$PUB_HEX

Para publicar (manual, nada foi enviado):
  1. git add docs/pages && git commit -m "chore(pages): publicação assinada"
  2. git push (só você decide) e, no GitHub, Settings > Pages > Deploy from branch > /docs/pages
     (ou copie docs/pages/ para a branch gh-pages).
  3. Confira: curl -s https://numb4r.github.io/Kenoma/events.json.sig
Mais detalhes em docs/assinatura.md.
MSG
