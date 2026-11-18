# Estilo da interface em pixel art

Guia do visual da interface: a Bolsa e a Bancada (0.24.0), e desde a 0.26.0 o HUD do mapa, o celular e os apps. A arte sai de um arquivo só, `tools/art/ui/build_ui.lua` (linhas de pixels e paleta), que gera os `.aseprite` em `tools/art/ui/`, os PNGs em `tools/art/ui/out/` e a folha de contato `out/contact_sheet.png`. Para mudar um desenho, edite as linhas e rode `aseprite -b --script tools/art/ui/build_ui.lua`; nunca edite o PNG à mão. Os tokens de cor e de espaço são os de `app/lib/ui/tema.dart`.

## Onde este guia contradiz o GDD

- `docs/referencias-de-arte.md` descreve o selo como "círculo violeta com runa em triângulo". Vale para o Selo simples e o reforçado; os selos de tipo levam a cor do tipo no disco, com a mesma runa, porque doze discos violeta não se distinguem na grade.
- Nenhuma outra contradição conhecida. Os ícones de itens mágicos (selos, tintas, Trama do Véu, fumaça de Fenda) usam o violeta do Véu; os materiais brutos não, como no mapa (`docs/art/estilo-mapa.md`, "Materiais no mapa").

## Grade

- Um pixel de arte são 3 dp, desenhado como bloco inteiro, com `FilterQuality.none`. Todo PNG está em 1 px por pixel de arte.
- Toda medida de layout é múltipla de 3 dp (`KEspaco`). Moldura, ícone e ponto caem sempre na mesma grade: nada de meio pixel de arte, nada de ícone em outra escala.
- Texto não é arte: rótulos e números em Silkscreen, frases em Pixelify Sans. Nenhum PNG tem letra.

## Paleta e papel de cada cor

| Cor | Hex | Papel |
|---|---|---|
| Contorno | `#1a1424` | toda borda de moldura e de ícone; nunca preto |
| Fundo | `#120e1a` | o rebaixado: célula da bolsa, trilho da barra, aba apagada, miolo da faixa |
| Superfície 1 | `#1e1830` | o painel e a folha |
| Superfície 2 | `#2a2240` | botão apertado e desativado, a lateral do botão, a célula selecionada |
| Linha | `#3d3357` | a face do botão, a luz fraca (esquerda do painel, baixo e direita do rebaixado) |
| Realce | `#56507a` | a luz forte: a borda de cima do painel e do botão |
| Véu | `#9b7bff` (claro `#c9b8ff`) | o que é do jogador: a seleção. Aba ativa, célula selecionada, borda da folha de detalhe |
| Sinal | `#5fd3c6` (claro `#a5efe6`, escuro `#2e8f86`, apagado `#2f5f66`) | o que vem do mundo, lido agora: a faixa de condições e a barra de capacidade |
| Essência | `#ff7a45` | só o que pede ação agora (bolsa cheia, custo que falta). Nenhuma moldura a usa; o código tinge |

Violeta, ciano e laranja nunca são decoração: se uma moldura tem violeta, é porque está selecionada. Os ícones usam a paleta dos materiais do mapa (`material_sprites.dart`), três tons por material.

## Contorno e luz

- Contorno de 1 px em `#1a1424` em volta de toda moldura e de todo ícone, fechado. Canto com chanfro de 1 px (o pixel do canto fica transparente).
- A luz vem de cima à esquerda. Em relevo (painel, botão): realce na borda de cima, luz fraca na esquerda, sombra na direita e embaixo. Rebaixado (célula, trilho da barra): o contrário, contorno em cima e à esquerda, linha clara embaixo e à direita.
- Sem gradiente, sem pontilhado e sem suavização nas molduras e nos ícones. O único brilho suave é o do amuleto no Conjurador (`gear_amulet_glow.png`), no violeta do Véu.

## Molduras em nove partes

As bordas ficam em `tools/art/ui/out/slices.json`, em pixels de arte, na ordem `[esquerda, topo, direita, baixo]`. O `centerSlice` é `Rect.fromLTRB(esq, topo, largura - dir, altura - baixo)` em pixels da imagem, com a imagem ampliada 3 vezes. O miolo é de cor lisa e pode esticar; os cantos nunca esticam.

| Arquivo | Tamanho | Bordas | Uso |
|---|---|---|---|
| `panel.png` | 12 × 12 | 4, 4, 4, 4 | painel em relevo |
| `sheet.png` | 12 × 6 | 3, 3, 3, 1 | folha de baixo: só a borda de cima, com a linha violeta; laterais e fundo sangram |
| `tab_on.png` | 12 × 10 | 2, 4, 2, 2 | aba ativa: linha violeta em cima, aberta embaixo |
| `tab_off.png` | 12 × 10 | 2, 4, 2, 2 | aba apagada: 1 px mais baixa, rebaixada |
| `button.png` | 12 × 11 | 2, 2, 2, 3 | botão: face, realce em cima e 2 px de lateral embaixo |
| `button_pressed.png` | 12 × 11 | 2, 4, 2, 1 | apertado: a face desce 2 px e a lateral some |
| `button_disabled.png` | 12 × 11 | 2, 2, 2, 3 | desativado: mesma forma, sem realce |
| `cell.png` | 8 × 8 | 2, 2, 2, 2 | célula da bolsa e espaço do Experimentar, rebaixada |
| `cell_selected.png` | 8 × 8 | 3, 3, 3, 3 | célula selecionada: anel violeta |
| `bar_frame.png` | 8 × 6 | 2, 2, 2, 2 | trilho da barra de capacidade |
| `bar_fill.png` | 3 × 4 | 1, 1, 1, 1 | enchimento: fica 1 px para dentro do trilho, com 4 px de altura |
| `chip.png` | 8 × 7 | 2, 2, 2, 2 | a faixa "Agora, aqui": chanfro e aro de 1 px no ciano do sinal |

- As abas sobem 2 px por cima do painel: as duas últimas linhas da aba cobrem o contorno e o realce de cima do painel. A apagada redesenha esses dois e a ativa os abre.
- As três imagens de botão têm o mesmo tamanho, então o botão não muda de lugar; o conteúdo desce 2 px no apertado porque a borda de cima dele é 4 e a de baixo 1 (os três somam 5 px de borda vertical).
- O código (0.24.1) põe o conteúdo sempre a pelo menos a borda × 3 dp + 3 dp de cada lado: uma moldura nova não corta o texto.
- Moldura nova: largura e altura de até 12 px, miolo de pelo menos 2 × 2 px liso, e o corte sempre depois do último pixel que não é de cor lisa.

## Estados de botão

Normal: face `#3d3357`, realce `#56507a`, lateral `#2a2240`. Apertado: face `#2a2240`, sombra `#120e1a` em cima e à esquerda. Desativado: face `#2a2240`, lateral `#1e1830`, texto em `textoMudo`. O estado nunca é só cor: o apertado afunda e o desativado perde o realce. O botão de ação principal não tem imagem própria; se precisar de destaque, o rótulo é que muda de cor.

## Ícone de 16 px

- Quadro de 16 × 16; o desenho ocupa de 10 a 13 px e fica centrado, com 1 px de folga no mínimo.
- Silhueta primeiro: o ícone tem de se ler só pela forma, em cinza. Cor e emblema são a segunda leitura.
- Três tons por material (claro em cima à esquerda, base, escuro embaixo à direita) e contorno fechado. Furo de verdade é transparente (a engrenagem, o anel).
- Famílias dividem a forma e trocam o miolo. Garrafa alta de rolha: o que cai do céu. Frasco redondo escuro: luz de lua, com a fase dentro (crescente acesa pela esquerda, minguante pela direita: hemisfério sul). Lata: vela e fumaça. Frasco cônico: tônico. Disco com runa: selo. Cordão e engaste: amuleto, com emblema de 6 × 6. Não use a forma de uma família para outra coisa.
- Refinado é o material com outra cara, não um selo de "melhorado" por cima: o giz consagrado é a exceção, com a faísca violeta de 5 px, o único desenho sem contorno.
- `essence.png` e `dust.png` são neutros (branco, cinza claro, cinza), para o código tingir multiplicando pela cor do tipo. Não os desenhe coloridos.
- Nome do arquivo: a id sem `item.`, com `.` virando `_`.
- Antes de aprovar, veja o ícone na folha de contato, dentro da célula, ao lado dos vizinhos da mesma aba.

## Pontos de qualidade

`dot_common.png` (cinza), `dot_good.png` (ciano) e `dot_perfect.png` (ouro), 3 × 3 px cada. Qualidade comum leva 1 ponto, boa 2, perfeita 3, todos da cor do nível: quem diferencia é a quantidade, a cor só reforça. Ficam no canto de baixo à direita da célula, a 1 px da borda, com passo de 4 px (1 px de vão).

## Equipamento no Conjurador

Três camadas de 16 × 16, no quadro do Conjurador do mapa (`mapPlayerPx`), desenhadas por cima dele nesta ordem: `gear_bag.png` (alça na diagonal e bolsa no quadril direito da tela), `gear_bottle.png` (uma garrafa de 1 × 3 px no cinto; a segunda e a terceira a +2 px em x cada, mesmo y) e `gear_amulet_glow.png` (o brilho no peito). Valem para os três quadros do passo sem deslocar.

## O que nunca fazer

- Preto puro, gradiente, sombra borrada, canto arredondado por vetor, contorno em outra cor.
- Violeta, ciano ou laranja como enfeite, ou cor sozinha para dizer estado ou qualidade.
- Letra, número ou logotipo dentro de PNG.
- Ícone em outra escala, girado ou esticado; moldura esticada fora das nove partes.
- Dois ícones da mesma aba com a mesma silhueta e só a cor diferente, fora das famílias acima.
- Brilho em qualquer coisa que não seja o amuleto.

## Kit do HUD e do celular (0.26.0)

Seções para entrar em `docs/art/estilo-ui.md`. A arte sai de `tools/art/ui/kit/build.lua` (`aseprite -b --script tools/art/ui/kit/build.lua`), que gera os `.aseprite` em `tools/art/ui/kit/`, os PNGs e o `slices.json` em `tools/art/ui/kit/out/` e a folha `out/folha.png` (a 3×). O script recusa moldura maior que 12 × 12, miolo menor que 2 × 2 e qualquer linha ou coluna que estique sem ser lisa (sai como `PROBLEMA`).

### Onde este adendo muda o guia

- "Essência: nenhuma moldura a usa; o código tinge" ganha três exceções, todas de "pede atenção agora": `warn_tag`, `app_tile_new` e `badge_dot`. Fora delas a regra continua.
- "Véu: a seleção" passa a incluir a escolha ligada (`switch_on`) e o progresso do jogador (`xp_fill`). Hoje a barra de XP é ciano no código; o ciano fica só para o que se lê do mundo.
- A agulha da bússola deixa de ser laranja: norte em `#ece6ff` (texto), sul em `#56507a`. O laranja no HUD fica só para o aviso e a novidade.
- Três medidas de `HudSize` saem da grade de 3 dp e precisam mudar com as peças (ver "Regras do HUD").

### Molduras em nove partes (kit)

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

### Peças fixas (kit)

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

### Regras do HUD

- O HUD fica sobre o mapa, então toda peça é opaca, com contorno fechado e miolo escuro (`#120e1a` ou `#1e1830`). Nada de fundo translúcido: as cores com `alpha` de hoje (`kOutline.withValues(alpha: ...)`) saem.
- Medidas na grade de 3 dp. As peças pedem: `bar` 48 (igual), `side` 60 (era 56), `portraitH` 81 (era 76), `phone` 54 de largura por 57 de altura (era 56), `radar` 54 (era 48), `compass` 54 (era 52). O atalho temporário tem 33 dp de altura (11 px) dentro da faixa de 48.
- Cor no HUD: violeta só no XP e no que está selecionado; ciano só no que se lê do mundo agora (anel do Radar, marca da borda, bússola seguindo a direção); laranja só no aviso e na novidade. A moldura do retrato e a das marcações são neutras.
- O que gira: a agulha, em passos de pixel, e a `edge_mark`, só em 90°. Por isso as duas não têm luz de cima à esquerda (a marca é de cor lisa, a agulha é simétrica). O mostrador, o anel e os botões nunca giram.
- O estado nunca é só cor: o botão do celular e o atalho afundam; o anel cheio também acende o miolo; a bússola seguindo engrossa o aro; o interruptor muda o botão de lado.
- Dentro da barra, a divisão entre a parte do céu e o selo de modo é uma coluna de 1 px de contorno e 1 px de `#3d3357`, desenhada pelo código; não há imagem para ela.
- Nenhum PNG tem letra: a hora, o nível, o "N" da bússola e os rótulos continuam texto. O "N" pode sair: o norte é a metade clara da agulha.

### Regras do aviso

- `warn_tag` é a única moldura com faixas diagonais e a única com laranja no corpo: marca o que não é o jogo normal (DEBUG com algo forçado, relógio forçado). Nenhuma peça do jogo normal usa faixa diagonal.
- Rótulo em Silkscreen, na cor Essência, dentro do miolo (linhas 1 a 6, 18 dp), entre as duas pontas de faixas de 2 px. Altura sempre 24 dp; a largura é a do rótulo mais 18 dp de cada lado (borda de 5 px × 3 dp + 3 dp).
- VÉU INSTÁVEL não é aviso deste tipo: é estado do mundo, não de debug, e continua texto em violeta sem a `warn_tag`.
- Não use a `warn_tag` para bolsa cheia, custo que falta ou novidade: esses continuam com o texto tingido de Essência e com o `badge_dot`.


## Cores e ícones dos tipos (0.26.0)

Seção para o `docs/art/estilo-ui.md` (0.26.0). A fonte é `tools/art/ui/types/palette.lua`; os ícones saem de `tools/art/ui/types/build.lua` (`out/<tipo>.png` de 16 × 16, `out/<tipo>_8.png` de 8 × 8, folha em `out/folha.png`) e as Fagulhas de `tools/art/sparks/build.lua` leem a mesma paleta. Para mudar uma cor, edite o `palette.lua` e rode os dois, as Fagulhas primeiro.

| Tipo | id | Principal | Claro | Escuro | Ícone | Contraste no painel `#1e1830` |
|---|---|---|---|---|---|---|
| Fogo | `fire` | `#F0502E` | `#FF9C7A` | `#A82E1C` | chama, com língua à direita | 4,8 |
| Água | `water` | `#4A9CFF` | `#A4D0FF` | `#2A62B8` | gota de ponta fina | 6,1 |
| Planta | `plant` | `#4DBD62` | `#A2E8A0` | `#2B7A40` | folha na diagonal, com talo | 7,1 |
| Terra | `earth` | `#C0915A` | `#E6C594` | `#7E5A32` | pedra torta, com pico | 6,1 |
| Elétrico | `electric` | `#FFD23A` | `#FFEE9A` | `#B8901C` | raio em Z | 11,8 |
| Metal | `metal` | `#93A1B3` | `#CCD6E2` | `#566274` | lingote | 6,5 |
| Luz | `light` | `#FFF0B8` | `#FFFBE6` | `#CDB468` | sol de oito raios | 15,0 |
| Sombra | `shadow` | `#A677AB` | `#D2ABD6` | `#68426E` | lua escura (crescente) | 4,8 |
| Espectral | `spectral` | `#D3E2F4` | `#F2F7FF` | `#8A9DBA` | chama fria, oca | 13,0 |
| Digital | `digital` | `#A8F040` | `#DCFA9E` | `#62A01E` | pixel soltando pixels | 12,4 |
| Feérico | `fae` | `#FFA8E0` | `#FFD6F1` | `#C0669E` | par de asas de fada | 9,7 |
| Dracônico | `draconic` | `#DE4F84` | `#F797B6` | `#8E2852` | escama com quilha | 4,5 |

Contraste pela fórmula da WCAG 2, calculado pelo `build.lua`, que acusa qualquer principal abaixo de 4,5 no painel. Sobre o fundo `#120e1a` todos sobem (o menor é 5,0, do Dracônico).

#### Regra

- Tipo é sempre **cor + ícone**. A cor sozinha nunca diz o tipo: em escala de cinza Fogo, Sombra e Dracônico ficam no mesmo cinza, e Luz, Espectral, Elétrico e Digital também; quem separa é a silhueta.
- A cor principal de um tipo nunca é o ciano do sinal (`#5fd3c6` e vizinhos, que é das ferramentas e do que se lê do mundo) nem o violeta do Véu (`#9b7bff` e vizinhos, que é do jogador). Por isso o Digital saiu do verde-água para o verde-limão e a Sombra saiu do violeta apagado para o ameixa.
- O Fogo é vermelho, não laranja: o laranja `#ff7a45` é da Essência e só pede ação.
- Texto e número na cor do tipo usam a principal ou o claro. O escuro é só sombra de ícone e fundo de etiqueta: sobre o painel ele fica entre 2,1 e 3,2 em oito tipos e não serve para texto.
- Etiqueta de tipo: fundo no escuro, ícone de 8 e texto no claro, ou só o ícone de 8 ao lado do nome na principal.
- O ícone de 16 segue "Ícone de 16 px" (contorno fechado, três tons, luz de cima à esquerda). O de 8 é a exceção: chapado, sem contorno, porque o contorno comeria o desenho; só sobre painel ou fundo escuro, nunca sobre o mapa.
- Formas reservadas: nenhuma das doze vira ícone de item. O Metal é lingote porque a engrenagem já é a sucata; a escama do Dracônico tem o arco em cima e a ponta embaixo, o contrário da gota.
- As Fagulhas do mapa usam os mesmos três tons, com o miolo próprio de cada uma (`tools/art/sparks/sparks.json`).


## Como a integração usa o kit (0.26.0)

- **Ícones de 16 px em todo tamanho:** na grade do celular e no Céu saem a 3 dp por pixel (48 dp). Na barra do HUD (lua, clima) e nas peças fixas do HUD (retrato, botão do celular, anel do Radar, bússola) saem na maior escala inteira de pixel físico que cabe na caixa de antes (`UiIcon`, `UiPiece` em `app/lib/ui/kit.dart`): nítidos em qualquer densidade, e o HUD não cobre mais mapa do que antes. No moto g54 (2,625) são 7 pixels físicos por pixel de arte. Por isso o `HudSize` **não** mudou (a proposta do adendo de levar `side` a 60, `portraitH` a 81 etc. ficou de fora).
- **Etiqueta de tipo:** o nome no tom claro sobre o tom escuro do próprio tipo ficava entre 2,0:1 e 4,2:1. A etiqueta usa o fundo neutro `#120e1a`, o aro no tom escuro do tipo, o ícone de 8 e o nome no tom claro (9,1:1 ou mais). Continua cor + ícone.
- **Rótulo na face do botão (`#3d3357`):** o violeta do Véu (3,7:1), o cinza (3,6:1) e a Essência (4,49:1) viram o tom claro deles (`#c9b8ff`, o texto, `#ffa07a`). Teste: `test/ui/contrast_test.dart`.
- **Alvo de toque:** 48 dp em tudo que se toca (`test/ui/tap_target_test.dart`); ficha de filtro, abas e segmentos subiram de 36 e 42 dp para 48.
- **Painel:** `panelBox()` é a moldura `panel` em nove partes (imagem fatiada na decoração), com o aro colorido por cima quando a tela pede destaque. `SwitchListTile` e `AlertDialog` do Material deram lugar a `KitSwitchTile` e `KitAlertDialog`, com os mesmos parâmetros. O menu de debug continua no estilo dele.

