# Adendo ao guia de estilo: kit do HUD e do celular (0.26.0)

Seções para entrar em `docs/art/estilo-ui.md`. A arte sai de `tools/art/ui/kit/build.lua` (`aseprite -b --script tools/art/ui/kit/build.lua`), que gera os `.aseprite` em `tools/art/ui/kit/`, os PNGs e o `slices.json` em `tools/art/ui/kit/out/` e a folha `out/folha.png` (a 3×). O script recusa moldura maior que 12 × 12, miolo menor que 2 × 2 e qualquer linha ou coluna que estique sem ser lisa (sai como `PROBLEMA`).

## Onde este adendo muda o guia

- "Essência: nenhuma moldura a usa; o código tinge" ganha três exceções, todas de "pede atenção agora": `warn_tag`, `app_tile_new` e `badge_dot`. Fora delas a regra continua.
- "Véu: a seleção" passa a incluir a escolha ligada (`switch_on`) e o progresso do jogador (`xp_fill`). Hoje a barra de XP é ciano no código; o ciano fica só para o que se lê do mundo.
- A agulha da bússola deixa de ser laranja: norte em `#ece6ff` (texto), sul em `#56507a`. O laranja no HUD fica só para o aviso e a novidade.
- Três medidas de `HudSize` saem da grade de 3 dp e precisam mudar com as peças (ver "Regras do HUD").

## Molduras em nove partes (kit)

Bordas em pixels de arte, `[esquerda, topo, direita, baixo]`, como em `out/slices.json`.

| Arquivo | Tamanho | Bordas | Uso |
|---|---|---|---|
| `hud_bar.png` | 8 × 8 | 2, 2, 2, 2 | a barra do topo: placa em `#120e1a` com realce em cima. Escura porque o mapa por baixo é claro |
| `shortcut_chip.png` | 12 × 11 | 2, 2, 2, 3 | atalho temporário (Patrulha ativa, corrida): botão com chanfro de 2 px. Neutro; a cor do atalho vai no rótulo |
| `shortcut_chip_pressed.png` | 12 × 11 | 2, 4, 2, 1 | apertado: a face desce 2 px e a lateral some. Soma 5 px de borda vertical, como o `button` |
| `warn_tag.png` | 12 × 8 | 5, 2, 5, 2 | aviso (DEBUG, relógio forçado). Só estica na horizontal: altura fixa de 8 px (24 dp) |
| `phone_body.png` | 12 × 12 | 4, 4, 4, 4 | o aparelho: corpo de 2 px em relevo, chanfro de 2 px, e o contorno da tela. O miolo é a tela (`#120e1a`) |
| `app_tile.png` | 10 × 10 | 3, 3, 3, 3 | o lugar de cada ícone na grade, rebaixado, miolo em `#1e1830` |
| `app_tile_new.png` | 10 × 10 | 3, 3, 3, 3 | o mesmo com o aro de 1 px de Essência por fora: app recém-liberado |
| `dialog.png` | 12 × 12 | 2, 8, 2, 2 | diálogo de confirmação: o `panel` com a faixa de título de 6 px (18 dp) dentro da borda de cima |
| `card.png` | 12 × 12 | 2, 2, 2, 2 | cartão de criatura (Bestiário, Círculo): relevo, face em `#2a2240`, chanfro de 2 px |
| `card_selected.png` | 12 × 12 | 2, 2, 2, 2 | selecionado: anel violeta no lugar do contorno de fora, mesmo tamanho e mesmas bordas |
| `chip_cond.png` | 8 × 7 | 2, 2, 2, 2 | chip de condição, neutro (aro `#3d3357`); o `cond_dot` vai a 2 px da esquerda e do topo |

- `dialog`: o título fica nas linhas 1 a 6 da imagem (de 3 a 21 dp do topo), em Silkscreen; o corpo começa depois da borda de cima, pela regra geral (borda × 3 dp + 3 dp).
- `app_tile` e `app_tile_new`, e `card` e `card_selected`, têm o mesmo tamanho e as mesmas bordas: trocar um pelo outro não move o conteúdo.
- `warn_tag` é a única moldura que não estica na vertical: as faixas diagonais moram nas pontas, e esticá-las em altura as quebraria.

## Peças fixas (kit)

| Arquivo | Tamanho | Uso |
|---|---|---|
| `hud_portrait.png` | 20 × 27 | retrato: janela de 16 × 16 em (2, 2) para o Conjurador, placa do nível de 16 × 4 em (2, 19), trilho do XP de 18 × 2 em (1, 24) |
| `xp_fill.png` | 1 × 2 | enchimento do XP: repete na horizontal dentro do trilho, em pixels inteiros (18 passos) |
| `phone_button.png`, `phone_button_pressed.png` | 18 × 19 | o botão do celular: face de 16 px com o aparelho desenhado e 2 px de lateral; no apertado a face desce 2 px |
| `badge_dot.png` | 4 × 4 | bolinha de novidade, em Essência, no desenho dos pontos de qualidade. Sobre o `app_tile_new`: canto de cima à direita, 1 px para fora |
| `radar_ring.png` | 162 × 18 | tira de 9 quadros de 18 × 18: o anel de recarga de 0/8 a 8/8, enchendo do alto no sentido horário. No cheio o miolo passa de `#2a2240` para `#3d3357` |
| `compass_dial.png`, `compass_dial_follow.png` | 18 × 18 | mostrador da bússola, não gira. Seguindo a direção: aro de 2 px no ciano do sinal em vez do aro em relevo |
| `compass_needle.png` | 6 × 12 | agulha, para cima, em (6, 3) do mostrador; o código gira em torno do centro do quadro |
| `edge_mark.png` | 10 × 10 | marca do Radar na borda da tela, seta para cima, ciano liso |
| `switch_off.png`, `switch_on.png` | 14 × 8 | interruptor: botão à esquerda e trilho vazio; botão à direita e trilho violeta |
| `cond_dot.png` | 3 × 3 | ponto do `chip_cond`, neutro: o código tinge multiplicando, como `essence.png` |
| `phone_wall.png` | 8 × 8 | ladrilho do fundo da tela inicial, repete nos dois eixos |

## Regras do HUD

- O HUD fica sobre o mapa, então toda peça é opaca, com contorno fechado e miolo escuro (`#120e1a` ou `#1e1830`). Nada de fundo translúcido: as cores com `alpha` de hoje (`kOutline.withValues(alpha: ...)`) saem.
- Medidas na grade de 3 dp. As peças pedem: `bar` 48 (igual), `side` 60 (era 56), `portraitH` 81 (era 76), `phone` 54 de largura por 57 de altura (era 56), `radar` 54 (era 48), `compass` 54 (era 52). O atalho temporário tem 33 dp de altura (11 px) dentro da faixa de 48.
- Cor no HUD: violeta só no XP e no que está selecionado; ciano só no que se lê do mundo agora (anel do Radar, marca da borda, bússola seguindo a direção); laranja só no aviso e na novidade. A moldura do retrato e a das marcações são neutras.
- O que gira: a agulha, em passos de pixel, e a `edge_mark`, só em 90°. Por isso as duas não têm luz de cima à esquerda (a marca é de cor lisa, a agulha é simétrica). O mostrador, o anel e os botões nunca giram.
- O estado nunca é só cor: o botão do celular e o atalho afundam; o anel cheio também acende o miolo; a bússola seguindo engrossa o aro; o interruptor muda o botão de lado.
- Dentro da barra, a divisão entre a parte do céu e o selo de modo é uma coluna de 1 px de contorno e 1 px de `#3d3357`, desenhada pelo código; não há imagem para ela.
- Nenhum PNG tem letra: a hora, o nível, o "N" da bússola e os rótulos continuam texto. O "N" pode sair: o norte é a metade clara da agulha.

## Regras do aviso

- `warn_tag` é a única moldura com faixas diagonais e a única com laranja no corpo: marca o que não é o jogo normal (DEBUG com algo forçado, relógio forçado). Nenhuma peça do jogo normal usa faixa diagonal.
- Rótulo em Silkscreen, na cor Essência, dentro do miolo (linhas 1 a 6, 18 dp), entre as duas pontas de faixas de 2 px. Altura sempre 24 dp; a largura é a do rótulo mais 18 dp de cada lado (borda de 5 px × 3 dp + 3 dp).
- VÉU INSTÁVEL não é aviso deste tipo: é estado do mundo, não de debug, e continua texto em violeta sem a `warn_tag`.
- Não use a `warn_tag` para bolsa cheia, custo que falta ou novidade: esses continuam com o texto tingido de Essência e com o `badge_dot`.
