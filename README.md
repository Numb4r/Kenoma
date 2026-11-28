# Kenoma: Veilbreakers

RPG mobile de exploração por GPS em pixel art 2D (Flutter, só Android). O norte é `docs/GDD.md`; o roteiro, `docs/marcos.md`.

## Preparar a máquina (uma vez)

1. Flutter stable e Android SDK: `export PATH="$HOME/development/flutter/bin:$PATH" ANDROID_HOME=$HOME/Android/Sdk`.
2. **Pacotes de região:** os `.bin` de `app/assets/regions/` não moram no git. Baixe e confira uma vez por máquina:
   ```
   scripts/baixar_regioes.sh
   ```
   Ele baixa da GitHub Release `regioes-dev` e confere o SHA-256 de cada um pela lista versionada `scripts/regioes.sha256`.
   O build do Android roda o mesmo script antes de empacotar (com tudo no disco, só confere).
3. Testes: `cd app && flutter analyze && flutter test --exclude-tags perf`; os de desempenho à parte, com a máquina quieta: `flutter test --tags perf --concurrency=1`.
4. Emulador: `docs/emulador.md`.

Depois de regerar um pacote na pipeline (`pipeline/README.md`): `scripts/subir_regioes.sh` sobe o arquivo novo na release e
atualiza a lista; commite a lista.
