# Rill (Água)

- **Bicho:** sapo-cururu (*Rhinella*), sem troca: corpo atarracado, pele de verruga cor de barro, glândula atrás do olho, íris ocre com a pupila deitada, barriga creme.
- **Pedaço da cidade:** poça, sarjeta e boca de lobo; a guia de concreto com a tinta amarela gasta.
- **Traço-assinatura:** o dorso é um espelho d'água que reflete o céu (azul em faixas, com nuvem). O espelho é a única cor da família; o resto é barro e concreto.
- **Paleta:** pele em 5 degraus de barro, barriga creme, concreto, amarelo de guia gasto, e o azul do céu só no emissivo (as cores da Fagulha de Água).

## Etapas

- **Fagulha (Drip Mote):** uma gota que cai de uma lasca de pele, ainda refletindo o céu; no retrato, a cidade aparece de ponta-cabeça dentro da gota.
- **Eco (Rillet):** o cururu sentado, em proporção natural; o errado é pouco: o dorso é um espelho d'água com céu e nuvem, e do queixo pinga.
- **Espírito (Brookkin):** a boca virou boca de lobo (verga e soleira de concreto, a quina com a tinta gasta) e despeja água; três olhos em fila, três braços, e o espelho do dorso partiu em três poças.
- **Entidade Maior:** a poça em pé. O sapo virou o aro de pele em volta de um espelho vertical, com a guia de concreto embaixo; a cara só existe no reflexo: três olhos de cururu boiando no céu, em cata-vento, cada um girado. Três pernas (duas andam, a terceira dobrou em cima) e três mãos na borda.
- **Arquétipo:** o céu de baixo. Uma sarjeta em anel, com a água correndo sem fim, atravessada por uma coluna de espinha; em cima, no lugar da cabeça, só a boca: um aro de lábio em volta do vão, com outro céu (estrelas) dentro e o Véu na borda. Três pernas de sapo pendem, e do anel pendem os cordões de ovos e o couro do sapo virado do avesso.

## Regras quebradas

- **Entidade Maior:** a água dela não cai. A poça fica em pé sem escorrer e a chuva sobe (as gotas têm a cauda para baixo).
- **Arquétipo:** geometria impossível, o anel e a coluna: o arco de trás do anel passa pela frente da coluna e o arco da frente passa por trás dela. Regra física: a água dele cai para cima, da ponta da coluna até o vão.

## Arquivos

`tools/art/creatures/conceitos/rill/build.lua` (usa `soot/_forma.lua`).

## Arte final (família inteira)

Kit em `tools/art/creatures/_rill.lua` (o do Wellmirror, que ganhou o espelho, o olho, a pele das formas grandes e os caracteres do vão; o Wellmirror não foi regerado e segue igual na régua); espécies em `rillet/`, `brookkin/`, `rill_entidade/` e `rill_arquetipo/` (nomes e pastas das duas últimas são provisórios), Fagulha em `tools/art/sparks/spark_water.lua`. Folha: `docs/art/final/rill.png`. O Arquétipo é o de `rodada3/arquetipos.png` (o sapo de frente com a poça em pé na boca).

- **Entidade, com o ajuste do dono:** não é mais o cururu com boca de lobo. É o bloco do meio-fio, de frente: a face de cima com a poça, a quina com a tinta amarela gasta, a verga com uma trinca, a grade, a soleira molhada. Os três olhos de cururu ficam sobre a grade (cada um no seu calombo de pele), a água escura escorre da boca pela frente do bloco e empoça embaixo. Do sapo sobram os olhos, as duas pernas de trás dobradas (uma de cada lado do bloco) e as duas mãos que saem da boca e agarram a soleira. A poça de cima reflete os três olhos (a regra da rodada 3) e a chuva sobe.
- **Entidade, luz:** a água que escorre e a poça de baixo são escuras de verdade (asfalto molhado, quase preto, com um brilho de 1 px que não é emissivo). A luz está nos três olhos sobre a grade (acesos, em `leds`, para o sapo se ler de noite), na poça de cima e nas gotas que sobem.
- **Entidade, segundo ajuste do dono (substitui os dois itens acima; o bloco lia como caixote ou máquina):** é o sapo agachado, de frente, feito de concreto de meio-fio. Cabeça larga e chata, torta (a boca cai para um lado), com os dois calombos dos olhos saltados em cima, de pele, o esquerdo maior e mais baixo; dorso e barriga redondos, de concreto com poros e a junta do meio-fio; as pernas de trás dobradas dos lados e os braços da frente plantados, de pele. A boca de lobo é a boca: uma fenda de lado a lado, com a verga de tinta amarela gasta em cima, a grade como dentes (barras inteiras alternadas com tocos quebrados) e a soleira molhada embaixo. A água escura escorre da boca pela barriga em quatro fios desiguais, e só os dois do meio chegam à poça. O terceiro olho está fora do lugar, no joelho direito, com a pupila em pé. Costura larga no flanco esquerdo.
- **Entidade, regra quebrada e luz depois do ajuste:** a chuva sobe, e a poça de baixo reflete três olhos em fila, que no corpo não estão assim. Olhos em `leds` (os três e os reflexos); em `glow`, a água atrás da grade, o brilho dos fios e da poça, a costura e as gotas. De dia a água é escura (o par apagado é azul quase preto).
- **Luz:** só a do tipo Água da paleta (`#2A62B8`, `#4A9CFF`, `#A4D0FF`). `leds` são as nuvens do espelho (e os olhos da Entidade); o resto é `glow`. No Arquétipo não há `leds` (não tem olho).
- **Costuras do Véu:** Rillet três, curtas e de 1 px (coxa, flanco, alto da cabeça), longe do espelho; Brookkin duas mais largas (coxa e flanco); Entidade uma larga, no flanco esquerdo; Arquétipo nenhuma (o vão); a Fagulha ficou sem, como as outras refeitas.
- **Animação:** o Rillet respira pelo papo, o céu corre no espelho e a gota do queixo cai; no Brookkin a água corre, os três olhos piscam em onda e o céu anda nas poças; na Entidade os olhos piscam um de cada vez, o do meio gira a pupila, a água escorre e os joelhos mexem; no Arquétipo o corpo respira, as duas luas atravessam a poça cada uma no seu passo, a cidade corre de lado e as gotas sobem (mais as regras do vão do `K.run`).
- **Retratos:** 96 nas três etapas de baixo; o do Arquétipo é o sapo inteiro em 128 (escala 1,85, margem de 5 px), com o `_retrato.lua`: a poça ocupa uns 72×27 px e vai do violeta ao preto, com as luas, a cidade e estrelas.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | A sarjeta: corpo de guia e asfalto, boca de lobo como boca, dorso de verruga com dois olhos, seis membros. Uma costura larga no dorso. | a enxurrada sobe da boca de lobo e junta numa poça deitada no ar, com o terceiro olho no reflexo |
| Arquétipo | Sapo de frente, pequeno e de olhos fechados, sentado no próprio reflexo, que é maior e tem olhos abertos, um terceiro olho e braços a mais; o vão é a linha d'água. | física: ele se apoia num reflexo; geometria: o reflexo é maior e tem mais do que o refletido |

## Rodada 3 (substitui a rodada 2 nestas etapas; aprovada)

**Aprovada pelo dono** (`docs/art/conceitos/rodada3/rodada3.png` e `arquetipos.png`): a Entidade Maior e o Arquétipo em 64. A família está aprovada por inteiro e segue para a arte final sem nova rodada de conceito.

**Ajuste que entra direto na arte final, Entidade Maior:** o conceito ainda lê como o Espírito maior. O corpo vira o próprio meio-fio com a boca de lobo (um bloco de concreto), os olhos ficam sobre a grade, com água escura escorrendo. O sapo se lê só pelos olhos e pelas patas.

A luz de todas as peças desta rodada é só a da paleta do tipo.

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Cururu de frente, agachado; a boca de um lado ao outro é a boca de lobo (verga com tinta amarela, soleira, grade). Os calombos dos olhos estão cegos; os três olhos estão atrás da grade. Costura larga na verga. | a poça do dorso reflete os três olhos, que estão do outro lado do corpo |
| Arquétipo | Sapo de frente, cinza, sem olho (dois buracos), pele em fibra com covas e veias acesas por fora. A boca aberta é a poça, e nela está o vão com duas luas e uma cidade de ponta-cabeça. Braços a mais de um lado só. | física: a poça está em pé e não escorre, e a água cai para cima; geometria: a poça é mais larga que a cabeça que a segura |

**Decisão do dono: a Entidade Maior e o Arquétipo de frente estão aceitos** como exceção à regra "bicho que anda fica de perfil" (`docs/art/estilo-criaturas.md`, "Ângulo"). O Rillet e o Brookkin seguem a regra.
