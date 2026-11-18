# Estilo das criaturas

O padrão que o Humoth fixou na 0.25.0 (GDD, "Direção de arte", Câmera). Toda família nova segue este formato; o Humoth (`tools/art/creatures/humoth/`, gerado por `build.lua`) é a referência de acabamento.

## Grade e tamanho

- Pixel de arte de 2 dp. No mapa, quadro de **28 × 28 px**; no Bestiário, retrato de **96 × 96 px**. Um tamanho de pixel só por sprite.
- A criatura olha para a **direita**; o código espelha. O centro do corpo fica em (14, 14) no quadro 0 do `idle`.
- Deixe 2 px livres em cima e 1 px embaixo no quadro 0 do `idle`: o corpo sobe e desce dentro do quadro e nada pode cortar na borda.
- Contorno de 1 px em `#1a1424` por fora da forma, nunca preto. Faísca solta não tem contorno.
- Sem sombra no desenho.
- Paleta do corpo curta: até 10 cores trocáveis (no Humoth: 3 de asa, 2 de asa de trás, 3 de pelo, 2 de antena). São elas as chaves do mapa de variantes.

## As três camadas

Cada animação sai em três tiras horizontais com os mesmos quadros, uma por camada:

| Arquivo | Camada | O que vai nela | O que o código faz |
|---|---|---|---|
| `<especie>_<anim>.png` | corpo | tudo o que não brilha, mais as partes emissivas **apagadas** num tom escuro (o olho desligado continua lendo como olho) | recebe o tom da noite e do clima e a troca de cor da variante |
| `<especie>_<anim>_leds.png` | leds | só o que **pisca**: ocelos, olhos, LEDs acesos | desenha depois do tom e faz piscar, fora de fase com o movimento |
| `<especie>_<anim>_glow.png` | glow | o que brilha **sem piscar**: veios, costuras, faíscas soltas | desenha depois do tom, sem piscar |

Regras: um pixel aceso em `leds` ou `glow` tem sempre o par apagado embaixo dele em `corpo` (menos a faísca solta, que só existe em `glow`). As cores apagadas e as emissivas não entram no mapa de variantes: ficam iguais em todas. Quando a animação pede brilho que cresce (alerta, fuga), ele é desenhado quadro a quadro em `glow`.

## Animações

Seis no mapa, mais o retrato. Os quadros e os fps do Humoth são o padrão; outra família pode mudar o fps no `<especie>.json`, não a lista.

| Animação | Quadros | fps | O que mostra |
|---|---|---|---|
| `idle` | 4 | 8 | parado: o movimento próprio da espécie em laço (bater de asa, respirar), o corpo sobe e desce 1 px |
| `drift` | 4 | 8 | deriva: o mesmo laço, inclinado na direção do movimento |
| `alert` | 3 | 6 | pose aberta e parada, o brilho crescendo em `glow`; `leds` fixos |
| `flee` | 6 | 12 | 1 quadro de antecipação (encolhe e desce 1 px), depois sobe e sai de lado deixando rastro em `glow` |
| `spawn` | 6 | 10 | 3 quadros só de faíscas se juntando, 1 de silhueta escura com os emissivos acesos, 2 abrindo até a pose do `idle` |
| `tuned` | 6 | 10 | 1 quadro inteiro e aceso, 3 se desfazendo de fora para dentro, 2 só de faíscas, a última juntando no centro |
| retrato | 4 | 6 | pairando: corpo e asas sobem em passos diferentes, os LEDs varrem, os veios pulsam |

O `<especie>.json` lista `frame`, `anims` (quadros e fps) e `body_dy` (quanto o corpo sobe em cada quadro, em pixels, negativo para cima). O do Humoth traz ainda `body_visible` (0 nos quadros que são só faísca, onde o acessório da variante não deve aparecer) e `portrait`.

## Variantes

A variante tem de se ler em **escala de cinza**: muda o **valor** do corpo e ganha um **acessório**; trocar só o matiz não vale.

- `<especie>_variants.json`: por chave (`urban`, `green`, `water`, `residential`, `lit`, `sacred`, `crimson`), o `map` de cor para cor do corpo e o `accessory`.
- O acessório é um PNG de 28 × 28 desenhado sobre o quadro 0 do `idle`. Fica no tronco (a parte que só se move por `body_dy`), nunca numa parte que bate ou balança, e tem forma e lugar próprios: dois acessórios não ocupam o mesmo ponto do corpo.
- Escada de valor do Humoth, do mais escuro ao mais claro: `crimson`, `water`, `urban`, base, `green`, `residential`, `sacred`, `lit`. Acessório claro em corpo escuro e escuro em corpo claro.
- O mesmo `map` vale para o retrato: o retrato só usa as cores do corpo que estão no mapa.
- O Brilhante não tem arquivo: é o único com brilho animado, feito em código.

## O que é desenhado e o que é código

| Desenhado | Código |
|---|---|
| os quadros das três camadas, olhando para a direita | espelhar para a esquerda |
| o corpo subindo e descendo dentro do quadro (`body_dy`) | deslocar o sprite no mapa (a fuga para cima e para o lado) |
| os emissivos acesos e apagados | o tom da noite e do clima no corpo, e os emissivos por cima sem tom |
| o brilho que cresce no alerta e o rastro da fuga | o piscar da camada `leds` |
| as faíscas do `tuned` até juntarem no centro | levar as faíscas até o Conjurador |
| o acessório e o mapa de cor da variante | aplicar o mapa, pôr o acessório em todo quadro com `body_dy`, o brilho do Brilhante |
| nada | a sombra no chão |

## Conferência

A folha `<especie>_folha.png` (4×, vizinho mais próximo, fundo de asfalto com o tom da noite) traz uma fileira por animação, na ordem da tabela, com o corpo no tom da noite e `leds` e `glow` por cima; depois três fileiras de variantes (base, `urban`, `green`, `water`, `residential`, `lit`, `sacred`, `crimson`): em cor, em cinza e com o tom da noite. Antes de entregar: `lint_sprite` na camada `corpo` sem peça solta nem pixel sozinho, e nenhum quadro encostando na borda.
