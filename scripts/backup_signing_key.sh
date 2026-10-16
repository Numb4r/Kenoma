#!/usr/bin/env bash
# Backup cifrado da chave de release do Kenoma (docs/assinatura.md).
#
#   ./scripts/backup_signing_key.sh /pasta/de/destino        gera kenoma-signing-AAAAMMDD.tar.gz.gpg
#   ./scripts/backup_signing_key.sh --verify arquivo.gpg     confere o conteúdo (pede a senha de novo)
#
# A senha é digitada por você no terminal (o gpg a pede); ela não fica em arquivo nenhum nem no repositório.
# Depois de gerar, copie o arquivo para DOIS lugares diferentes (pendrive e nuvem pessoal).
set -euo pipefail
SRC="${KENOMA_SIGNING_DIR:-$HOME/.kenoma-signing}"
need=(kenoma-release.jks key.properties)

if [[ "${1:-}" == "--verify" ]]; then
  [[ -f "${2:-}" ]] || { echo "uso: $0 --verify arquivo.gpg" >&2; exit 2; }
  echo "Conteúdo de $2 (pede a senha):"
  gpg --quiet --decrypt "$2" | tar -tzvf -
  exit 0
fi

DEST="${1:-}"
[[ -n "$DEST" && -d "$DEST" ]] || { echo "uso: $0 /pasta/de/destino (a pasta precisa existir)" >&2; exit 2; }
for f in "${need[@]}"; do
  [[ -s "$SRC/$f" ]] || { echo "falta $SRC/$f: a chave não está completa" >&2; exit 1; }
done
[[ -s "$SRC/publicacao_ed25519.pem" ]] && need+=(publicacao_ed25519.pem) # chave de assinatura do feed (docs/assinatura.md)
OUT="$DEST/kenoma-signing-$(date +%Y%m%d).tar.gz.gpg"
[[ ! -e "$OUT" ]] || { echo "já existe $OUT; não sobrescrevo" >&2; exit 1; }

echo "Vou cifrar $SRC (${need[*]}) em $OUT"
echo "Digite uma senha forte quando o gpg pedir, e guarde-a num cofre de senhas. Sem ela o backup não abre."
tar -C "$SRC" -czf - "${need[@]}" | gpg --symmetric --cipher-algo AES256 --output "$OUT"
chmod 600 "$OUT"
echo "Gerado: $OUT"
sha256sum "$OUT"
echo "Confira com: $0 --verify \"$OUT\""
echo "LEMBRETE: copie $(basename "$OUT") para dois lugares diferentes (pendrive e nuvem pessoal)."
