# CLAUDE.md

**Kenoma: Veilbreakers** (repo `kenoma`): RPG mobile de exploração por GPS em pixel art 2D. A cidade real vira fantasia urbana; o Conjurador coleta materiais do ambiente, fabrica selos e captura criaturas sintonizando o sinal num dial. Não existe batalha (`docs/plano-b-batalha.md` só se pedido).

## Referências
- `docs/GDD.md` é o norte, não o escopo. `docs/marcos.md` é o roadmap: um marco por vez. `docs/fase0-spec.md` é o escopo e a spec de hash, PRNG e células (seção 3). Algo do GDD fora da spec e dos marcos: pergunte antes.
- Clima `docs/clima-auditoria.md`, chave e feed `docs/assinatura.md`, pacotes de região e SHAs `pipeline/README.md`, arte `docs/referencias-de-arte.md`, issues `docs/agents/`.

## Stack e comandos
Flutter stable, Dart 3, Flame no mapa e na sintonia, widgets no resto, Riverpod. Só Android. Pipeline em Python 3.11 via uv. Antes de `flutter`: `export PATH="$HOME/development/flutter/bin:$PATH" ANDROID_HOME=$HOME/Android/Sdk`.
- Testes: `cd app && flutter analyze && flutter test` (um arquivo: `flutter test test/core/fnv_test.dart`; por nome: `--plain-name "FNV-1a"`). Nunca `dart format` (reescreve ~150 arquivos). O tempo de cada teste é 60 s (`app/dart_test.yaml`, `timeout: 2x`): a suíte roda com o emulador ligado.
- Biomas: edite `shared/biomes.json` e rode `./scripts/sync_shared.sh` (um teste compara as cópias).
- Pipeline: `cd pipeline && .venv/bin/python build_region.py --region campinas` (e `build_visual.py`). Regerar um `.bin` muda o mundo: o SHA novo entra na época de desenvolvimento (regra 5).
- Aparelho: o celular se o `adb devices` mostrar o moto g54, senão o emulador do notebook (`docs/emulador.md`, só build de debug, sempre `adb -s emulator-5554`); desempenho só se mede no celular.
- Checklist do celular (`docs/checklist-celular.md`): cumulativo desde a versão instalada no celular; cada versão acrescenta os itens dela, e um item só sai quando o relatório confirmar que passou.
- Screenshot: só se `adb shell dumpsys window | grep isKeyguardShowing` der `false` e `grep mCurrentFocus` citar `com.numb4r.kenoma`; então `adb exec-out screencap -p > /tmp/kenoma-shots/<nome>.png`.
- Celular, segurança (0.24.2): só mexer depois que o dono disser na sessão que o aparelho está liberado, e parar quando ele pegar o aparelho (tela desligada, app trocado ou toque dele). Todo toque ou captura passa por `scripts/celular.sh`, que antes de cada ação confere que o primeiro plano é `com.numb4r.kenoma` e, se não for, para na hora e não tenta de novo. Nunca digitar texto pelo `adb` no celular: o debug se dirige por comandos (`scripts/celular.sh cmd ...`, uma intent que o próprio app lê, só no Kenoma), nunca pelo teclado.

## Regras invioláveis
1. Determinismo: o mundo deriva de `hash(seed_global, época, célula, janela)` com o FNV-1a 64 e o PCG32 de `app/lib/core/`. Nunca `hashCode` nem `dart:math Random`. Hash é u64: `>>>`, módulo sobre `h >>> 32`. Tempo em segundos UTC; só a exibição é local.
2. Offline: nada no Núcleo depende de rede. Spawns individuais: capturar não tira nada dos amigos.
3. Lógica em Dart puro e testável (`core/`, `capture/`, `world/`, `player/`, `crafting/`); Flame e widgets só desenham. Função de `core/` e `capture/` tem teste com vetores fixos.
4. Conteúdo é dado em `app/assets/data/`, sem balanceamento no código. IDs de texto estáveis (`soot.eco`); o sufixo `.eco`, `.spirit`, `.ritual` decide a camada.
5. Modo de desenvolvimento até a distribuição: uma época única, embarcada e ativa; mudança de mundo entra nela direto. O regime de épocas publicadas e congeladas começa quando o dono disser que vai distribuir (passo a passo em `docs/distribuicao.md`). É mundo o que está em `epochs.json` (spawns, coleta, `eco_v2`, `climate`, os SHA dos pacotes), `shared/biomes.json` e os pacotes de região, mesmo que o pedido diga `balance.json`, que é só por aparelho. `*_noaccess.bin` não é mundo e vai em `route_files`.
6. Amigos já jogam: todo APK sai com a chave de release (`~/.kenoma-signing/`), nunca a de debug. Mudou o save: suba `saveSchemaVersion`, migração pura e teste com save antigo. Nunca grave a chave privada nem publique no GitHub Pages sem pedido; o feed só acrescenta épocas ou estende validade.
7. Push: com `flutter test` passando e `flutter analyze` limpo, dê push no fim de cada versão sem perguntar; fora disso, só com autorização explícita. Publicar o feed, o `regions.json` ou qualquer coisa em `docs/pages` continua precisando de autorização explícita, a cada vez. Commit só quando pedido, pequeno, um por passo de marco.

## Convenções
- Código em inglês; UI, comentários de domínio e docs em português. Nomes próprios não se traduzem (Sootling, Ialprg).
- Função nova é app do celular (`ui/menu/phone_apps.dart`, nível em `balance.json` `phone.apps`). HUD só com atalhos em zonas fixas (`ui/game/hud_layout.dart`, teste em 360×800, 412×915, 480×1000). Ajustes só guarda preferências.
- Clima: a tela só desenha o que cai do céu ou cobre a vista; o chão vai no mapa em células z21 (`climate_ground.dart`), nunca em coordenadas de tela. Clima da rede é só visual; climas de outras regiões e místicos só por `events.json` assinado ou debug.
- Simulações (GDD, "Simulações do mundo"): o que muda o jogo é função da seed e do tempo, igual para amigos; cenário pode ser simulação local. O tráfego comum é cenário (`world/sim/`, pontos do OSM em `*_traffic.bin`, fora das épocas); a cobertura do clima é um campo por bloco (`world/cover_field.dart`), refeito só quando a fase muda de faixa.
- Menu de debug em toda build de teste, inclusive release dos amigos, nunca atrás de flag. Versão futura fica atrás de `streetLifeEnabled` (`core/features.dart`).
- Patrulha do Véu nunca grava o save principal (`patrulha.jsonl`). Recomeçar mantém `player_id`, log de versões, certificados e Ajustes.
- Sprite ausente vira placeholder gerado. Cores: Véu `#9b7bff`, sinal `#5fd3c6`, Essência `#ff7a45`, contorno `#1a1424` (nunca preto).

## Agentes
- `criativo` decide e entrega a spec, o `executor` implementa. `criativo` (Fable, só leitura): toda decisão criativa (nomes, textos, clima e efeito, sprites, paleta, arte e 3D) e a conferência das folhas de contato; devolve uma spec de no máximo ~1 página (paleta em hex, silhueta, proporções, resolução, referências, lista de assets). `executor` (Sonnet): só quando chamado, com a spec ou o conteúdo no pedido; gera arte por script em lote (`tools/art/rodar.sh`: Aseprite batch, Python/PIL, Blender headless), MCP só para ajuste fino, e grava dados em volume (`app/assets/data/`, menos `epochs.json`, e `workbench/catalog/catalog.json`). Os MCPs `aseprite` e `blender` só existem dentro do `executor`. `testador` (Haiku): depois de cada mudança de código; devolve só as falhas.
- O resto fica na thread principal (Opus): implementar, depurar, integrar e o servidor do workbench. Dois agentes nunca editam o mesmo arquivo, e a thread principal não mexe nos arquivos do `executor` enquanto ele trabalha. Os agentes globais (`code-reviewer`, `tdd-guide` etc.) não se usam neste repo. Antes de fechar cada versão, a thread principal relê as seções do GDD citadas no prompt.
- Rodar `/clear` ao trocar de tarefa; `/compact` quando o contexto passar de ~200k.
- Execução: depois de 2 tentativas falhas no mesmo critério, pare e reporte. Capturas só no fim de cada seção do prompt. No resumo final, liste o que precisa de teste no celular ou na rua. Nada de diário de bordo: o histórico fica no git.
