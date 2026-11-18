# Estilo do mapa 2D

Guia do estilo do mapa: nasceu no laboratório visual da 0.21.0 e, desde a 0.22.0, é o estilo **Completo** do mapa do jogo (`app/lib/ui/city/`), em todos os biomas. O estilo de antes continua como **Simplificado** nos Ajustes. Direção: entre o GTA 2 (prédio com altura falsa visto de cima) e o Stardew Valley (chão e vegetação com textura). Os números e as cores vivem em `app/lib/ui/sprites/map_style.dart`; este documento diz como usar. O 3D foi descartado.

## Onde este guia contradiz o GDD

- **Cores do mundo** (GDD rev 358, Clima e eventos): o ciano é o sinal das ferramentas do Conjurador e o violeta é o jogador. **Nenhuma ameaça do Véu usa essas duas cores**: a Vigília, a Lua Carmim e o que vier do Choronzon vão no vermelho, longe também do laranja da Essência.
- **Direção de arte, Regras de estilo** ("cidade em tons frios dessaturados, sem placas") e o pré-prompt de `docs/referencias-de-arte.md` ("no dithering, no signs, grey-indigo only"): o mapa passa a ter cor de material (grama verde, cerâmica, reboco creme), pontilhado no chão e letreiros no Iluminado. O que se mantém da regra: letreiro nunca tem texto, nada de carros ou pessoas, e **as três cores da magia continuam exclusivas**. Nenhuma cor da cidade é violeta `#9b7bff`, ciano `#5fd3c6` ou laranja brasa `#ff7a45`; o neon é rosa, lima e azul, a cerâmica é um marrom avermelhado bem menos saturado que a brasa. A cidade segue menos saturada que a magia.
- **Direção de arte, Câmera** ("ângulo 3/4 fixo, projetando telhado e paredes conforme o ângulo"): a projeção vira a do GTA 2, de cima, com o telhado deslocado a partir do centro da tela.
- **Direção de arte, Prédios** ("altura visual máxima de dois tiles"): mantido. Nenhum prédio passa de 32 px de arte de altura falsa.

Se a direção ficar, o GDD e o pré-prompt precisam ser atualizados nessas três seções.

## Grade

- Pixel de arte de **2 dp** (0.25.0; era 3 dp), um número inteiro de pixels físicos, ampliado por vizinho mais próximo. Nada de suavização no chão, nos prédios e nos carimbos. Os tamanhos no mundo são os mesmos de antes: carimbos, texturas e sprites têm 1,5 vez os pixels (árvore `tree` 21×20, Conjurador 24×24, Eco 28, Espírito 36, material 15), redesenhados, não ampliados. Os números em pixels deste documento escritos antes da 0.25.0 são da grade de 3 dp: multiplique por 1,5.
- Carimbo nunca gira nem escala: fica alinhado à grade da tela, e só a posição dele acompanha o mapa. Desde a 0.22.2 a textura é do que ela cobre: o módulo de chão gira com o chão (remendo, óleo, junta e onda da calçada nunca ficam presos à tela) e o módulo do telhado fica alinhado à aresta mais longa do contorno e gira e anda exatamente com ele. A posição e a escolha saem de hash da célula do mundo, nunca de coordenada de tela nem de `Random`.
- O pontilhado (`ditherPct`) também é ancorado no mundo, como a textura de ruído de hoje.
- Suave só pode ser luz: poça de poste, halo de neon, faixa do céu, tom da hora.
- Contorno `outline` (`#1a1424`) de 1 px em telhado, copa de árvore, arbusto e letreiro. Chão não tem contorno; a borda entre dois chãos é 1 px do tom `dark` do chão de cima.

## Paleta

Três tons por material (`_dark`, base, `_light`), e cada chão num degrau de valor, para a cena se ler em cinza. Do mais escuro ao mais claro:

| Material | Chave base | Hex (escuro, base, claro) | Luma da base |
|---|---|---|---|
| Asfalto | `asphalt` | `#2b2f3d` `#343949` `#40465a` | 57 |
| Água | `water` | `#234a70` `#2a5580` `#3b6c9a` | 77 |
| Pedra do Sagrado | `sacred` | `#4a4560` `#5a5474` `#6c668a` | 89 |
| Terra de baldio | `dirt` | `#5f5443` `#736652` `#877a64` | 104 |
| Grama | `grass` | `#2f7446` `#429658` `#5fb26a` | 118 |
| Concreto | `concrete` | `#6a707f` `#7c8291` `#8e94a2` | 130 |
| Grama de quintal | `yard` | `#5a8a4e` `#6fa05e` `#8ab874` | 138 |
| Cimentado do Residencial | `res` | `#847c6f` `#968e80` `#a8a092` | 143 |
| Cimento claro (Iluminado sem informação, área comercial) | `cement` | `#808492` `#9094a2` `#a0a4b0` | 148 |
| Calçada | `sidewalk` | `#8e92a0` `#a3a7b3` `#b6bac4` | 167 |
| Piso ladrilhado (só `paved`) | `lit` | `#adabb9` `#c2c0cc` `#d4d2dc` | 194 |

Por cima do chão: copa `canopy` (`#1f5a3a` `#2c7048` `#45905a`, sempre mais escura que a grama), mato `weed`, flores `flower_white` `flower_yellow` `flower_pink`, pedrinha `pebble`, faixa `lane` `#c9c4a8` e `lane_worn` `#8f8c7c`, óleo `oil`.

Prédios: paredes `wall_res` (creme), `wall_res_b` (azulado claro), `wall_urban` (cinza), `wall_lit` (quase branco), `wall_sacred` (cal), `wall_bare` (tijolo), cada uma com `_shade`. Telhados `roof_tile` (cerâmica `#a8553d`), `roof_slab` (laje cinza quente `#56525a` `#6e6a70` `#86828a`, luma 108), `roof_tar` (manta escura), `roof_metal`, `roof_slate` (ardósia azulada). Janelas `window_off`, `window_on`, `window_on_cool`. Neon `neon_a` rosa, `neon_b` lima, `neon_c` azul, `neon_off` de dia. Sombra `shadow` é o contorno ameixa a 42%; o renderizador lê o alfa da paleta.

A laje é a massa dominante do Centro e por isso é de valor médio e lisa: mais escura que a calçada (167) e que o concreto (130). Grade é só de piso (`floor_lit`, e só no chão `paved`); a calçada comum tem junta discreta (`sidewalk_joint`, luma 157) e telhado nenhum tem junta em grade. Quem brilha na cena é a calçada, o piso das praças e a magia; a parede é sempre mais escura que o telhado dela.

Limite: a cena de um bioma usa no máximo 3 tons de chão, 3 famílias de verde (3 tons cada, todas abaixo da grama), 3 pares de parede e 5 materiais de telhado (3 tons cada). Não crie tom intermediário no código; se faltar cor, ela entra na paleta com nome.

## Chão de cada bioma

Cada chão é uma `GroundRecipe`: tom base, `ditherPct` de pixels trocados (metade escuros, metade claros) e `stampsPer100Px` carimbos por bloco de 100 x 100 px de arte, sorteados na lista (nome repetido pesa mais).

| Chave | Cara | Receita |
|---|---|---|
| `empty` / `void` | terra batida neutra, sem carimbo | 10% de pontilhado, 0 carimbos |
| `lot` / `vacant` | lote vazio e terreno baldio: a mesma terra com mato | 16%, 45 |
| `urban` | concreto liso neutro, sem carimbo | 5%, 0 |
| `green` | grama cheia: tufos, três flores, arbusto | 18%, 60 |
| `water` | azul com reflexos curtos; borda de 1 px `foam` contra a margem | 10%, 20 |
| `residential` | cimentado quente neutro, sem carimbo | 6%, 0 |
| `yard` | grama clara de quintal, uma flor amarela, arbusto | 14%, 35 |
| `lit` | cimento claro liso (148), sem módulo e sem carimbo | 4%, 0 |
| `sacred` | pedra violácea neutra, sem carimbo | 6%, 0 |
| `paved` | área de pedestre e praça calçada do OSM: o único chão ladrilhado (módulo `floor_lit`) | 4%, 0 |
| `parking` | asfalto com vagas pintadas (módulo `parking_bay`, 4 x 16) e óleo raro | 8%, 2 |
| `lot_res` | lote residencial: terra batida clara com tufo de grama | 12%, 18 |
| `commercial` | área comercial: cimento claro liso | 3%, 0 |
| `sidewalk` | concreto liso com junta discreta (módulo `sidewalk_tile`, placas de 8 px) e rachadura rara | 3%, 2 |
| `road` | asfalto com desgaste, rachadura, óleo e remendo | 10%, 6 |

Desde a 0.23.1 o chão segue o uso do solo do OSM (`pipeline/build_ground.py`, `<região>_e0_ground.bin`, cenário fora das épocas): por cima do chão neutro do bioma vão o lote residencial (`landuse=residential`), a área comercial (`landuse=commercial|retail`), o terreno baldio (`landuse=brownfield|greenfield|construction`), o estacionamento de superfície (`amenity=parking`) e o piso de pedestre (`highway=pedestrian`, `area:highway=pedestrian`, `place=square`), nessa ordem. Onde não há informação, vale o chão neutro do bioma: só o tom e um pontilhado leve, sem módulo e sem carimbo com cara de objeto. Ladrilho só em `paved`. Módulo de chão tem lados que dividem 64.

No mapa (0.22.0), a célula de Vazio só fica de terra batida em campo aberto: com casa dentro, ela leva o chão do Residencial; cercada de cidade (3 ou mais vizinhas de Urbano, Residencial, Iluminado ou Sagrado), leva o chão mais comum delas. Só desenho: a grade lógica não muda.

Como distinguir os quatro que hoje se confundem: **Vazio** é marrom e mato, o único chão de terra; **Urbano** é cinza frio e liso; **Residencial** é bege com manchas verdes de quintal e telhado vermelho; **Iluminado** é cimento claro e liso, com telhado escuro e neon; o piso ladrilhado e mais claro da cidade fica só nas áreas de pedestre e praças calçadas.

## Rua, faixa e calçada

- Asfalto com a receita `road`. O desgaste é o pontilhado; nas ruas `principal` ele cai para a metade (asfalto mais novo).
- Faixa central só em `principal` e `secondary`: tracejado de 1 px de largura, 4 px aceso e 6 px apagado, na cor `lane`. Um traço em cada quatro sai em `lane_worn` e um em cada sete some (hash do traço). Rua `local` não tem faixa. Trilha `pedestrian` usa a receita `sidewalk`.
- Calçada de 2 px de cada lado nas ruas `local` e 3 px nas maiores: concreto liso com o módulo `sidewalk_tile` (junta de 1 px a cada 8 px, num tom vizinho) e meio-fio de 1 px `sidewalk_dark` do lado do asfalto. A calçada portuguesa (`sidewalk_mosaic`) fica só no Centro (a zona `mosaic_zone` de `pipeline/regions.json`, no arquivo de uso do solo).
- Faixa de pedestre e semáforo ficam de fora: não há dado de cruzamento.

## Grama, flores, árvore e sombra

- Tufos e flores só nas receitas `green`, `yard` e `sacred`. Flor nunca encosta em rua: se o carimbo cair a menos de 2 px de outro chão, não desenhe.
- Árvore: carimbo `tree` (14 x 13) com a sombra por baixo (a silhueta da copa achatada a 70%, na cor da sombra), deslocada de 2 a 6 px na direção oposta ao sol (mais longe com o sol baixo, some com o sol abaixo de 0 grau). No Verde, uma árvore a cada 500 px de arte quadrados em média, em grupos (sorteie por célula z21: célula com árvore tem de 1 a 3). No quintal, no máximo uma por lote. Na calçada do Iluminado e do Urbano, uma a cada 40 px ao longo das ruas `principal`, alternando com os postes.
- Arbusto (`bush`) acompanha muro e borda de parque.
- A copa passa por cima de rua e calçada, mas nunca por cima de telhado.

## Muro e quintal

No Residencial, o espaço do lote que o prédio não ocupa é quintal (`yard`), e o lote é cercado por muro: linha de 1 px `fence` com 1 px `fence_dark` do lado oposto ao sol. Sem dado de lote, use a regra: em volta de cada prédio `house` ou `residential`, o anel de 4 a 6 px (hash do prédio) é quintal, e o muro corre na borda de fora do anel, aberto no lado que dá para a rua mais próxima. Muro não projeta sombra longa: só 1 px.

## Prédios

Altura falsa em pixels de arte (o telhado se desloca do centro da tela para fora, proporcional à altura e à distância do centro; no centro exato, deslocamento zero):

| Tipo OSM | Altura | Estilo (`wallStyleFor`) |
|---|---|---|
| `house`, `residential`, `detached`, `terrace`... | 5 | reboco creme, telha de cerâmica, janela |
| `apartments`, `office`, `hotel`, `school`, `hospital` | 14 (até 24 com `building:levels`) | parede cinza, laje, janela |
| `commercial`, `retail`, `supermarket` | 8 | fora do Iluminado: cinza e laje; no Iluminado: parede quase branca, manta escura, vitrine |
| `industrial`, `warehouse`, `garage` | 9 | parede cinza escura cega, telha metálica |
| `church`, `chapel`, `temple`... | 16 | cal, ardósia azulada |
| `yes` e desconhecidos | 6 | pelo bioma: Residencial, Verde e Água como casa; Iluminado como comércio; Urbano como bloco; Vazio com tijolo sem reboco e fibrocimento (`roof_metal`); Sagrado como igreja |

- Prédio sem tipo no Urbano (quase todo o Centro): o renderizador escolhe o tipo pela área da planta antes de chamar `wallStyleFor`. Menos de 150 m²: `house` (sobrado antigo, telha, altura 5). Mais de 1200 m²: `warehouse` (galpão ou mercado, telha metálica, altura 9). O resto: bloco de laje.
- Teto: módulo `roofPattern` repetido (ancorado no prédio, não na tela), com borda `roofEdge` de 1 px.
- Caixa d'água: carimbo `roof_tank` (5 x 5, azul de ardósia), um por telhado de laje com 150 px² ou mais, a até 3 px do centro do telhado (hash do prédio). Nunca em telha, metal ou ardósia.
- Paredes: as faces viradas para o sol usam `wall`, as outras `wallShade`. Uma em cada três casas (hash do prédio) troca `wall_res` por `wall_res_b`.
- Janelas: o módulo de 4 x 4 (`window_*`) ou de 6 x 4 (`window_shop_*`) repetido ao longo da parede, só quando a parede visível tem 4 px ou mais de altura. Parede mais baixa que isso fica lisa.
- Sombra projetada: `shadow` (`#161A36` a 30%, 0.23.2), no ângulo real do sol, comprimento proporcional à altura e limitado a 3 vezes ela. É translúcida: escurece o chão e mantém 70% do contraste dele (asfalto 57 → 49, grama 118 → 91, calçada 167 → 125; a vaga `lane_worn` fica em 105 sobre o asfalto em 49). A cor e o alfa saem da chave `shadow`; o renderizador mistura o tom frio de `sceneLightSplit` nela, nunca no contorno. Sem sombra com o sol abaixo de 0 grau.
- A sombra cai também no telhado do vizinho mais baixo: comprimento pela diferença de altura, recortada no telhado dele, no mesmo pano das outras (nunca escurece duas vezes). Em bairro denso é ela que conta a hora.
- Perto de Fenda e em evento, os efeitos do GDD (costura violeta, janela ciano, janela vermelha na Lua Carmim) entram por cima deste estilo; são as únicas cores de magia permitidas em prédio.

## Janelas, letreiros e neon

- Com `lightsOn` falso, toda janela usa `window_off` (ou `window_shop_off`).
- Com `lightsOn` verdadeiro, acende por hash da janela: 45% no Residencial, 30% no Urbano, 20% no Vazio, 15% no Sagrado, 85% das vitrines do Iluminado. Depois da meia-noite local, metade das janelas de casa apaga; vitrine não.
- Letreiro só no Iluminado e só em prédio de comércio: um por fachada voltada para a rua, colado na borda do telhado. Formas: `sign_bar`, `sign_blade`, `neon_ring`, `neon_arrow`. Nunca texto.
- De dia o neon está apagado: troque `neon_a`, `neon_b` e `neon_c` por `neon_off`. À noite, a cor cheia mais um halo suave da mesma cor com 6 px de raio a 35%.
- A cor do neon de cada loja sai do hash do prédio; lojas vizinhas não repetem a cor.

## Postes e poças de luz

- Poste: carimbo `lamp` na calçada, um a cada 40 m em ruas `principal` e `secondary` (lados alternados) e um a cada 60 m nas `local`. Poste a menos de 18 m de outro já colocado não entra (os cruzamentos amontoavam). Vazio não tem poste; Sagrado tem um por entrada.
- Poça de luz, só com `lightsOn`: disco de `lamp_glow` com 8 px de raio em três anéis (raios 3, 5 e 8 px; 34%, 20%, 10% de opacidade), o de fora pontilhado. No Iluminado, `lamp_glow_lit` com 10 px. O raio não cresce com o zoom além de 1,5 vez.
- A poça é luz de chão: recortada para fora dos telhados, nunca sobe em prédio. Na tela inteira as poças somadas ficam abaixo de um quinto da área; a noite é escura com ilhas, não um tapete amarelo.
- As poças, as janelas acesas e o neon são desenhados **depois** do tom da hora, sem tom por cima: é isso que faz a noite ter ilhas de luz.

## Curva de luz

`sceneLight(sunAltDeg)` devolve a cor e a opacidade de um retângulo pintado por cima de chão, prédios e sprites. Mistura linear entre os pontos:

| Altitude do sol | Momento | Tom | Opacidade |
|---|---|---|---|
| -18 ou menos | noite | `#141033` | 0,58 |
| -6 | fim do crepúsculo civil | `#2a1f55` | 0,46 |
| 0 | sol no horizonte | `#d8707a` | 0,24 |
| 8 | hora dourada | `#ffc98a` | 0,16 |
| 35 | meia manhã, meia tarde | `#ffe2b0` | 0,09 |
| 90 | zênite | `#ffffff` | 0,00 |

O quente dura até os 35 graus de propósito: às 7h30 (sol a uns 29 graus) a cena leva cerca de 10% de âmbar e o horizonte fica creme; ao meio-dia, nada de tom e o céu mais fundo. O resto da diferença entre manhã e meio-dia é o comprimento da sombra.

As luzes acendem com o sol a 1 grau abaixo do horizonte (`lightsOn`), poucos minutos depois do pôr do sol em Campinas, e apagam na mesma altitude de manhã. A curva só depende da altitude, então amanhecer e entardecer têm o mesmo tom.

## Céu do horizonte

- Faixa no topo da tela, por baixo do HUD de cima. Na 0.21.0 eram 36 px de arte (108 dp); desde a 0.22.0, 6% da altura da tela, no máximo 10% (ver "Luz, chuva e horizonte"). Na borda de baixo, a névoa de distância (item 14 de "Luz, chuva e horizonte"). Desde a 0.23.2 a faixa começa embaixo da barra do HUD, e o HUD fica no topo da tela, desviando só do furo da câmera.
- `skyGradient(sunAltDeg)` dá 4 cores de cima para baixo; pinte em 4 bandas com 2 px de pontilhado entre elas, sem gradiente contínuo.
- Nuvens: carimbo `cloud`, de 2 a 5 na faixa conforme a cobertura do clima, andando devagar com o vento. À noite, misture a nuvem 60% com a primeira cor do céu.
- A faixa é o panorama do lado para onde o topo da tela aponta: a posição horizontal de sol, lua e eventos é o azimute deles menos o rumo da câmera, com -60 a +60 graus ocupando a largura. Girar o mapa gira o céu.

Céu por clima (misture cada cor do gradiente com a cor do clima usando `mixArgb`):

| Clima | Cor | Força | Nuvens |
|---|---|---|---|
| Limpo | nenhuma | 0 | 0 a 2 |
| Nublado | `#8a8fa3` | 0,45 | 5, juntas |
| Garoa e chuva | `#6c7186` | 0,60 | teto fechado: banda `cloud_shade` nos 10 px de cima |
| Tempestade | `#3d4254` | 0,75 | teto fechado escuro; o relâmpago clareia a faixa inteira por um quadro |
| Neblina | `#c2c0d2` | 0,70 | sem nuvem; a neblina de baixo sobe para 16 px |
| Sol forte | `#fff0d0` | 0,15 | 0 |

## Onde mora o céu dos eventos

Tudo que é céu de evento fica dentro da faixa, nunca sobre o mapa. As cores são as do evento, não desta paleta.

| Evento | Lugar na faixa |
|---|---|
| Arco-íris | arco inteiro, do lado oposto ao sol, com os pés na neblina |
| Aurora | cortinas nos 20 px de cima, na largura toda |
| Luas (cheia, Carmim, nova) | disco de 9 px no azimute da lua; a altura na faixa acompanha a altitude |
| Eclipse | no disco do sol ou da lua, no azimute dele; a faixa escurece junto com `sceneLight` |
| Olhos da Vigília | de 2 a 5 pares nos 12 px de cima, em vermelho (a cor da camada `eyes` em `eventos.json`), só sugeridos no pontilhado; nunca sobre o mapa e nunca com rosto |
| Prisma do Véu | reflexos de cor na neblina de baixo |

## 0.22.0: do laboratório para o mapa

### O que gira e o que fica de pé

- **Gira com o mapa** (o chão): ruas, lotes, grama, calçada, faixas, faixa de pedestre, quintal e muro, as marcas do clima no chão, as sombras dos prédios (seguem o sol, são do mundo), o contorno dos telhados e a textura de tudo isso (0.22.2: o chão e o telhado levam a textura junto; o telhado, presa à aresta mais longa).
- **Gira com o rumo** (exceção aprovada pelo dono na 0.23.0): carros, ônibus, ciclistas e barcos do tráfego, vistos de cima, apontam para onde andam; os nomes de rua acompanham a direção da rua. O modo de debug "Giro dos objetos" escreve a categoria de cada objeto sobre ele.
- **Fica de pé na tela**: tudo que tem altura ou é sprite. Árvores (e a sombra delas, a silhueta da copa, desde a 0.23.1), postes, ponto de ônibus, banca, props de telhado, letreiros, materiais, janelas, paredes, Ecos, avatar, passantes e textos. O lugar de um prop de telhado sai do chão (células z21, em volta do centro do contorno) e sobe com o telhado: gira e anda com o prédio, e o carimbo fica de pé. Todo carimbo é de pé (`uprightStampKinds`) ou de chão (`groundStampKinds`, em `turn_category.dart`), e o teste `test/ui/upright_turn_test.dart` desenha cada carimbo de pé a 0° e a 90° e exige os mesmos pixels: carimbo novo entra numa das duas listas. São desenhados na orientação da tela, na posição girada. As paredes e o deslocamento dos telhados saem sempre do centro da tela para fora, em qualquer giro.
- **Pixel nítido**: o chão nunca é uma imagem pronta que gira. Ele é rasterizado já girado, na grade de pixels da tela, em blocos de 4 × 4 células z21 (`city_ground.dart`). No arrasto e na pinça vale o bloco do ângulo mais próximo (passos de 3 graus) e do zoom mais próximo (passos de 6% a partir do zoom do começo do gesto, desde a 0.23.2), desenhado com o resto do giro e da escala (no máximo uns 3% de esticada); um quarto de segundo depois de o dedo soltar, os blocos são refeitos no ângulo e no zoom exatos. Com o mapa parado, todo bloco só desliza por pixels inteiros.

### Cache

O chão parado (chão, ruas, sombras, a planta dos prédios, a luz da hora, as poças de luz e o reflexo dos postes) é desenhado uma vez por bloco e só refeito quando o bloco entra na tela, quando o giro ou o zoom de alvo mudam, quando a luz muda de faixa (3 graus de altitude ou 5 de azimute do sol, uns 15 a 20 minutos), quando a chuva molha ou seca o asfalto, ou quando muda o nível de detalhe. Cada quadro refaz no máximo 4 ms de blocos (os que faltam primeiro). O que fica de pé tem deslocamento pela posição na tela e é desenhado a cada quadro, numa camada própria e barata.

### Prédios (as regras novas do `criativo`)

1. Escada de valor de todo prédio: telhado > parede no sol > parede na sombra. Lumas: laje 154, zinco 164, ardósia 149, fibrocimento 141, cerâmica clara 134, zinco velho 128, cerâmica 113, manta 99. Paredes (0.23.1, escurecidas para lerem como lateral de prédio): Centro 85 / 63 / 46, reboco 78 / 56, reboco azulado 78 / 57, Iluminado 106 / 78, Sagrado 108 / 79, tijolo 90 / 64. A janela apagada (`window_off`) é 36. O telhado sai do pé no máximo um quarto da distância do centro da tela até a borda, na direção dele (`kRoofEdgeShare`, 0.23.1): prédio alto não joga parede por cima da rua inteira.
2. Telhado por `roofVariantsFor(tipo, bioma)[hash do prédio % length]`. O metal fica no galpão (2 de 6) e no Vazio (1 de 4).
3. Platibanda: 1 px de `parapet` por dentro da borda, só quando `parapet != 0` (laje e manta).
4. Props: de `roofProps` (caixa d'água, ar-condicionado, antena), um em telhado de 150 px² ou mais e até 3 acima de 600 px², dentro do telhado. Cerâmica, metal e ardósia nunca têm prop.
5. Janelas: uma fileira a cada `floorPx` (4 px) de fachada visível, a partir de 2 andares; vitrine só no térreo.
6. Galpão: o prédio sem tipo do Urbano vira galpão acima de 2500 m² (era 1200); entre 150 e 2500 m², bloco.
7. A altura vem do OSM (`building:levels`, `height`) no arquivo `<região>_e0_bldg.bin`; sem dado, pelo tipo.

### Cara de Campinas

8. Calçada portuguesa (`sidewalk_mosaic`) só na zona do Centro. Fora dela, e em calçada de menos de 3 px, vale `sidewalk_tile`.
9. Faixa de pedestre nos pontos `highway=crossing` do OSM: barras de 1 px `crosswalk` no sentido da rua, 1 px de vão, uns 3 m de comprimento. Portão: 3 a 4 px de `gate` e `gate_dark` no muro, no meio da aresta mais longa do lote.
10. Árvores: `tree`, `tree_a`, `tree_b`, `tree_c` por hash, sem copas todas iguais; as do OSM (`natural=tree`) e as plantadas nos verdes. Ipê só perto de praça e parque, no máximo um em cada quatro árvores, `kind` por hash e `ipeStamp(kind, mês local)`: ipê-roxo em junho e julho, ipê-amarelo em agosto e setembro, só copa verde no resto. O ipê-roxo é rosa-magenta, nunca o violeta do Véu.
11. `bus_stop` nos pontos `highway=bus_stop` do OSM; `newsstand` em uma de cada três praças.

### Luz, chuva e horizonte

12. Luz: `sceneLightSplit` pinta `warm` em chão, telhado e parede no sol, e `cool` dentro das sombras e nas paredes de sombra, antes das luzes acesas. No pôr do sol, o lado iluminado fica quente e as sombras frias, em vez de um rosa por igual. O Simplificado segue em `sceneLight`.
13. Chuva: o asfalto vira `asphalt_wet` e `asphalt_wet_dark`, com `wet_shine` em pixels soltos; à noite, `lamp_reflect` numa faixa vertical curta e quebrada embaixo de cada poste, além das poças que já existem.
14. Horizonte: a faixa do céu ocupa 6% da altura da tela (o teto é 10%). Embaixo dela, a névoa na cor de `horizonFog(sunAltDeg)` (misturada com o céu do clima) dissolve o topo do mapa numa faixa curta: `max(5, 0,55 × céu)` fileiras (1,1 × céu na neblina), um ponto por pixel de arte, densidade `0,85 × u^1,6` (78% na primeira fileira, zero na última). O limiar é ruído de gradiente intercalado (IGN) sobre o pixel da tela, não matriz de Bayer: sem nível de 50% em xadrez e sem grade de pontos a cada 4 px (0.23.2; referência em `tools/art/ref/haze_0232_opcoes.png`). As linhas pontilhadas de 1 px entre as bandas do céu continuam.
15. Neve e geada: `snow` em pontilhado de 70% sobre o telhado, na posição deslocada dele, com `snow_shade`. Poças, alagamento e dunas ficam no chão.

### Nível de detalhe

Acima de 65 m de largura de tela (o zoom aberto do GDD vai a 80 m; com o "Zoom ampliado" dos Ajustes vai a 250 m e acima de 120 m o mapa passa para o Simplificado, sem tráfego, passantes, bichos nem partículas, e as ruas finas somem antes: trilhas acima de 120 m, locais acima de 200 m, secundárias acima de 400 m; o mapa de Rotas é sempre assim): sem `fineStamps` (flores, tufos, pedrinhas, props de telhado, antenas), metade do pontilhado do chão, sem paginação fina do piso, sem janelas, letreiros, faixa central e portões. O tráfego e os passantes a mais de 40 m do jogador andam no passo maior.

### Completo e Simplificado

O Simplificado (Ajustes, "Gráficos do mapa") é o estilo de antes: plano, sem altura falsa, sem vegetação detalhada, sem horizonte e com metade das partículas. Os dois mostram tudo que importa para o jogo (Ecos, Fagulhas, Aura, alcance, marcas do clima no chão e eventos), usam a mesma lógica e a mesma máscara de ruas, e a camada base de spawn é a mesma. Se o Completo passar de 20 ms por quadro em média por um minuto, o jogo sugere uma vez trocar, sem trocar sozinho.

## Materiais no mapa

Cada material que nasce no chão tem um sprite próprio em `app/lib/ui/sprites/material_sprites.dart` (`materialSprites`, `materialSpriteLegend`, `materialPalette`), numa matriz de 15 × 15 com o desenho de 10 a 12 px de arte (0.25.0; eram 5 a 8 px na grade de 3 dp), com contorno `outline` fechado. Fica de pé: não gira nem escala, 1 caractere é 1 pixel de arte, e a base do sprite fica no ponto do spawn. Fora da Aura, 60% de opacidade. Não pisca e não usa violeta, ciano nem laranja brasa: quem pulsa é a Fagulha (desde a 0.25.1 um sprite do Aseprite por tipo, com contorno, em `tools/art/sparks/`) e quem tem anel é o Eco. Até a 0.23.0 eram caixinhas coloridas (as "caixas cinza e brancas" do mapa).

## O que não fazer

- Preto puro, gradiente contínuo no chão ou nos prédios, carimbo girado ou ampliado.
- Violeta, ciano ou laranja brasa em qualquer coisa que não seja magia.
- Texto, logotipo, carro ou pessoa desenhados no cenário.
- Dois chãos vizinhos com a mesma luma: confira na tabela antes de criar um material.
