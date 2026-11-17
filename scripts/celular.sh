#!/bin/bash
# Dirige o moto g54 com segurança (0.24.2). No 0.24.1 um script seguiu tocando e digitando às cegas depois que o dono pegou
# o aparelho, e o texto foi parar num chat. Regras:
#   - antes de CADA ação: tela ligada, sem bloqueio e o Kenoma em primeiro plano; se não, para na hora, grava a trava e
#     recusa tudo daqui em diante até `reset` (nada de tentar de novo sozinho);
#   - nunca digita texto: o debug vai por `cmd`, uma intent que só o Kenoma lê (lib/dev/debug_commands.dart);
#   - `start` (abrir o app) só com KENOMA_CELULAR_LIBERADO=1, depois que o dono disse na sessão que o aparelho está livre.
#
# uso: celular.sh check | start | cmd "sim on; tp -22.9,-47.06; map" | tap X Y | swipe X1 Y1 X2 Y2 [ms] | back | shot NOME | reset
set -u
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
SERIAL="${KENOMA_CELULAR:-ZF524FMMGF}"
A="adb -s $SERIAL"
PKG=com.numb4r.kenoma
TRAVA=/tmp/kenoma-celular.parado
SHOTS=/tmp/kenoma-shots

parar() {
  echo "PARADO: $1" | tee "$TRAVA" >&2
  exit 2
}

confere() {
  [ -f "$TRAVA" ] && { echo "recusado: $(cat "$TRAVA") (rode 'reset' depois que o dono liberar de novo)" >&2; exit 2; }
  local w
  w=$($A shell dumpsys window 2>/dev/null) || parar "adb sem resposta"
  echo "$w" | grep -q "mAwake=true\|mScreenOnFully=true" || parar "tela desligada"
  echo "$w" | grep -q "isKeyguardShowing=false" || parar "tela bloqueada"
  echo "$w" | grep "mCurrentFocus" | grep -q "$PKG" || parar "outro app em primeiro plano: $(echo "$w" | grep -m1 mCurrentFocus | sed 's/.*u0 //')"
}

case "${1:-}" in
  check) confere; echo "ok: Kenoma em primeiro plano" ;;
  reset) rm -f "$TRAVA"; echo "trava removida" ;;
  start)
    [ "${KENOMA_CELULAR_LIBERADO:-}" = 1 ] || { echo "start só com KENOMA_CELULAR_LIBERADO=1 (o dono liberou o aparelho nesta sessão)" >&2; exit 2; }
    [ -f "$TRAVA" ] && { echo "recusado: $(cat "$TRAVA")" >&2; exit 2; }
    $A shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 6; confere; echo "ok: aberto" ;;
  cmd) confere; $A shell am start -n $PKG/.MainActivity --es kenoma_cmd "'${2:?comando}'" >/dev/null; echo "ok: cmd $2" ;;
  tap) confere; $A shell input tap "$2" "$3" ;;
  swipe) confere; $A shell input swipe "$2" "$3" "$4" "$5" "${6:-300}" ;;
  back) confere; $A shell input keyevent 4 ;;
  shot)
    confere
    mkdir -p "$SHOTS"
    $A exec-out screencap -p > "$SHOTS/$2.png"
    # Conferido de novo depois: se o dono pegou o aparelho no meio, a captura some.
    if ! ( confere ) 2>/dev/null; then rm -f "$SHOTS/$2.png"; parar "mudou durante a captura"; fi
    echo "$SHOTS/$2.png" ;;
  *) echo "uso: $0 check | start | cmd \"...\" | tap X Y | swipe X1 Y1 X2 Y2 [ms] | back | shot NOME | reset" >&2; exit 1 ;;
esac
