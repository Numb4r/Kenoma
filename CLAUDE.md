# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Kenoma: Veilbreakers** é um RPG mobile de exploração via GPS em pixel art 2D. A cidade real vira um mundo de fantasia urbana invadido pelos fragmentos de deuses mortos que vazam por Fendas no Véu. O jogador é um Conjurador que coleta materiais conforme o ambiente real, fabrica selos e captura criaturas sintonizando o sinal delas num dial, como um rádio. Não existe batalha.

Nome do repositório: `kenoma`.

## Documentos de referência

- `docs/GDD.md` é a visão completa do jogo, exportada do GDD. Serve de norte, **não** de escopo.
- `docs/fase0-spec.md` é o escopo atual. Só implemente o que está nele.
- `docs/marcos.md` é a ordem de implementação. Trabalhe um marco por vez.
- `docs/referencias-de-arte.md` tem os prompts e descrições visuais das telas e criaturas.
- `docs/dados-iniciais/` tem os JSONs iniciais. No M0, copie `biomes.json` para `shared/`, `regions.json` para `pipeline/` e os demais para `app/assets/data/`.

Se uma tarefa tocar em algo que está no GDD mas não na spec da Fase 0, pare e pergunte antes de implementar.

`docs/plano-b-batalha.md` guarda um sistema de batalha para o caso de a sintonia não funcionar. **Não implemente batalha** a menos que isso seja pedido explicitamente.

## Stack

- Flutter (stable) e Dart 3
- Flame para o mapa e para a tela de sintonia
- Widgets Flutter para toda interface fora do mapa e da sintonia (celular, bolsa, círculo, bestiário, bancada, configurações)
- Riverpod para estado
- `geolocator` para GPS
- `path_provider` para o save, `share_plus` e `file_picker` para exportar e importar backup
- `qr_flutter` e `mobile_scanner` para compartilhar a seed do grupo por QR code
- `vibration` para os padrões de vibração da sintonia (o `HapticFeedback` não faz padrão)
- Pipeline de mapa em Python 3.11+ com `osmium`, `shapely`, `pyproj`, `rasterio`, `numpy`
- Plataforma alvo da Fase 0: Android. Web fora do escopo (inteiros de 64 bits).

## Estrutura

```
app/                  # projeto Flutter
  lib/
    core/             # hash, PRNG, células, janelas, épocas (Dart puro, sem Flutter)
    data/             # pacotes de região e JSONs de conteúdo
    world/            # mapa, spawns, coleta, marcação
    capture/          # lógica da sintonia (Dart puro, testável)
    player/           # Conjurador, círculo, bolsa, bestiário, progressão
    crafting/         # receitas, bancada, destilação
    save/             # formato do save, migrações, backup
    ui/               # telas e widgets
    dev/              # ferramentas de debug (simulador de GPS, relógio etc.)
  assets/
    data/             # creatures.json, items.json, recipes.json, balance.json, epochs.json
    regions/          # pacotes de bioma (.bin)
    sprites/
  test/
pipeline/             # scripts Python de geração de pacotes de região
  regions.json        # bbox e fonte de cada região
shared/
  biomes.json         # biomas e regras OSM, fonte única para Python e Dart
scripts/
  sync_shared.sh      # copia shared/biomes.json para app/assets/data/
docs/
```

## Regras invioláveis

1. **Determinismo.** Tudo que existe no mundo é derivado de `hash(seed_global, época, célula, janela)`. Dois aparelhos com a mesma seed e a mesma época, na mesma célula e na mesma janela, veem os mesmos spawns (existência, espécie, posição, quantidade). O nível do Eco e as capturas são individuais. A especificação exata do hash, do PRNG e dos vetores de teste está na seção 3 da spec.
2. **Nunca use `Object.hashCode`, `String.hashCode` nem `dart:math Random` para lógica de mundo.** Use o hash e o PRNG próprios de `lib/core/` (FNV-1a 64 e PCG32 implementados à mão). Todo hash é u64: use `>>>`, nunca `>>`, e faça módulo sobre `h >>> 32`.
3. **Tempo em UTC.** Janelas, épocas e registros usam segundos UTC desde a época Unix. Só a exibição converte para o horário local.
4. **Offline.** Nada no Núcleo depende de rede. GPS e arquivos locais apenas.
5. **Spawns individuais.** A seed é compartilhada, mas cada jogador tem a própria instância de cada criatura. Capturar não remove nada para os amigos.
6. **Lógica separada de renderização.** `capture/`, `world/`, `player/` e `crafting/` têm lógica testável em Dart puro. Componentes Flame e widgets só desenham e repassam input.
7. **Conteúdo é dado.** Criaturas, itens, receitas e parâmetros de balanceamento vivem em JSON em `assets/data/`. Nenhum número de balanceamento hardcoded.
8. **Conteúdo que afeta o mundo muda só por época.** Tabelas de spawn, coleta e materiais, biomas e o pacote de região ficam em `epochs.json` e `biomes.json`. Nunca altere o que uma época publicada usa: crie a próxima época com data de início UTC. `balance.json` guarda só o que não muda o mundo.
9. **IDs estáveis.** Espécies, itens e receitas têm IDs de texto (`soot.eco`, `item.chalk`). Nunca use índice numérico como identificador persistido.
10. **Biomas têm fonte única** em `shared/biomes.json`. O Python lê direto; o app lê a cópia em `app/assets/data/`, feita por `scripts/sync_shared.sh`, e um teste falha se as duas cópias forem diferentes.

## Sistema de células

Coordenadas de tile Web Mercator (padrão slippy map), inteiras e determinísticas.

- Grade de bioma: zoom 21 (~18 m por célula em Campinas)
- Célula de spawn: zoom 20 (~35 m)
- Célula de Fenda (futuro): zoom 15 (~1,1 km)

Janelas de spawn têm 20 minutos, com deslocamento próprio por célula. Detalhes em `docs/fase0-spec.md`.

## Convenções

- Código e identificadores em inglês. Textos da interface, comentários de domínio e docs em português.
- Nomes de criaturas, deuses e do jogo são nomes próprios não traduzidos (Sootling, Ialprg, Shloshim).
- Toda função de `core/` e `capture/` tem teste unitário com vetores fixos.
- Commits pequenos, um por passo de marco.
- Sprites ausentes usam placeholders gerados (forma simples na cor do tipo com a inicial do nome). Arte nunca bloqueia código.
- Cores fixas: violeta `#9b7bff` é o Véu, ciano `#5fd3c6` é o sinal, laranja `#ff7a45` é Essência. Contorno `#1a1424`, nunca preto puro.

## Comandos

```
# app
cd app && flutter pub get
cd app && flutter test
cd app && flutter test test/core/fnv_test.dart             # um arquivo
cd app && flutter test --plain-name "FNV-1a" test/core/     # testes pelo nome
cd app && flutter analyze
cd app && flutter run

# biomas: rodar depois de editar shared/biomes.json
./scripts/sync_shared.sh

# pipeline (Python 3.11 via uv; ~3 min e ~4,5 GB de RAM; baixa o extrato da Geofabrik para pipeline/cache/)
cd pipeline && uv venv --python 3.11 .venv && uv pip install --python .venv/bin/python -r requirements.txt
cd pipeline && .venv/bin/python build_region.py --region campinas
```

O pipeline grava `app/assets/regions/campinas_e0.bin` (versionado) e `pipeline/out/campinas_preview.png` (não versionado). O SHA-256 impresso vai para `region_packs.campinas.sha256` em `app/assets/data/epochs.json`. O extrato do OSM muda todo dia, então regerar dá outro SHA: o `.bin` commitado é a fonte da época 0 e não deve ser regerado por cima. O arquivo do pacote se chama `campinas_e0.bin`, como está em `epochs.json`. O M4 em `docs/marcos.md` diz `campinas.bin`, mas o nome certo é `campinas_e0.bin`.
