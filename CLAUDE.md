# CLAUDE.md

**Kenoma: Veilbreakers** (repo `kenoma`): RPG mobile de exploração por GPS em pixel art 2D. A cidade real vira fantasia urbana; o Conjurador coleta materiais do ambiente, fabrica selos e captura criaturas sintonizando o sinal num dial. Não existe batalha (`docs/plano-b-batalha.md` só se pedido).

## Referências
- `docs/GDD.md` é o norte, não o escopo. `docs/marcos.md` é o roadmap: um marco por vez. `docs/fase0-spec.md` é o escopo e a spec de hash, PRNG e células (seção 3). Algo do GDD fora da spec e dos marcos: pergunte antes.
- Clima `docs/clima-auditoria.md`, chave e feed `docs/assinatura.md`, pacotes de região e SHAs `pipeline/README.md`, arte `docs/referencias-de-arte.md`, issues `docs/agents/`.

## Stack e comandos
Flutter stable, Dart 3, Flame no mapa e na sintonia, widgets no resto, Riverpod. Só Android. Pipeline em Python 3.11 via uv. Antes de `flutter`: `export PATH="$HOME/development/flutter/bin:$PATH" ANDROID_HOME=$HOME/Android/Sdk`.
- Testes: `cd app && flutter analyze && flutter test` (um arquivo: `flutter test test/core/fnv_test.dart`; por nome: `--plain-name "FNV-1a"`). Nunca `dart format` (reescreve ~150 arquivos).
- Biomas: edite `shared/biomes.json` e rode `./scripts/sync_shared.sh` (um teste compara as cópias).
- Pipeline: `cd pipeline && .venv/bin/python build_region.py --region campinas` (e `build_visual.py`). Nunca regere por cima um `.bin` commitado: o extrato muda e o SHA em `epochs.json` é mundo.
- Screenshot: só se `adb shell dumpsys window | grep isKeyguardShowing` der `false` e `grep mCurrentFocus` citar `com.numb4r.kenoma`; então `adb exec-out screencap -p > /tmp/kenoma-shots/<nome>.png`.

## Regras invioláveis
1. Determinismo: o mundo deriva de `hash(seed_global, época, célula, janela)` com o FNV-1a 64 e o PCG32 de `app/lib/core/`. Nunca `hashCode` nem `dart:math Random`. Hash é u64: `>>>`, módulo sobre `h >>> 32`. Tempo em segundos UTC; só a exibição é local.
2. Offline: nada no Núcleo depende de rede. Spawns individuais: capturar não tira nada dos amigos.
3. Lógica em Dart puro e testável (`core/`, `capture/`, `world/`, `player/`, `crafting/`); Flame e widgets só desenham. Função de `core/` e `capture/` tem teste com vetores fixos.
4. Conteúdo é dado em `app/assets/data/`, sem balanceamento no código. IDs de texto estáveis (`soot.eco`); o sufixo `.eco`, `.spirit`, `.ritual` decide a camada.
5. O que muda o mundo vive só na época (`epochs.json`: spawns, coleta, `eco_v2`, `climate`; `shared/biomes.json`; pacotes de região, e o SHA do pacote visual desde a época 2), mesmo que o pedido diga `balance.json`, que é só por aparelho. Nunca altere época publicada: pergunte e crie a próxima com início UTC. `*_noaccess.bin` não é mundo e vai em `route_files`.
6. Amigos já jogam: todo APK sai com a chave de release (`~/.kenoma-signing/`), nunca a de debug. Mudou o save: suba `saveSchemaVersion`, migração pura e teste com save antigo. Nunca grave a chave privada nem publique no GitHub Pages sem pedido; o feed só acrescenta épocas ou estende validade.
7. Push só com autorização explícita, a cada vez. Commit só quando pedido, pequeno, um por passo de marco.

## Convenções
- Código em inglês; UI, comentários de domínio e docs em português. Nomes próprios não se traduzem (Sootling, Ialprg).
- Função nova é app do celular (`ui/menu/phone_apps.dart`, nível em `balance.json` `phone.apps`). HUD só com atalhos em zonas fixas (`ui/game/hud_layout.dart`, teste em 360×800, 412×915, 480×1000). Ajustes só guarda preferências.
- Clima: a tela só desenha o que cai do céu ou cobre a vista; o chão vai no mapa em células z21 (`climate_ground.dart`), nunca em coordenadas de tela. Clima da rede é só visual; climas de outras regiões e místicos só por `events.json` assinado ou debug.
- Simulações (GDD, "Simulações do mundo"): o que muda o jogo é função da seed e do tempo, igual para amigos; cenário pode ser simulação local. O tráfego comum é cenário (`world/sim/`, pontos do OSM em `*_traffic.bin`, fora das épocas); a cobertura do clima é um campo por bloco (`world/cover_field.dart`), refeito só quando a fase muda de faixa.
- Menu de debug em toda build de teste, inclusive release dos amigos, nunca atrás de flag. Versão futura fica atrás de `streetLifeEnabled` (`core/features.dart`).
- Patrulha do Véu nunca grava o save principal (`patrulha.jsonl`). Recomeçar mantém `player_id`, log de versões, certificados e Ajustes.
- Sprite ausente vira placeholder gerado. Cores: Véu `#9b7bff`, sinal `#5fd3c6`, Essência `#ff7a45`, contorno `#1a1424` (nunca preto).

## Agentes
- `testador`: depois de mudar código, e no fim do marco com screenshot. `conteudo`: lotes grandes nos JSONs de `app/assets/data/` (o hook dele recusa `epochs.json` e outras pastas). `revisor`: só no fim do marco, contra GDD, spec e marcos.
- O que leva poucas chamadas não se delega; bugs difíceis ficam na thread principal. Nunca dois agentes no mesmo arquivo. Os agentes globais (`code-reviewer`, `tdd-guide` etc.) não se usam neste repo.
- Execução autônoma: screenshot só no fim de cada marco; depois de 2 tentativas falhas no mesmo critério, pare e reporte. O histórico fica nos commits: não escreva nem leia diário de bordo.
