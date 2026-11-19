# Espécies de ritual (Kilnshade, Rootseer, Wellmirror)

As três são da etapa Espírito (quadro de 36, retrato de 96) e usam o bicho, o pedaço da cidade, a paleta e a luz da família delas. O que as separa do Espírito comum é a mesma regra nas três.

## A regra do ser de ritual

- **Parado como um ídolo.** O Espírito comum anda; o de ritual está sentado ou plantado. Na deriva ele se arrasta ou ginga, sem passo de bicho.
- **Uma abertura redonda só, com o elemento do deus dentro.** A boca da fornalha (as chamas de Ialprg), o disco em espiral (o verde de Peab), o papo-espelho com a lua (os mares de Zumvi). É a maior mancha de luz da peça e o que se lê no mapa.
- **Sem olho aberto.** Não respondem ao dial porque não olham: o Kilnshade e o Wellmirror têm o olho fechado, a Rootseer não tem rosto. O que pisca (`leds`) fica dentro da abertura.
- **Partes em número certo.** O errado do Espírito comum é contar errado (rabos, olhos, braços); o do ritual é uma parte do corpo que virou o altar.
- Costura do Véu da etapa: duas, de 2 px, só no `glow`, com o par apagado no corpo.

## Peças

| Espécie | Pasta | O que é | O que tem de próprio | Camadas |
|---|---|---|---|---|
| Kilnshade (`soot.ritual`, Ialprg) | `tools/art/creatures/kilnshade/` | O saruê sentado sobre as ancas, de olho fechado, as duas mãos juntas na frente do peito. | O tronco é uma boca de fornalha: arco de ferro fundido e, por dentro, só o fogo. O rabo sobe reto atrás dele como chaminé, com a bituca no alto e a fumaça. No alerta a boca abre e mostra a brasa na garganta. | `leds`: as brasas no chão do forno e a bituca. `glow`: o fogo, as costuras (lombo e nuca), as faíscas. |
| Rootseer (`frond.ritual`, Peab) | `tools/art/creatures/rootseer/` | Uma fronde só, que nunca abriu: o báculo enrolou até virar um disco, em cima de um talo que atravessa uma placa de calçada, sobre seis raízes abertas no chão. | O disco é um olho: a nervura acesa é a íris em espiral e o broto, no meio, a pupila. No alerta o olho abre (a espiral desenrola, a pupila cresce); encolhida, fecha. Alguns lobos já são concreto ou folha seca. | `leds`: o broto. `glow`: a nervura, as costuras (placa e lobos de fora), os esporos. |
| Wellmirror (`rill.ritual`, Zumvi) | `tools/art/creatures/wellmirror/` | O cururu do fundo do poço: sentado dentro de uma manilha de concreto com a tinta amarela gasta, de olho fechado, um braço pendurado na borda. | O espelho da família saiu do dorso e foi para o papo: um disco d'água em pé com a noite de lua cheia dentro, que enche e esvazia. A manilha transborda. | `leds`: as estrelas. `glow`: a borda do espelho, a lua e o rastro dela, os fios que transbordam, as costuras (dorso e manilha), as gotas. |

## Luz e kits

A luz é só a do tipo (`tools/art/ui/types/palette.lua`): Fogo `#A82E1C`, `#F0502E`, `#FF9C7A`; Planta `#2B7A40`, `#4DBD62`, `#A2E8A0`; Água `#2A62B8`, `#4A9CFF`, `#A4D0FF`. A lua do Wellmirror é o azul claro do tipo, sem branco.

O Kilnshade usa `_soot.lua` e a Rootseer `_frond.lua`, sem mudança nos kits. O Wellmirror usa `tools/art/creatures/_rill.lua`, novo: a legenda e a pele do Eco e do Espírito aprovados do Rill, com a luz da paleta; o resto da família entra nele quando for para a arte final.

## Conferência

- `python3 tools/art/creatures/regua.py`: as três saíram de `PENDENTES` e passam.
- Folha: `python3 tools/art/creatures/familia.py rituais espirito:kilnshade espirito:rootseer espirito:wellmirror` grava `docs/art/final/rituais.png`.
