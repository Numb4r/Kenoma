#!/usr/bin/env bash
# Sobe o AVD kenoma_g54. Tenta a GPU NVIDIA por PRIME offload, depois a Intel e, se o driver falhar, o renderizador de
# software (swiftshader_indirect). Um modo falha se o emulador morre ou não termina o boot em 3 min.
# Uso: scripts/emulador/iniciar.sh [--gpu nvidia|intel|software] [--janela]   (sem --janela, roda sem janela: -no-window)
set -u
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
EMU="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
AVD=kenoma_g54
LOG="${TMPDIR:-/tmp}/kenoma-emulador.log"
ONLY="" WINDOW=(-no-window)
while [ $# -gt 0 ]; do
  case "$1" in
    --gpu) ONLY="$2"; shift 2 ;;
    --janela) WINDOW=(); shift ;;
    *) echo "opção desconhecida: $1"; exit 2 ;;
  esac
done

if "$ADB" devices | grep -q '^emulator-.*device$'; then echo "já tem um emulador no ar: $("$ADB" devices | grep '^emulator-' | cut -f1)"; exit 0; fi

booted() { [ "$("$ADB" -e shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; }

try() {
  local name="$1" gpu="$2"; shift 2
  echo "== tentando $name (-gpu $gpu)"
  env "$@" "$EMU" -avd "$AVD" -gpu "$gpu" "${WINDOW[@]}" -no-snapshot-save -no-boot-anim -netdelay none -netspeed full > "$LOG" 2>&1 &
  local pid=$!
  for _ in $(seq 180); do
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then echo "   o emulador saiu (log: $LOG)"; return 1; fi
    if booted; then echo "   no ar com $name (pid $pid, log: $LOG)"; return 0; fi
  done
  echo "   não terminou o boot em 3 min"; kill "$pid" 2>/dev/null; sleep 3; return 1
}

modes=(nvidia intel software)
[ -n "$ONLY" ] && modes=("$ONLY")
for m in "${modes[@]}"; do
  case "$m" in
    nvidia) try "NVIDIA (PRIME offload)" host __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia && exit 0 ;;
    intel) try "Intel" host __GLX_VENDOR_LIBRARY_NAME=mesa && exit 0 ;;
    software) try "software" swiftshader_indirect && exit 0 ;;
  esac
done
echo "nenhum modo subiu; veja $LOG"; exit 1
