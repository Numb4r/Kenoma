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
| Kilnshade (`soot.ritual`, Ialprg) | `tools/art/creatures/kilnshade/` | O saruê sentado sobre as ancas, de olho fechado (a fresta escura em arco, de 4 px, numa pálpebra clara), as duas mãos juntas na frente do peito. A cabeça é grande: a cara branca passa de 8×7 px no mapa e as duas orelhas ficam separadas. | O tronco é uma boca de fornalha: arco de ferro fundido e, por dentro, o fogo em cima de um leito escuro de carvão. O rabo é de saruê: sai grosso e peludo da anca, deita no chão, sobe em S afinando e a ponta, fina, enrola para fora; a chaminé é só a ponta, com a bituca e a fumaça. No alerta a boca abre e mostra a brasa na garganta. | `leds`: as três brasas no leito de carvão (separadas do fogo por uma linha escura) e a bituca. `glow`: o fogo, as costuras (lombo e nuca), as faíscas. |
| Rootseer (`frond.ritual`, Peab) | `tools/art/creatures/rootseer/` | Uma fronde só, que nunca abriu: o talo sobe vergado de uma placa de calçada, com as pinas alternadas da família (compridas de um lado, curtas do outro) só na metade de baixo, e a ponta enrola num báculo que pende para a frente, fora do eixo do talo. O pescoço fica nu: a silhueta tem três vazios (debaixo do báculo, atrás do pescoço, entre a pina de baixo e a placa). O tronco é um degrau de valor mais escuro que a copa (pinas em `c`, `b`, `a`; a copa puxada para o claro). A placa fica alta sobre seis raízes compridas, em arco; o vão entre elas é sombra (`k`), não vazio, e só os pés ficam soltos. | O báculo é um olho: a nervura acesa é a íris em espiral e o broto, no meio, a pupila. A silhueta é um "?", não um disco no cabo: os lobos de fora do rolo somem ao longo da volta (sem coroa de pétalas). No alerta o olho abre (a espiral desenrola, a pupila cresce); encolhida, fecha. Alguns lobos já são concreto ou folha seca. | `leds`: o broto. `glow`: a nervura (do pé do talo ao meio do rolo), as costuras (placa e pina de cima do tronco), os esporos. |
| Wellmirror (`rill.ritual`, Zumvi) | `tools/art/creatures/wellmirror/` | O cururu do fundo do poço: sentado dentro de uma manilha de concreto com a tinta amarela gasta, um braço pendurado na borda. A cabeça está erguida e virada três quartos para a câmera: larga, com os dois calombos dos olhos no alto, cada um com a pálpebra clara e a fresta escura, e a boca de lado a lado sobre o queixo creme. | O espelho da família saiu do dorso e foi para o papo, que pende do queixo: a pele creme esticada em volta de um disco d'água em pé com a noite de lua cheia dentro, que enche e esvazia. Apagado (de dia), a lua e o rastro continuam claros dentro do disco. Encolhido, o papo esvazia mas fica um disco inteiro acima da borda. A manilha transborda. | `leds`: as estrelas. `glow`: a borda do espelho, a lua e o rastro dela, o luar no alto dos dois calombos dos olhos (um arco de 3 a 5 px em cada um, para a cabeça se ler à noite; apagado é pele e pálpebra), os fios que transbordam, as costuras (dorso e manilha), as gotas. |

Os acessórios das variantes ficam espalhados pela peça, um em cada parte (rabo, anca, pescoço, testa no Kilnshade; talo, raízes, báculo, placa na Rootseer; manilha, dorso, glândula no Wellmirror), para a variante se ler pelo lugar e não só pela cor.

## Luz e kits

A luz é só a do tipo (`tools/art/ui/types/palette.lua`): Fogo `#A82E1C`, `#F0502E`, `#FF9C7A`; Planta `#2B7A40`, `#4DBD62`, `#A2E8A0`; Água `#2A62B8`, `#4A9CFF`, `#A4D0FF`. A lua do Wellmirror é o azul claro do tipo, sem branco; apagada, ela e o rastro são cores de corpo (`m` `#93A5BD`, `l` `#5C7696` em `_rill.lua`), não luz.

O Kilnshade usa `_soot.lua` e a Rootseer `_frond.lua`, sem mudança nos kits. O Wellmirror usa `tools/art/creatures/_rill.lua`, que só ele usa: a legenda e a pele do Eco e do Espírito aprovados do Rill, com a luz da paleta; o resto da família entra nele quando for para a arte final. O luar da cabeça são dois caracteres dele (`F` e `G`, o azul médio e o claro do tipo, com a pele `e` e a pálpebra `W` como par apagado).

Contorno: na régua ele é teto (Espírito: 0,28 no mapa, 0,22 no retrato), não piso. A Rootseer fica em 0,24 no mapa e 0,13 no retrato; quem segura é a sombra debaixo da placa e o vão de 1 px entre duas partes, que vira junta (`k`) em vez de contorno (`seal` no build dela).

## Conferência

- `python3 tools/art/creatures/regua.py`: as três saíram de `PENDENTES` e passam.
- No mapa, a 36 px: conferir o quadro 0 do idle, o alerta e o encolhido da fuga de noite (corpo com o tom, emissivos acesos) e de dia (corpo puro, emissivos apagados), não só a folha.
- Folha: `python3 tools/art/creatures/familia.py rituais espirito:kilnshade espirito:rootseer espirito:wellmirror` grava `docs/art/final/rituais.png`.
