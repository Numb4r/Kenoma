# Soot (Fogo)

- **Bicho:** gambá-de-orelha-branca (*Didelphis albiventris*, o saruê), sem troca. É o gambá brasileiro de bueiro e forro, não o cangambá listrado: cara branca suja, orelha e rabo pelados, focinho fino, mão que parece de gente e os filhotes no lombo.
- **Pedaço da cidade:** grelha e tampa de bueiro de ferro fundido; bituca acesa.
- **Traço-assinatura:** a brasa no peito, que aparece pelas falhas do pelo (miolo claro, rachaduras em laranja).
- **Paleta:** fuligem (cinza quente, 4 a 5 degraus), cara branca suja, pele nua rosa-acinzentada, ferro fundido com ferrugem, cinza e filtro da bituca. Só a brasa tem cor.

## Etapas

- **Fagulha (Ember Mote):** um tufo do peito arrancado, com a brasa dentro e um resto de bituca espetado.
- **Eco (Sootling):** o gambá em proporção natural, de perfil; o errado é pouco: a ponta do rabo pelado queima como bituca e a brasa aparece no peito.
- **Espírito (Cinderkin):** o flanco virou grelha de bueiro com a brasa atrás das barras; dois rabos (um arrasta), dois olhos do mesmo lado, três orelhas, a boca aberta, e os filhotes de fuligem agarrados no lombo.
- **Entidade Maior:** a tampa do bueiro é o corpo. Três pescoços de gambá em cata-vento, sem olhos, só a boca aberta com os dentes; os seis olhos ficaram na tampa, em volta da brasa. Três rabos entre os pescoços.
- **Arquétipo:** o bueiro sem fundo. A armação é uma grelha impossível, com três caveiras sem órbita em cima das barras, três rabos (um pende do vão), o couro vazio pendurado de lado com a manga e a mão, e dedos que seguram as barras por dentro. No lugar do peito, a brasa é um sol negro: anel de fogo em volta de um furo; o Véu aparece na borda dos vãos.

## Regras quebradas

- **Entidade Maior:** o fogo dela pende. A chama escorre para baixo, da brasa pela tampa, das pontas dos rabos e das bocas, como baba.
- **Arquétipo:** geometria impossível, a grelha em tridente impossível (em cima são três barras redondas; embaixo os dois vãos viraram dentes e a barra do meio virou vão; um rabo pende desse vão). Regra física: o fogo dele tira luz em vez de dar, o ferro fica mais escuro quanto mais perto da brasa.

## Arquivos

`tools/art/creatures/conceitos/soot/build.lua` (usa `soot/_forma.lua`, as formas e o sombreado que rill e frond também usam). `soot/_folha.lua` monta uma folha de conferência rápida (`<familia>/_folha.png`), que não é a folha oficial.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Arquétipo | Saruê de perfil, sem olho, boca aberta além da queixada; a boca é o vão, com queixada dentro de queixada. Flanco de tampa de bueiro com brasa atrás, filhotes-caveira encolhendo até o rabo em espiral. | física: o fogo tira luz (pelo e ferro escurecem perto da brasa); geometria: boca dentro de boca |

## Arte final (rodadas 1 e 2 aprovadas)

Kit da família: `tools/art/creatures/_soot.lua` (a legenda, os emissivos e as formas dos conceitos com pose; a saída é a do `_hum.lua`, no formato do Humoth). Rodar cada `build.lua` com `KENOMA_ART='<repo>/tools/art/'`. A luz das cinco peças é a do tipo (`#A82E1C`, `#F0502E`, `#FF9C7A`); o laranja da Essência e os amarelos do conceito saíram. Bicho de chão: no Sootling, no Cinderkin e no Arquétipo o `body_dy` é o tronco que sobe com os pés plantados; na deriva andam, na fuga saltam.

| Etapa | Pasta | O que mudou em relação ao conceito |
|---|---|---|
| Fagulha | `tools/art/sparks/spark_fire*` (desenho em `spark_fire.lua`) | O Ember Mote substitui a chama antiga: o tufo do peito com a brasa dentro e o resto de bituca, 4 quadros a 5 fps pairando (desce 1 px e volta); a brasa cresce até o pico, as rachaduras abrem no pelo e uma faísca sobe. |
| Eco | `tools/art/creatures/sootling/` | O saruê de perfil substitui a bola de fuligem. **Três costuras do Véu** de 1 px (anca, lombo, barriga), `#9B7BFF` no `glow` e `#473F4C` apagadas no pelo; no retrato ganham pontos atravessados. A bituca do rabo vai em `leds`. No alerta o rabo sobe e a boca aberta mostra a brasa na garganta. |
| Espírito | `tools/art/creatures/cinderkin/` | **Elemento errado: o bueiro tomou o corpo por dentro.** O flanco é a grelha e por dentro ele é oco: só a brasa atrás das barras, e de lá uma mão de saruê passa três dedos pelos vãos e segura a barra (quatro no alerta). Duas costuras de 2 px (anca e pescoço). Os filhotes levantam a cabeça um de cada vez; a fumaça da bituca ondula; o rabo de baixo arrasta no passo. |
| Entidade Maior | `tools/art/creatures/soot_entidade/` (provisório) | Duas costuras de 3 px (uma atravessa a tampa, outra dá a volta num pescoço). O cata-vento balança, as bocas abrem fora de fase, os seis olhos da tampa piscam um de cada vez, e o fogo que pende cresce, pinga e recomeça. No alerta pescoços e rabos esticam; encolhem na antecipação. `idle` e `drift` com 6 quadros a 6 fps. |
| Arquétipo | `tools/art/creatures/soot_arquetipo/` (provisório) | Sem costura. O vão é a boca: escura no corpo (`#241A2A`), com o violeta só no `glow` (a borda junto das queixadas e o xadrez que rareia para o fundo). As queixadas de dentro nascem da de fora, encolhem e afundam sem parar; a queixada respira e escancara no alerta; as caveiras do lombo balançam fora de fase; as rachaduras da brasa crescem e encolhem. `idle` e `drift` com 6 quadros a 5 fps. **Retrato:** busto de 128 em escala 3 (a cabeça sem olho, a boca e a brasa do peito), cortado num rasgo à esquerda e embaixo. |

Na deriva a Entidade tomba 8 graus para a frente e o fogo dela fica para trás; o Arquétipo anda. A Entidade sobe no máximo 1 px na fuga. O Sootling e o Cinderkin antigos e a Fagulha de fogo foram substituídos por estes; o Kilnshade (espécie de ritual) não mudou.

