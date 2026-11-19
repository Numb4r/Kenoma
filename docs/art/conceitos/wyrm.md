# Wyrm (Dracônico)

- **Bicho:** teú (sem troca). Escama preta em xadrez de dois tons, faixas cor de cinza, barriga clara, dedos sujos de terra vermelha.
- **Pedaço da cidade:** asfalto rachado (placas levantadas, brita, tinta de faixa gasta) e a cratera (terra vermelha, o buraco).
- **Traço-assinatura:** escama em brasa, escama escura com a junta acesa em volta.
- **Luz do tipo:** Dracônico (`#DE4F84` na junta, `#F797B6` no nó, `#8E2852` no fundo). Violeta do Véu só nas costuras e no vão do Arquétipo.

## Etapas

- **Fagulha (Scale Mote):** uma escama solta, escura, com a junta ainda acesa em volta e uma trinca no meio.
- **Eco (Wyrmlet):** um teú jovem em proporção natural, andando; só as costelas têm a escama em brasa, e a língua bifurcada é uma chama pequena. Não parece dragão.
- **Espírito (Wyrmkin):** o teú tomado pelo asfalto: placas de rua levantadas na espinha, ainda com a faixa pintada, uma asa só (de placa), cinco pernas, duas caudas, duas línguas.
- **Entidade Maior:** a cratera que anda. Um pedaço de rua com o buraco no meio, em pernas de teú; da borda sobe o tronco, que se abre em três pescoços em cata-vento, cada um com uma cabeça sem olhos e de boca aberta. O único olho está no fundo do buraco.
- **Arquétipo:** o eclipse. No lugar do corpo, um disco vazio com a coroa de brasa; a armação é um anel de doze escamas de asfalto; de dentro do vão, cinco mãos de teú agarram o anel; por fora, três caudas em cata-vento. Nenhuma cabeça.

## Regras quebradas

- **Entidade Maior (regra física):** a profundidade. O buraco é mais fundo do que a placa de rua que o carrega: os anéis descem até a brasa e o olho, e a placa tem três pixels de espessura.
- **Arquétipo (geometria impossível):** as doze escamas do anel estão cada uma por cima da seguinte, em toda a volta; não existe a escama de baixo.
- **Arquétipo (regra física):** a luz e o calor. A coroa brilha em volta de um disco que não tapa nada (eclipse sem sol nem lua), e as brasas soltas caem de fora para dentro do vão.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Teú que nada na rua: mergulha e volta três vezes em arcos, a brasa aparece por baixo do asfalto, pernas penduradas, olhos no flanco, cabeça sem olhos com duas línguas. Uma costura larga no arco maior. | o asfalto se comporta como água: ele atravessa sem abrir buraco |

## Arte final (rodadas 1 e 2 aprovadas)

Kit da família: `tools/art/creatures/_wyrm.lua` (a legenda, os emissivos e as formas dos conceitos com pose; a saída é a do `_hum.lua`, no formato do Humoth). Rodar cada `build.lua` com `KENOMA_ART='<repo>/tools/art/'`. A luz das cinco peças é a do tipo (`#8E2852`, `#DE4F84`, `#F797B6`); o laranja e o amarelo de brasa do conceito saíram. A escama em brasa é escama escura com a junta acesa: a junta vai no `glow` e, apagada, fica vinho escuro (`#4E2438`, `#643046`, `#3A1A2C`). Bicho de chão: no Wyrmlet e no Wyrmkin o `body_dy` é o tronco que sobe com os pés plantados; na deriva andam, na fuga saltam.

| Etapa | Pasta | O que mudou em relação ao conceito |
|---|---|---|
| Fagulha | `tools/art/sparks/spark_draconic*` (desenho em `spark_draconic.lua`) | O Scale Mote substitui a escama genérica: escama solta de teú com a junta acesa em volta e a trinca no meio, 4 quadros a 5 fps pairando (desce 1 px e volta); no pico a junta acende inteira, a trinca abre e solta uma fagulha. |
| Eco | `tools/art/creatures/wyrmlet/` | O teú jovem de perfil substitui o ovo de carvão. **Quatro costuras do Véu** de 1 px (rabo, anca, lombo, pescoço), `#9B7BFF` no `glow` e `#3F3B4C` apagadas na escama. O olho e a língua vão em `leds`. A brasa das costelas respira, o rabo balança, a língua entra e sai; no alerta ele ergue a cabeça e o rabo e abre a boca. |
| Espírito | `tools/art/creatures/wyrmkin/` | **Elemento errado: a rua tomou o corpo por dentro.** No flanco abriu um buraco de rua, com a borda de asfalto, a terra vermelha e a brasa no fundo, e do fundo dele um olho olha para fora (em `leds`; olha para trás num quadro do laço). Duas costuras de 2 px (a base do rabo e o pescoço). As placas da espinha e a asa de placa se eriçam no alerta; a segunda cauda arrasta no chão, fora de fase. |
| Entidade Maior | `tools/art/creatures/wyrm_entidade/` (provisório) | Uma costura de 3 px no arco maior. As faixas da pele escorrem pelos arcos (o corpo passa, os arcos ficam), as ondas da rua se abrem em volta de cada entrada e a faixa pintada ondula junto; a brasa de baixo do asfalto corre, as pernas penduradas balançam fora de fase. Os quatro olhos do flanco vão em `leds`. `idle` e `drift` com 6 quadros a 6 fps. |
| Arquétipo | `tools/art/creatures/wyrm_arquetipo/` (provisório) | Sem costura: o vão. No corpo ele é escuro (`#120D1C`); o violeta vai só no `glow`, e a coroa, na luz do tipo, fica em volta do disco do meio, que não acende. O anel gira uma escama por laço, as mãos abrem e fecham fora de fase, as caudas respiram e as brasas caem de fora para dentro. `idle` e `drift` com 6 quadros a 5 fps. **Retrato:** busto de 128 em escala 3, cortado num rasgo em volta. Sem nada em `leds` (não tem olho). |

O Wyrmlet e o Wyrmkin antigos e a Fagulha dracônica foram substituídos por estes.

