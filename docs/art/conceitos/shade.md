# Shade (Sombra)

- **Bicho:** morcego, sem troca. A espécie é o morcego-da-cara-branca (*Artibeus lituratus*), o frugívoro que dorme debaixo de marquise e de amendoeira nas cidades brasileiras: pelo pardo, folha nasal e duas listras claras na cara.
- **Pedaço da cidade:** marquise de concreto, com a lâmpada tubular por baixo, o vergalhão na ponta quebrada e a sujeira que escorre.
- **Traço-assinatura:** a sombra não acompanha o corpo. Ela tem outra pose, é maior que quem a faz e é ela que tem os olhos; o corpo nunca tem olho aberto.
- **Luz do tipo:** crepúsculo (rosa-vinho `#C4667C`, pêssego `#F4B6A2`, branco quente `#FFF1E6`), na borda da sombra e nos olhos dela. A lâmpada da marquise é branco quente. Nada de violeta fora do vão do Arquétipo.

## Etapas

- **Fagulha (Dusk Mote):** uma lasca de marquise e, presa nela, uma sombra que não é a dela: um pedaço de asa com um olho.
- **Eco (Umbrel):** o morcego dorme pendurado numa lasca de laje, fechado como guarda-chuva; a sombra dele está de pé ao lado, de asa aberta, olhando.
- **Espírito (Shadekin):** o morcego de pé, com três orelhas e sem olhos; um braço virou laje com a lâmpada acesa, o outro desce até o chão. A sombra é maior que ele, tem três olhos e os braços para cima.
- **Entidade Maior:** a marquise inteira. Embaixo, pendurado, o corpo sem rosto com três pares de braços em grade; em cima da laje, a sombra em cata-vento de três asas, com olhos espalhados e o rosto que falta no corpo.
- **Arquétipo:** o vão. Três lajes em roda com as lâmpadas viradas para dentro; no meio não há corpo, só o vão (o Véu aparece nele), e dele saem três sombras em espiral que acabam em mãos de osso. Do morcego sobram as mãos, três orelhas e os que dormem pendurados nas lajes.

## Regras quebradas

- **Entidade Maior (física):** a sombra fica do lado da luz. As lâmpadas estão embaixo da laje e a sombra está em cima dela, atravessando o concreto, maior que o corpo que a faria.
- **Arquétipo (geometria):** as três lajes se apoiam em roda, cada uma em cima da seguinte; nenhuma fica embaixo, e a roda não fecha no espaço.
- **Arquétipo (física):** sombra sem corpo e com peso. Não há nada que a projete, três saem do mesmo vão em três direções, passam por cima das lajes e seguram coisas com mãos de osso.

## Régua (mapa / retrato)

| Etapa | Opacos | Cores | Detalhe | Contorno | Emissivo |
|---|---|---|---|---|---|
| Fagulha | 70 / 2361 | 11 / 14 | 1,00 / 0,76 | 0,41 / 0,13 | 0,17 / 0,10 |
| Eco | 441 / 3206 | 21 / 23 | 0,98 / 0,93 | 0,27 / 0,13 | 0,08 / 0,05 |
| Espírito | 548 / 2902 | 25 / 26 | 0,96 / 0,93 | 0,27 / 0,16 | 0,11 / 0,09 |
| Entidade Maior | 1067 / 3737 | 26 / 26 | 0,97 / 0,95 | 0,25 / 0,18 | 0,13 / 0,12 |
| Arquétipo | 1610 / 5943 | 18 / 18 | 0,96 / 0,95 | 0,22 / 0,14 | 0,17 / 0,15 |

No mapa, o corpo do Eco e a cabeça do Espírito são desenhados pixel a pixel; o resto sai das formas do `build.lua`. No Arquétipo, osso e os que dormem pendurados ficam sem contorno (contorno seletivo).

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Eco | Morcego pendurado na lasca de laje; a sombra sai dos pés dele, inclinada atrás do corpo, menor, com uma asa aberta e os olhos, presa por quatro costuras finas (só emissivo). | nenhuma |
| Arquétipo | Morcego pendurado na própria sombra, que está em cima, de pé e de asa aberta, com os olhos; o casulo de laje e vergalhão não fecha, e na fresta (o vão) o casulo se repete menor. Cabeça de osso, três orelhas, sem rosto. | física: o peso pende de uma sombra, que fica acima da lâmpada; geometria: casulo dentro de casulo |

## Arte final (rodadas 1 e 2 aprovadas)

Kit da família: `tools/art/creatures/_shade.lua` (a legenda, os emissivos e as ajudas de forma dos conceitos com pose; a saída é a do `_hum.lua`, no formato do Humoth). Rodar cada `build.lua` com `KENOMA_ART='<repo>/tools/art/'`. A luz das cinco peças é a do tipo (`#68426E`, `#A677AB`, `#D2ABD6`); o rosa do crepúsculo do conceito saiu, e a lâmpada da marquise acende na mesma luz. A sombra é parte do sprite e não acompanha o corpo: o `body_dy` move só o corpo, a sombra fica e tem ritmo próprio; a matéria dela (`#231E33`, `#2F2942`, `#3C3552`) não entra no mapa de variantes. O jogo não desenha sombra no chão para as espécies do Shade (`castsGroundShadow`).

| Etapa | Pasta | O que mudou em relação ao conceito |
|---|---|---|
| Fagulha | `tools/art/sparks/spark_shadow*` (desenho em `spark_shadow.lua`) | O Dusk Mote substitui o fiapo antigo: a lasca de marquise com o pedaço de asa e o olho, 4 quadros a 5 fps. A lasca desce 1 px e volta; a sombra não vai junto, o olho olha para o lado e arregala no pico, quando a borda acende. |
| Eco | `tools/art/creatures/umbrel/` | O morcego pendurado na lasca substitui o vulto antigo. **Quatro costuras do Véu** de 1 px prendem a sombra ao corpo, `#9B7BFF` no `glow` e `#352E4C` apagadas na sombra. Os dois olhos da sombra vão em `leds`; o corpo nunca abre o olho. A sombra abre e fecha a asa fora do ritmo do corpo; no alerta é ela que abre a asa, ergue a cabeça e arregala. |
| Espírito | `tools/art/creatures/shadekin/` | **Elemento errado: a marquise tomou o corpo por dentro.** Um braço é a laje, com a lâmpada acesa por baixo e vergalhão no lugar dos dedos, e o concreto entra rachado pelo ombro e pelo peito. Duas costuras de 2 px (o pulso da sombra sobre a cabeça dele; o ombro, entre o pelo e a laje). A sombra tamborila os dedos em outro ritmo; no alerta ela se ergue e abre as duas mãos. A lâmpada falha num quadro do laço. |
| Entidade Maior | `tools/art/creatures/shade_entidade/` (provisório) | Duas costuras de 3 px (a laje, onde a sombra a atravessa; o peito do corpo). O cata-vento gira um terço de volta por laço com o rosto parado no meio, e gira ao contrário na deriva; os braços pendurados balançam fora de fase; as lâmpadas falham uma de cada vez. No alerta as asas abrem e os braços sobem. `idle` e `drift` com 6 quadros a 6 fps. |
| Arquétipo | `tools/art/creatures/shade_arquetipo/` (provisório) | Sem costura: o vão. No corpo a fresta é escura (`#120D1C`); o violeta vai só no `glow`, e os casulos de dentro nascem do tamanho do de fora, encolhem e afundam. O casulo balança como pêndulo e a sombra não; as asas batem devagar. No alerta as asas sobem e o vão abre. `idle` e `drift` com 6 quadros a 5 fps. Retrato: busto de 128 (a sombra, os pés e a fresta). |

O `body_dy` da fuga é `1, 0, 0, -1, -1, -1` em toda a família. O Umbrel e o Shadekin antigos e a Fagulha de sombra foram substituídos por estes.

