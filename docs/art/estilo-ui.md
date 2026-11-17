# Estilo da interface em pixel art

Guia do visual da Bolsa e da Bancada (0.24.0), e a base do redesenho do HUD. A arte sai de um arquivo só, `tools/art/ui/build_ui.lua` (linhas de pixels e paleta), que gera os `.aseprite` em `tools/art/ui/`, os PNGs em `tools/art/ui/out/` e a folha de contato `out/contact_sheet.png`. Para mudar um desenho, edite as linhas e rode `aseprite -b --script tools/art/ui/build_ui.lua`; nunca edite o PNG à mão. Os tokens de cor e de espaço são os de `app/lib/ui/tema.dart`.

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
