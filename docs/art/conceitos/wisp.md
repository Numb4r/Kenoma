# Wisp (Espectral)

- **Bicho:** coruja-buraqueira (*Athene cunicularia*), sem troca. É a coruja de terreno baldio, canteiro e cemitério: cabeça chata sem tufos, sobrancelha e queixo claros, barriga barrada, pernas compridas e nuas, e mora num buraco no chão.
- **Pedaço da cidade:** vela (toco, cera escorrida, velário) e névoa de baixada.
- **Traço-assinatura:** olhos de vela. No lugar de cada olho há uma chama de vela, mais alta que larga, que sobe além da cabeça; onde a família aparece, a chama aparece.
- **Luz do tipo:** chama fria de fogo-fátuo (azul `#6FA8E0`, azul-claro `#BFE3FF`, branco `#F2FAFF`). Não é o ciano do sinal nem o laranja da Essência. A névoa e a cera são matéria (corpo), só a chama é emissiva.

## Etapas

- **Fagulha (Chill Mote):** um toco de vela com a chama fria, solto de qualquer olho.
- **Eco (Wisplet):** a coruja de pé nas pernas compridas, numa poça de névoa; duas chamas no lugar dos olhos e uma lágrima de cera embaixo de cada uma.
- **Espírito (Hollowkin):** o manto de penas ficou de pé e vazio. No capuz, só o bico e três chamas (duas de um lado); no peito aberto, a vela; um ombro derreteu em cera, sobra uma perna só e no lugar da outra escorre cera.
- **Entidade Maior:** a toca e o velário. Três asas em cata-vento com olhos de chama, o disco da cara de ponta-cabeça (bico para cima), três pernas apoiadas num monte de cera derretida com a toca no meio e três chamas lá dentro.
- **Arquétipo:** a procissão. Três mantos vazios em roda, um disco de penas de uma cara sem olhos nem bico em volta do vão (o Véu aparece nele), tocos de vela cravados na borda, três pernas penduradas que não tocam nada e tiras de mortalha acesas na ponta.

## Regras quebradas

- **Entidade Maior (física):** a chama queima para baixo e a cera pinga para cima. As chamas dos olhos descem das órbitas, e do monte sobem colunas de cera com a gota na ponta de cima.
- **Arquétipo (geometria):** o manto é um pano só, sem lado de dentro: cada manto entra pelo capuz do seguinte, em roda, e o último entra no primeiro.
- **Arquétipo (física):** não existe "para cima". Toda chama, em qualquer ponto do quadro, aponta para o vão.

## Régua (mapa / retrato)

| Etapa | Opacos | Cores | Detalhe | Contorno | Emissivo |
|---|---|---|---|---|---|
| Fagulha | 43 / 1905 | 8 / 12 | 1,00 / 0,78 | 0,40 / 0,12 | 0,35 / 0,21 |
| Eco | 266 / 2269 | 17 / 16 | 1,00 / 0,90 | 0,27 / 0,12 | 0,09 / 0,09 |
| Espírito | 615 / 3322 | 18 / 18 | 0,98 / 0,94 | 0,20 / 0,10 | 0,09 / 0,07 |
| Entidade Maior | 912 / 3368 | 18 / 18 | 0,95 / 0,95 | 0,26 / 0,16 | 0,13 / 0,11 |
| Arquétipo | 1741 / 6378 | 16 / 16 | 0,84 / 0,65 | 0,22 / 0,14 | 0,16 / 0,18 |

O Eco do mapa é desenhado pixel a pixel (a coruja é estreita: 266 opacos, contra 404 do Humoth). A chama não tem contorno; na Entidade a névoa também não, e no Arquétipo as garras ficam sem (contorno seletivo). A roda de chamas do Arquétipo é emissivo solto.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Velário de pé: tronco de cera, asas abertas como duas prateleiras de tocos de vela, cara de ponta-cabeça com órbitas ocas, tripé de pernas saindo da toca. Uma costura larga na raiz da asa. | a chama queima para baixo e a cera pinga para cima |

## Arte final (rodadas 1 e 2 aprovadas)

Kit da família: `tools/art/creatures/_wisp.lua` (a legenda, os emissivos e as ferramentas dos conceitos com pose; a saída é a do `_hum.lua`, no formato do Humoth). Rodar cada `build.lua` com `KENOMA_ART='<repo>/tools/art/'`. A luz das cinco peças é a do tipo (`#8A9DBA`, `#D3E2F4`, `#F2F7FF`); o azul do conceito saiu. Os olhos de vela vão em `leds` (piscam); as outras chamas, em `glow`. A chama não tem contorno. Bicho de chão: no Wisplet, no Hollowkin e na Entidade o `body_dy` é o tronco que sobe com os pés plantados; na deriva andam, na fuga saltam.

| Etapa | Pasta | O que mudou em relação ao conceito |
|---|---|---|
| Fagulha | `tools/art/sparks/spark_spectral*` (desenho em `spark_spectral.lua`) | O Chill Mote substitui a chama oca antiga: o toco de vela com a chama fria, 4 quadros a 5 fps pairando (desce 1 px e volta); a chama inclina e cresce até o pico, a cera clareia do lado da luz e um grão de frio sobe. |
| Eco | `tools/art/creatures/wisplet/` | A coruja-buraqueira substitui o vulto de névoa. **Três costuras do Véu** de 1 px (asa, barriga, alto da cabeça), `#9B7BFF` no `glow` e `#735C4C` apagadas na pena. Cada chama treme no seu passo; no alerta o pescoço estica e as chamas crescem; encolhida, afunda a cabeça (a reverência da buraqueira). |
| Espírito | `tools/art/creatures/hollowkin/` | **Elemento errado: a vela tomou o corpo por dentro.** O manto de penas está oco e no lugar do peito queima uma vela inteira, que ilumina a borda da fenda; sobram o bico no escuro do capuz e três olhos de vela, dois do mesmo lado. Duas costuras de 2 px (o lado de penas e o ombro de cera). |
| Entidade Maior | `tools/art/creatures/wisp_entidade/` (provisório) | O velário da rodada 2. Duas costuras largas: 3 px na raiz da asa esquerda e 2 px numa cinta no tronco de cera. As asas balançam em gangorra, cada chama cresce e encolhe no seu passo, os olhos soltam fogo que cai, os fios de cera sobem e recolhem. `idle` e `drift` com 6 quadros a 6 fps. |
| Arquétipo | `tools/art/creatures/wisp_arquetipo/` (provisório) | Sem costura. O vão é escuro no corpo (`#150F20`), com o violeta só no `glow` (o aro junto das chamas, que respira, e o xadrez do fundo). As nove chamas dos tocos são o olho de vela e vão em `leds`. Os três capuzes dão um terço de volta por laço, o disco e os tocos giram devagar, a roda de 21 chamas soltas gira ao contrário. `idle` e `drift` com 8 quadros a 5 fps. **Retrato:** busto de 128 em escala 3, o olho de vela no quadro, capuzes, pernas e tiras cortados num rasgo em volta. |

A Entidade sobe no máximo 1 px na fuga. O Arquétipo não sobe: o `body_dy` dele desce 1 px, porque os capuzes girando não deixam folga em cima. O Wisplet e o Hollowkin antigos e a Fagulha espectral foram substituídos por estes.

