# Emulador de Android no notebook

Quando o celular não está por perto, o desenvolvimento roda num emulador no notebook (Dell Inspiron 14 5440, Ubuntu 22.04, Core 7 150U, 32 GB, Intel com NVIDIA MX570A). **No notebook só entram builds de debug**: a de debug tem outra assinatura e não instala por cima da release do celular sem apagar o save. Nunca instale nada no celular a partir daqui.

## Preparar (uma vez)

```
scripts/emulador/setup.sh
scripts/baixar_regioes.sh
```

O segundo baixa os pacotes de região (`app/assets/regions/*.bin`, fora do git desde a 0.26.0) da GitHub Release `regioes-dev` e confere o SHA-256 de cada um pela lista `scripts/regioes.sha256`. Uma vez por máquina; o build do Android roda o mesmo script antes de empacotar.

Idempotente. Confere a virtualização (`vmx` na CPU e `/dev/kvm` acessível), o Flutter e o Android SDK, instala pelo `sdkmanager` o platform-tools, o emulator e a imagem `system-images;android-34;google_apis;x86_64`, e cria o AVD `kenoma_g54` com o perfil do moto g54: 1080×2400, densidade 400, 4 GB de RAM. O que precisa de sudo (pacotes de KVM, grupo `kvm`) ele só lista. Neste notebook, em 2026-11-15, nada precisou de sudo: o `/dev/kvm` já era acessível.

## Subir

```
scripts/emulador/iniciar.sh            # sem janela; --janela para ver
scripts/emulador/iniciar.sh --gpu intel
```

Tenta a GPU NVIDIA por PRIME offload (`__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia`), depois a Intel e, se o driver falhar, `swiftshader_indirect`. Em 2026-11-15 a NVIDIA deu falha de segmentação (o driver estava com `Driver/library version mismatch`, que costuma sair com um reboot) e subiu na Intel. Depois de um dia ligado, o `screencap` travou: `adb -s emulator-5554 emu kill` e subir de novo resolve (o app e o save ficam).

Instalar: `cd app && flutter build apk --debug && adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`. A build de debug leva x86_64, arm64 e armv7. Sempre `-s emulator-5554` no `adb`, para não falar com o celular por engano.

## Posição

```
scripts/emulador/rota.py taquaral               # a volta da Lagoa do Taquaral (2,7 km)
scripts/emulador/rota.py centro                 # Rua 13 de Maio, ida e volta (1,6 km)
scripts/emulador/rota.py paulista               # Avenida Paulista, São Paulo (época 12)
scripts/emulador/rota.py --fixo=-22.9056,-47.0608
```

Toca um GPX pelo `adb emu geo fix` a 1,4 m/s, um ponto por segundo (`--velocidade`, `--voltas`). As três rotas saíram do mesmo extrato do OSM da época 0 e são de lugares públicos; nenhuma perto de casa. `--fixo` só fixa uma coordenada, para pôr o emulador no mesmo lugar do celular.

## O que o jogo faz no emulador

- **Conta como GPS simulado** (GDD rev 353, Salvaguardas): o que se pega não vai para a Bolsa nem conta para XP, estatística ou bestiário, a menos que o interruptor "GPS simulado dá recompensa" do debug esteja ligado. O item do simulador no debug avisa quando é emulador. A Patrulha com o GPS do emulador nunca dá recompensa (o interruptor fica no app e não chega ao serviço).
- **Dois aparelhos de verdade:** o item "Camada pessoal de spawn" do debug mostra a célula z20, a janela, a época e dois resumos, `base` e `pessoal`. Na mesma célula e janela, o celular e o emulador têm de dar a mesma `base` e `pessoal` diferente (outro `player_id`). Para comparar, ponha o emulador no lugar do celular com `rota.py --fixo=lat,lon` e confira os dois a olho (item do checklist do celular).

## Limites

- **Desempenho só no celular.** O orçamento de 4 ms por quadro vale medido no moto g54. No emulador, cada simulação é medida só como comparação relativa, antes e depois de uma mudança, no mesmo AVD, para pegar regressão; esses números vão para o workbench marcados como emulador. A medida absoluta fica no checklist do celular.
- Contador de passos, Patrulha com a tela apagada, vibração e as notificações de Uber e 99 continuam sendo testes do celular.
- A build de debug calcula a água do relevo bem mais devagar que a de release (alguns segundos por tile): no emulador, o bloco fica seco um tempo depois de entrar numa área nova.
