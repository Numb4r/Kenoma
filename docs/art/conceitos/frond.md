# Frond (Planta)

- **Bicho:** Charnia, a fronde fóssil ediacarana, sem troca. O que a separa de uma folha: os lobos não se espelham (vêm um de um lado, depois um do outro, em simetria de deslize), cada lobo é repartido em lobinhos, e a base é um disco de fixação.
- **Pedaço da cidade:** rachadura de calçada, laje de concreto levantada, raiz.
- **Traço-assinatura:** a fronde fractal, com a nervura do talo acesa em verde (o fio de luz que a Fagulha também carrega).
- **Paleta:** verde de calçada sem brilho (5 degraus), folha seca, raiz, concreto; no Arquétipo a fronde é pedra de fóssil. Só a nervura tem cor.

## Etapas

- **Fagulha (Seed Mote):** um lobo solto da fronde, com o fio da nervura aceso, que cai girando como semente alada.
- **Eco (Frondling):** uma fronde de Charnia em pé, com a ponta ainda enrolada em báculo virada para a direita, andando sobre cinco raízes; o errado é pouco: os lobos não se espelham, um já secou, e a raiz segura uma lasca de calçada.
- **Espírito (Thicketkin):** o disco de fixação virou um pedaço de laje levantado por sete raízes, com a rachadura acesa; dela saem frondes em número errado (uma fronde grande, um báculo que não abriu e, no lugar da terceira, uma raiz que cresce para cima e abre como mão), e alguns lobos já são lascas de concreto ou folha seca.
- **Entidade Maior:** a calçada inteira. Um disco de laje partido em três por uma rachadura em espiral (o desenho do Tribrachidium), três frondes em cata-vento, as raízes embaixo como pernas, nenhum rosto.
- **Arquétipo:** a rachadura. No lugar do corpo há um vão em Y com o Véu na borda, num resto de calçada partido em três lajes; do vão saem três frondes de pedra, fósseis, só com a nervura acesa, e a raiz desce em leque.

## Regras quebradas

- **Entidade Maior:** a rachadura não para na pedra. Os três braços da espiral continuam pelo ar, acesos, para além da borda da laje.
- **Arquétipo:** geometria impossível, cada fronde passa por cima da laje de um lado e por baixo da mesma laje do outro. Regra física: a parte é maior que o todo; da ponta de cada fronde sai outra maior, e os lobos crescem para a ponta em vez de afinar.

## Arquivos

`tools/art/creatures/conceitos/frond/build.lua` (usa `soot/_forma.lua`).

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Arquétipo | Fronde de pedra em pé: os lobos se espelham, crescem para a ponta, e o báculo abriu em dois; o talo é o vão, com a fronde repetida dentro. Caco de calçada sobre raízes finas. | física: mais pesada em cima do que as raízes aguentam, e não tomba; geometria: a fronde inteira dentro do próprio talo |

## Arte final (rodadas 1 e 2 aprovadas)

Kit da família: `tools/art/creatures/_frond.lua` (as formas dos conceitos com pose, na saída do `_hum.lua`; reusa a costura, o rasgo do busto e as formas do `_soot.lua`). Rodar cada `build.lua` com `KENOMA_ART='<repo>/tools/art/'`. A luz é a do tipo Planta (`#2B7A40`, `#4DBD62`, `#A2E8A0`), no lugar dos verdes do conceito. Bicho de chão: o tronco sobe e desce (`body_dy`, aplicado no desenho) e as raízes ficam; só saem do chão no salto da fuga.

| Etapa | Pasta | O que mudou em relação ao conceito |
|---|---|---|
| Fagulha | `tools/art/sparks/spark_plant*` | O Seed Mote substitui a folha antiga: o lobo solto com o fio da nervura e o toco do talo, 4 quadros a 5 fps pairando (desce 1 px e volta), a luz sobe pela nervura até o pico, a ponta do lobo vira e um esporo solta. Corpo de 9 × 8. |
| Eco | `tools/art/creatures/frondling/` | **Quatro costuras do Véu** de 1 px, cada uma atravessada num lobo (com pontos no retrato), `#9B7BFF` no `glow` e `#4B5049` apagada no corpo. O broto na ponta do báculo foi para `leds`. A fronde verga para trás e volta, os lobos abanam fora de fase, a luz corre pelo talo; na deriva as cinco raízes andam e a fronde fica para trás. |
| Espírito | `tools/art/creatures/thicketkin/` | **Elemento errado: uma raiz no lugar de fronde.** Onde ficava a fronde torta de trás, uma raiz grossa sai da laje para cima e abre em cinco radículas como uma mão, segurando uma lasca de calçada; abre e fecha no laço, escancara no alerta, fecha em punho encolhida. Ficam a fronde grande e o báculo que não abriu. Duas costuras de 2 px: atravessando a laje e nos lobos de baixo da fronde grande. |
| Entidade Maior | `tools/art/creatures/frond_entidade/` (provisório) | Duas costuras de 3 px: de borda a borda da laje e cortando os lobos de uma fronde. A espiral aperta e solta, as frondes balançam em cata-vento com a raiz presa na laje, as sete raízes andam fora de fase na deriva. A rachadura no ar ficou mais longa e a luz corre por ela para fora. `idle` e `drift` com 6 quadros a 6 fps. |
| Arquétipo | `tools/art/creatures/frond_arquetipo/` (provisório) | Sem costura. O vão é fechado e escuro no corpo (`#2A2630`); o violeta fica só no `glow` (a borda e o xadrez que rareia para o eixo). As frondes de dentro nascem do tamanho da de fora, encolhem e afundam em laço. O corpo inteiro pende de um lado para o outro sobre as cinco raízes, que tremem nos joelhos, e não tomba. `idle` e `drift` com 6 quadros a 5 fps. **Retrato:** busto de 128 em escala 3, com os dois báculos, os lobos de cima e o vão, cortado num rasgo embaixo. |

Na deriva as frondes vergam para trás, porque o báculo já chega perto da borda do quadro; as quatro etapas sobem no máximo 1 px na fuga. O Frondling e o Thicketkin antigos e a Fagulha de folha foram substituídos por estes; o Rootseer (espécie de ritual) não mudou.

