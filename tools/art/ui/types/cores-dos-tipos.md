## Cores e ícones dos tipos

Seção para o `docs/art/estilo-ui.md` (0.26.0). A fonte é `tools/art/ui/types/palette.lua`; os ícones saem de `tools/art/ui/types/build.lua` (`out/<tipo>.png` de 16 × 16, `out/<tipo>_8.png` de 8 × 8, folha em `out/folha.png`) e as Fagulhas de `tools/art/sparks/build.lua` leem a mesma paleta. Para mudar uma cor, edite o `palette.lua` e rode os dois, as Fagulhas primeiro.

| Tipo | id | Principal | Claro | Escuro | Ícone | Contraste no painel `#1e1830` |
|---|---|---|---|---|---|---|
| Fogo | `fire` | `#F0502E` | `#FF9C7A` | `#A82E1C` | chama, com língua à direita | 4,8 |
| Água | `water` | `#4A9CFF` | `#A4D0FF` | `#2A62B8` | gota de ponta fina | 6,1 |
| Planta | `plant` | `#4DBD62` | `#A2E8A0` | `#2B7A40` | folha na diagonal, com talo | 7,1 |
| Terra | `earth` | `#C0915A` | `#E6C594` | `#7E5A32` | pedra torta, com pico | 6,1 |
| Elétrico | `electric` | `#FFD23A` | `#FFEE9A` | `#B8901C` | raio em Z | 11,8 |
| Metal | `metal` | `#93A1B3` | `#CCD6E2` | `#566274` | lingote | 6,5 |
| Luz | `light` | `#FFF0B8` | `#FFFBE6` | `#CDB468` | sol de oito raios | 15,0 |
| Sombra | `shadow` | `#A677AB` | `#D2ABD6` | `#68426E` | lua escura (crescente) | 4,8 |
| Espectral | `spectral` | `#D3E2F4` | `#F2F7FF` | `#8A9DBA` | chama fria, oca | 13,0 |
| Digital | `digital` | `#A8F040` | `#DCFA9E` | `#62A01E` | pixel soltando pixels | 12,4 |
| Feérico | `fae` | `#FFA8E0` | `#FFD6F1` | `#C0669E` | par de asas de fada | 9,7 |
| Dracônico | `draconic` | `#DE4F84` | `#F797B6` | `#8E2852` | escama com quilha | 4,5 |

Contraste pela fórmula da WCAG 2, calculado pelo `build.lua`, que acusa qualquer principal abaixo de 4,5 no painel. Sobre o fundo `#120e1a` todos sobem (o menor é 5,0, do Dracônico).

### Regra

- Tipo é sempre **cor + ícone**. A cor sozinha nunca diz o tipo: em escala de cinza Fogo, Sombra e Dracônico ficam no mesmo cinza, e Luz, Espectral, Elétrico e Digital também; quem separa é a silhueta.
- A cor principal de um tipo nunca é o ciano do sinal (`#5fd3c6` e vizinhos, que é das ferramentas e do que se lê do mundo) nem o violeta do Véu (`#9b7bff` e vizinhos, que é do jogador). Por isso o Digital saiu do verde-água para o verde-limão e a Sombra saiu do violeta apagado para o ameixa.
- O Fogo é vermelho, não laranja: o laranja `#ff7a45` é da Essência e só pede ação.
- Texto e número na cor do tipo usam a principal ou o claro. O escuro é só sombra de ícone e fundo de etiqueta: sobre o painel ele fica entre 2,1 e 3,2 em oito tipos e não serve para texto.
- Etiqueta de tipo: fundo no escuro, ícone de 8 e texto no claro, ou só o ícone de 8 ao lado do nome na principal.
- O ícone de 16 segue "Ícone de 16 px" (contorno fechado, três tons, luz de cima à esquerda). O de 8 é a exceção: chapado, sem contorno, porque o contorno comeria o desenho; só sobre painel ou fundo escuro, nunca sobre o mapa.
- Formas reservadas: nenhuma das doze vira ícone de item. O Metal é lingote porque a engrenagem já é a sucata; a escama do Dracônico tem o arco em cima e a ponta embaixo, o contrário da gota.
- As Fagulhas do mapa usam os mesmos três tons, com o miolo próprio de cada uma (`tools/art/sparks/sparks.json`).
