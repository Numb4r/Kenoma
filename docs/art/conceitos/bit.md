# Bit (Digital)

- **Bicho:** pombo (*Columba livia*), sem troca. Cinza-azulado, duas barras escuras na asa, ponta da cauda escura, pés rosa e o brilho verde e magenta do pescoço, que já parece uma tela.
- **Pedaço da cidade:** tela e letreiro digital (moldura, vidro escuro, matriz de LED, cabo solto).
- **Traço-assinatura:** glitch na plumagem. Uma faixa do corpo anda de lado, com a ponta magenta de um lado e verde do outro, e o brilho do pescoço é feito de subpixels acesos.
- **Luz do tipo:** pixel aceso em verde `#6FE08A`, magenta `#E070C8`, azul `#5A8CFF` e branco `#F2F2FF` (as cores do pescoço do pombo, não o ciano do sinal).

## Etapas

- **Fagulha (Static Mote):** uma pena de pombo que se desfaz em pixels pela ponta.
- **Eco (Bitling):** o pombo de perfil, em proporção de pombo; o pescoço brilha em subpixels e uma faixa do corpo está dois pixels fora do lugar, com as barras da asa acesas em azul.
- **Espírito (Glitchkin):** o balanço da cabeça ficou preso em quadros: três pescoços e três cabeças (a segunda com linhas de varredura, a terceira só matriz de pixels), três pernas, duas caudas, uma tela rachada no peito e a asa em fatias.
- **Entidade Maior:** o painel de LED da fachada. Três asas em cata-vento saem de dentro da tela; o rosto está na tela, deitado, um olho só; em cima, três pescoços sem cabeça; embaixo, três pernas que não pisam em nada e um cabo solto.
- **Arquétipo:** o quadro repetido. Nove telas em roda em volta do vão (o Véu aparece nele); em todas, o mesmo pombo sem cabeça no mesmo instante. Do bicho sobram três asas de cinza, penas presas nas molduras e sete pés pendurados.

## Regras quebradas

- **Entidade Maior (física):** uma imagem plana tem fundo. As asas começam dentro da tela, como imagem, atravessam a moldura e continuam do lado de fora como pena.
- **Arquétipo (geometria):** nove telas planas, viradas para quem olha, cada uma na frente da anterior, e a primeira na frente da última: a roda não tem a tela de trás.
- **Arquétipo (física):** uma coisa só em muitos lugares no mesmo instante. O mesmo pombo, na mesma pose, está inteiro em cada tela, e nada ali passa.

## Régua (mapa / retrato)

| Etapa | Opacos | Cores | Detalhe | Contorno | Emissivo |
|---|---|---|---|---|---|
| Fagulha | 51 / 2254 | 9 / 10 | 0,97 / 0,66 | 0,43 / 0,09 | 0,18 / 0,14 |
| Eco | 286 / 1950 | 15 / 16 | 0,97 / 0,96 | 0,25 / 0,12 | 0,10 / 0,07 |
| Espírito | 418 / 2218 | 19 / 19 | 0,95 / 0,96 | 0,19 / 0,10 | 0,13 / 0,11 |
| Entidade Maior | 784 / 2860 | 17 / 17 | 0,94 / 0,88 | 0,24 / 0,14 | 0,14 / 0,13 |
| Arquétipo | 1752 / 6345 | 17 / 17 | 0,94 / 0,84 | 0,22 / 0,12 | 0,19 / 0,22 |

O Eco do mapa é desenhado pixel a pixel. O glitch (`tear`) só passa por partes largas do corpo, para nenhuma peça se soltar. Pés e pernas da Entidade e do Arquétipo ficam sem contorno (contorno seletivo).
