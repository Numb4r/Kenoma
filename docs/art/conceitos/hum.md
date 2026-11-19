# Hum (Elétrico)

- **Bicho:** mariposa-esfinge (mantida: é o Humoth).
- **Pedaço da cidade:** letreiro de LED e fios; nas etapas altas, a rede elétrica do bairro (transformador de poste, cruzeta, isolador).
- **Traço-assinatura:** o olho de LED, ciano `#5fd3c6` com o miolo claro, o mesmo bloco em todas as etapas; os veios elétricos amarelos acompanham.
- **Materiais:** pó de asa índigo, pelo roxo-escuro, cobre desencapado, borracha de cabo, aço galvanizado, porcelana, madeira de poste. No Arquétipo a asa vira cinza.

| Etapa | Nome | Mapa | O que é |
|---|---|---|---|
| Fagulha | Arc Mote | 12 | Um ocelo arrancado da asa, ainda aceso, com um veio pendurado soltando faísca. |
| Eco | Humoth | 28 | A mariposa-esfinge com dois olhos de letreiro nas asas e veios elétricos. Não muda. |
| Espírito | Coilkin | 36 | A mariposa tomada pelos fios: abdômen em bobina de cobre, asas de trás só na armação de fio, três antenas (a do meio é um fio desencapado), três olhos nas asas e um quarto no peito aberto, no meio da bobina. |
| Entidade Maior | sem nome | 48 | O poste é o corpo: o transformador abriu numa boca de pé, com dentes de aleta e olhos lá dentro; duas asas rasgadas pendem como mortalha e a terceira sobe atrás da cruzeta, com três, dois e dois olhos de tamanhos diferentes; mais olhos soltos no poste, e cinco antenas no lugar das pernas. Nenhuma cabeça. **Regra quebrada: gravidade.** Os fios da cruzeta caem para cima. |
| Arquétipo | sem nome | 64 | A forma original: no lugar do corpo, uma boca redonda de armação de letreiro com doze dentes, e dentro dela um túnel de armações com o olho de LED no fim e outros pelo caminho, em espiral. Três asas de cinza de tamanhos diferentes (três, um e dois olhos), sete antenas sem cabeça em volta da gola de pelo. A armação está partida embaixo, o vão escorre para fora e o raio sai dali. O vão é mais escuro que o contorno (`#0d0914`). **Regra quebrada: o dentro é maior que o fora.** O túnel afunda mais do que o corpo tem de fundo; o raio não cai do céu, sai de dentro dela. |

## Arte final (rodada 1 aprovada)

Kit da família: `tools/art/creatures/_hum.lua` (as formas dos conceitos com pose, no formato do Humoth). Rodar cada `build.lua` com `KENOMA_ART='<worktree>/tools/art/'`. A luz amarela das cinco peças é a do tipo (`#FFD23A`, `#FFEE9A`); o Humoth passou para ela depois da rodada 2 (o build aceita os amarelos antigos do `humoth_portrait_src.aseprite` e grava os novos).

| Etapa | Pasta | O que mudou em relação ao conceito |
|---|---|---|
| Fagulha | `tools/art/sparks/spark_electric*` | O Arc Mote substitui a faísca antiga: 4 quadros a 5 fps pairando (desce 1 px e volta), o veio balança e solta faísca, o olho inteiro acende no pico. A ponta do veio é faísca solta, para o corpo caber em 10 × 10. |
| Eco | `tools/art/creatures/humoth/` | Só ganhou **uma costura do Véu**: 1 px em diagonal no abdômen (6 px no mapa, tracejada pelos anéis no retrato), `#9B7BFF` no `glow` e `#3A2E5A` apagada no corpo. Fica no tronco e acompanha todas as animações. |
| Espírito | `tools/art/creatures/coilkin/` | **Elemento errado: o peito abriu.** A bobina de cobre sobe por dentro do tórax e no meio dela abre um quarto olho de LED: o letreiro tomou o corpo por dentro e olha de lá. O cabo de borracha foi para o pescoço. Uma costura de 2 px de borda a borda da asa direita. |
| Entidade Maior | `tools/art/creatures/hum_entidade/` (provisório) | Duas costuras de 3 px (cinta no poste abaixo do transformador, e na asa direita). Os fios da cruzeta sobem em onda e a faísca das pontas sobe e some; a boca respira e escancara no alerta; as asas de mortalha balançam; os joelhos das cinco antenas sobem fora de fase. `idle` e `drift` com 6 quadros a 6 fps. |
| Arquétipo | `tools/art/creatures/hum_arquetipo/` (provisório) | Sem costura. O vão fica quase preto no corpo, com faixas de fundo (`#130D1E`) que dão a profundidade do túnel; o violeta só no `glow` (aro tracejado depois das pontas dos dentes e o miolo do que escorre). Os dentes giram um dente por laço, o letreiro da armação corre, os olhos descem a espiral e somem no olho do fundo, o raio muda de caminho a cada quadro. `idle` e `drift` com 6 quadros a 5 fps. **Retrato:** busto de 128, a boca em escala 2,5 com a quarta armação do túnel, asas e antenas cortadas num rasgo em volta, o raio saindo pelo pé do quadro. |

Na deriva a Entidade inclina só a cruzeta e o transformador e o Arquétipo não inclina (as asas ficam para trás, o túnel aponta para a frente). Os dois sobem no máximo 1 px na fuga.

Fonte: `tools/art/creatures/conceitos/hum/build.lua`. Cada etapa é uma função da escala. Fagulha e Espírito: o retrato é o desenho do mapa ampliado, com o olho em matriz de LED. Entidade Maior e Arquétipo: o retrato mantém a pose e ganha detalhe só dele (pupila em cada olho, cada uma para um lado; barbas nas antenas; escamas e veios ramificados nas asas; veio da madeira e rebites; na Entidade, olhos inteiros dentro da boca; no Arquétipo, os dentes da segunda armação, a terceira armação do túnel e olhos inteiros no vão). O Coilkin antigo e a Fagulha elétrica de `tools/art/sparks/` foram substituídos por estes.
