#!/usr/bin/env bash
# Prepara o emulador do Kenoma no notebook (idempotente: rodar de novo só confere). Não usa sudo: o que precisa de root sai
# listado no fim para você rodar. Uso: scripts/emulador/setup.sh
set -u
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
FLUTTER="${FLUTTER_ROOT:-$HOME/development/flutter}"
IMAGE="system-images;android-34;google_apis;x86_64"
AVD=kenoma_g54
SUDO=()   # comandos com sudo que faltam
ok() { echo "  ok  $*"; }
warn() { echo "  !!  $*"; }

echo "== KVM"
if grep -qE '(vmx|svm)' /proc/cpuinfo; then ok "a CPU tem virtualização (vmx/svm)"; else warn "sem vmx/svm na CPU: ligue a virtualização (Intel VT-x) na BIOS"; fi
if [ -e /dev/kvm ]; then
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then ok "/dev/kvm acessível"; else
    warn "/dev/kvm existe mas você não lê/escreve nele"
    SUDO+=("sudo usermod -aG kvm $USER   # e saia e entre de novo na sessão")
  fi
else
  warn "/dev/kvm não existe"
  SUDO+=("sudo apt install qemu-kvm   # e confira a virtualização ligada na BIOS")
fi

echo "== Flutter e Android SDK"
if [ -x "$FLUTTER/bin/flutter" ]; then ok "Flutter em $FLUTTER"; else warn "Flutter não encontrado em $FLUTTER: instale o stable (https://docs.flutter.dev/get-started/install/linux) nesse caminho ou exporte FLUTTER_ROOT"; fi
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
AVDM="$SDK/cmdline-tools/latest/bin/avdmanager"
if [ ! -x "$SDKM" ]; then
  warn "Android SDK sem cmdline-tools em $SDK: baixe 'Command line tools only' de https://developer.android.com/studio#command-line-tools-only e extraia em $SDK/cmdline-tools/latest"
  printf '\n%s\n' "${SUDO[@]:-}"
  exit 1
fi
ok "sdkmanager em $SDKM"

echo "== Pacotes (platform-tools, emulator, $IMAGE)"
yes | "$SDKM" --licenses > /dev/null 2>&1 || true
for p in platform-tools emulator "$IMAGE"; do
  if "$SDKM" --list_installed 2>/dev/null | grep -q "^  ${p//;/;} "; then ok "$p já instalado"; else
    echo "  ..  instalando $p"
    "$SDKM" --install "$p" > /dev/null || { warn "falhou: $p"; exit 1; }
    ok "$p"
  fi
done

echo "== AVD $AVD (perfil do moto g54: 1080x2400, densidade 400, 4 GB)"
if "$SDK/emulator/emulator" -list-avds 2>/dev/null | grep -qx "$AVD"; then ok "AVD $AVD já existe"; else
  echo no | "$AVDM" create avd -n "$AVD" -k "$IMAGE" -d pixel_6 --force > /dev/null || { warn "avdmanager falhou"; exit 1; }
  ok "AVD $AVD criado"
fi
CFG="$HOME/.android/avd/$AVD.avd/config.ini"
set_cfg() { if grep -q "^$1=" "$CFG"; then sed -i "s|^$1=.*|$1=$2|" "$CFG"; else echo "$1=$2" >> "$CFG"; fi; }
set_cfg hw.lcd.width 1080
set_cfg hw.lcd.height 2400
set_cfg hw.lcd.density 400
set_cfg hw.ramSize 4096
set_cfg hw.keyboard yes
set_cfg hw.gpu.enabled yes
set_cfg disk.dataPartition.size 6G
ok "config.ini: 1080x2400, 400 dpi, 4096 MB"

if [ ${#SUDO[@]} -gt 0 ]; then
  echo; echo "== Rode você (precisa de sudo):"; printf '  %s\n' "${SUDO[@]}"
else
  echo; echo "Pronto. Suba com scripts/emulador/iniciar.sh"
fi
