# Textos do crafting (fase 1)

Para revisão do dono. O `executor` copia daqui para `app/assets/data/` (`items.json`, `recipes.json`, `mentor.json` e os textos de interface). Base: GDD, "Crafting", em especial "Regras da fase 1".

Como ler:

- `entra` lista os ingredientes. **As quantidades são sugestão**, o balanceamento é da thread principal.
- `condição` é o que precisa valer na hora de fabricar. Nos refinos é sempre uma só.
- `pista` é o texto da silhueta no grimório, antes de a receita ser descoberta.
- `substituto` é o caminho comum de uma receita que pede material de calendário (GDD, "Condições, não lugares"): vira uma segunda receita com a mesma saída, id com `.alt` no fim.
- "Essência (qualquer)" é `any:essence`, como no selo reforçado. "Pó (qualquer)" é qualquer Pó de Essência.

## Resumo

| Id | Nome | Degrau |
| --- | --- | --- |
| `item.meteorite` | Meteorito | Bruto |
| `item.rune` | Runa caída | Bruto |
| `item.wood` | Galho de gelo | Bruto |
| `item.vessel.glass` | Garrafa de vidro | Peça (coletor) |
| `item.vessel.dark` | Frasco escuro | Peça (coletor) |
| `item.vessel.candle` | Pote de vela | Peça (coletor) |
| `item.vessel.thermal` | Frasco térmico | Peça (coletor) |
| `item.rain_water` | Água de chuva | Refinado (condição) |
| `item.snow` | Neve | Refinado (condição, perecível) |
| `item.snow_water` | Água de neve | Refinado (condição) |
| `item.moonlight.new` | Luz de lua nova | Refinado (condição) |
| `item.moonlight.waxing` | Luz de lua crescente | Refinado (condição) |
| `item.moonlight.full` | Luz de lua cheia | Refinado (condição) |
| `item.moonlight.waning` | Luz de lua minguante | Refinado (condição) |
| `item.rift_smoke` | Fumaça de Fenda | Refinado (condição) |
| `item.ref.consecrated_chalk` | Giz consagrado | Refinado |
| `item.ref.white_clay` | Barro branco | Refinado |
| `item.ref.quicklime` | Cal viva | Refinado |
| `item.ref.lustral_water` | Água lustral | Refinado |
| `item.ref.essence_salt` | Sal de Essência | Refinado |
| `item.ref.dried_herbs` | Ervas secas | Refinado |
| `item.ref.braided_fiber` | Fibra trançada | Refinado |
| `item.ref.green_infusion` | Infusão verde | Refinado |
| `item.ref.cold_iron` | Ferro frio | Refinado |
| `item.ref.living_rust` | Ferrugem viva | Refinado |
| `item.ref.tin_mirror` | Espelho de lata | Refinado |
| `item.ref.still_ectoplasm` | Ectoplasma sereno | Refinado |
| `item.comp.sigil_ink` | Tinta sigílica | Componente |
| `item.comp.seal_core` | Núcleo de selo | Componente |
| `item.comp.ether_filament` | Filamento etéreo | Componente |
| `item.comp.veil_weave` | Trama do Véu | Componente |
| `item.comp.cold_setting` | Engaste de ferro frio | Componente |
| `item.comp.sun_lens` | Lente de sol | Componente |
| `item.comp.focus_extract` | Extrato de foco | Componente |
| `item.comp.white_wax` | Lacre branco | Componente |
| `item.comp.hidden_ink` | Tinta oculta | Componente (lua nova) |
| `item.comp.waning_salt` | Sal minguante | Componente (lua minguante) |
| `item.seal.sigil` | Selo sigílico | Peça |
| `item.seal.umbral` | Selo umbral | Peça (lua nova) |
| `item.seal.moonlit` | Selo enluarado | Peça (lua cheia) |
| `item.seal.haunt` | Selo de assombro | Peça (lua cheia) |
| `item.tonic.vigil` | Tônico de vigília | Peça |
| `item.tonic.waxing` | Tônico crescente | Peça (lua crescente) |
| `item.tonic.rift` | Tônico de fumaça | Peça |
| `item.amulet.summer.downpour` | Amuleto do Aguaceiro | Peça (verão) |
| `item.amulet.summer.thunder` | Amuleto da Trovoada | Peça (verão) |
| `item.amulet.autumn.harvest` | Amuleto da Colheita | Peça (outono) |
| `item.amulet.autumn.leaf` | Amuleto da Folha Seca | Peça (outono) |
| `item.amulet.winter.snow` | Amuleto de Neve | Peça (inverno) |
| `item.amulet.winter.mist` | Amuleto da Bruma | Peça (inverno) |
| `item.amulet.spring.sprout` | Amuleto do Broto | Peça (primavera) |
| `item.amulet.spring.bloom` | Amuleto da Florada | Peça (primavera) |
| `item.bag.satchel` | Bolsa de andarilho | Peça (equipável) |
| `item.bag.deep` | Alforje do Véu | Peça (equipável) |
| `item.belt.bandolier` | Cinto de frascos | Peça (equipável) |
| `item.grimoire.field` | Grimório de campo | Peça (equipável) |
| `item.jewel.meteor` | Anel de meteorito | Peça (equipável) |
| `item.jewel.rune` | Pingente rúnico | Peça (equipável) |

## Brutos sem nome

Já caem no mundo pelas épocas (chuva de meteoros, Chuva de Runas, chuva congelante), só faltava o nome.

### item.meteorite
- nome: Meteorito
- descrição: Pedra que caiu ainda morna e não esfriou até hoje.

### item.rune
- nome: Runa caída
- descrição: Um sinal que choveu inteiro e ninguém sabe ler.

### item.wood
- nome: Galho de gelo
- descrição: Galho que o gelo quebrou, e que continua frio dentro da bolsa.

## Recipientes

Vazios, vão no cinto ou são plantados. Todos de improviso. A garrafa de vidro é a porta de entrada: só pede Caco de vidro (0.24.2; antes era Sucata).

### item.glass_shard
- nome: Caco de vidro
- descrição: Resto de garrafa na calçada dos bares. Corta menos do que parece.

### item.vessel.glass
- nome: Garrafa de vidro
- descrição: Cacos de vidro refundidos, bons para guardar o que cai do céu.
- enche com: Água de chuva (durante garoa, chuva ou tempestade) e Neve (durante neve do calendário)

### recipe.vessel.glass
- saída: item.vessel.glass
- entra: Caco de vidro ×2
- pista: algo para guardar chuva
- condição: nenhuma

### item.vessel.dark
- nome: Frasco escuro
- descrição: Vidro que não deixa a luz sair depois que entra.
- enche com: Luz de lua, à noite, uma por grupo de fase

### recipe.vessel.dark
- saída: item.vessel.dark
- entra: Garrafa de vidro ×1, Pó de Essência de Sombra ×2
- pista: um vidro que guarda luz
- condição: nenhuma

### item.vessel.candle
- nome: Pote de vela
- descrição: Uma lata com cera de ectoplasma, que a fumaça errada acende sozinha.
- enche com: Fumaça de Fenda (enquanto não há Fendas: na Noite das Fendas e nas Cinzas do Véu)

### recipe.vessel.candle
- saída: item.vessel.candle
- entra: Sucata ×1, Ectoplasma ×2
- pista: algo que prende fumaça
- condição: nenhuma

### item.vessel.thermal
- nome: Frasco térmico
- descrição: Garrafa agasalhada em fibra, onde a neve esquece de derreter.
- enche com: Neve (não derrete enquanto estiver nele)

### recipe.vessel.thermal
- saída: item.vessel.thermal
- entra: Garrafa de vidro ×1, Fibra trançada ×2
- pista: uma garrafa agasalhada
- condição: nenhuma

O GDD não pede outro recipiente na fase 1. A luz da Lua Carmim (perecível) é receita de janela, fase 3, e cabe no Frasco escuro.

## Condições engarrafadas

Aba Condições da bolsa. Não têm receita: enchem no recipiente.

### item.rain_water
- nome: Água de chuva
- descrição: Chuva de verdade, guardada antes de tocar o chão.
- recipiente: Garrafa de vidro
- qualidade: garoa comum, chuva boa, tempestade perfeita

### item.snow
- nome: Neve
- descrição: Neve do Véu, que não é fria na mão e derrete assim mesmo.
- recipiente: Garrafa de vidro (derrete em alguns dias e vira Água de neve) ou Frasco térmico (não derrete)
- qualidade: Neve do Véu comum, Neve boa, Nevasca perfeita

### item.snow_water
- nome: Água de neve
- descrição: O que sobra da neve quando ninguém a guardou direito.
- uso: vale como Água de chuva boa em qualquer receita

### item.moonlight.new
- nome: Luz de lua nova
- descrição: O frasco parece vazio, e pesa mais do que vazio.

### item.moonlight.waxing
- nome: Luz de lua crescente
- descrição: Uma claridade fina que aumenta um pouco cada vez que você olha.

### item.moonlight.full
- nome: Luz de lua cheia
- descrição: Luz inteira, que atravessa a tampa e faz sombra dentro da bolsa.

### item.moonlight.waning
- nome: Luz de lua minguante
- descrição: Uma luz que vai embora devagar e leva junto o que estiver perto.

### item.rift_smoke
- nome: Fumaça de Fenda
- descrição: Fumaça que sobe para o lado errado e cheira a lugar nenhum.
- recipiente: Pote de vela

## Refinos

Improviso, em qualquer lugar, com a condição valendo na hora. Descobrem-se no Experimentar.

### item.ref.consecrated_chalk
- nome: Giz consagrado
- descrição: Giz que passou a noite ao relento e agora risca até no ar.

### recipe.refine.consecrated_chalk
- saída: item.ref.consecrated_chalk
- entra: Giz ×2
- pista: algo da noite
- condição: à noite

### item.ref.white_clay
- nome: Barro branco
- descrição: Giz amolecido na chuva, que guarda a forma do que encostar nele.

### recipe.refine.white_clay
- saída: item.ref.white_clay
- entra: Giz ×1, Água pura ×1
- pista: algo da chuva
- condição: durante chuva (garoa, chuva ou tempestade)

### item.ref.quicklime
- nome: Cal viva
- descrição: Giz queimado de sol, que esquenta quando sente água por perto.

### recipe.refine.quicklime
- saída: item.ref.quicklime
- entra: Giz ×2
- pista: algo do sol
- condição: de dia, com sol forte

### item.ref.lustral_water
- nome: Água lustral
- descrição: Água pura que ouviu outra água e ficou mais quieta.

### recipe.refine.lustral_water
- saída: item.ref.lustral_water
- entra: Água pura ×2
- pista: perto de água
- condição: perto de água (qualquer rio, lago ou córrego)

### item.ref.essence_salt
- nome: Sal de Essência
- descrição: Pó de Essência que a umidade juntou em grãos, todos do mesmo tamanho.

### recipe.refine.essence_salt
- saída: item.ref.essence_salt
- entra: Pó (qualquer) ×3
- pista: perto de água
- condição: perto de água

### item.ref.dried_herbs
- nome: Ervas secas
- descrição: Ervas que o sol secou sem tirar o cheiro.

### recipe.refine.dried_herbs
- saída: item.ref.dried_herbs
- entra: Ervas ×2
- pista: algo do sol
- condição: de dia, com sol forte

### item.ref.braided_fiber
- nome: Fibra trançada
- descrição: Talos trançados no meio do mato, que apertam sozinhos o nó.

### recipe.refine.braided_fiber
- saída: item.ref.braided_fiber
- entra: Ervas ×2
- pista: onde o chão é verde
- condição: em área verde

### item.ref.green_infusion
- nome: Infusão verde
- descrição: Erva e água deixadas na sombra de uma árvore até a água mudar de ideia.

### recipe.refine.green_infusion
- saída: item.ref.green_infusion
- entra: Ervas ×1, Água pura ×1
- pista: onde o chão é verde
- condição: em área verde

### item.ref.cold_iron
- nome: Ferro frio
- descrição: Sucata que perdeu o calor do dia e não aceita outro.

### recipe.refine.cold_iron
- saída: item.ref.cold_iron
- entra: Sucata ×2
- pista: algo da noite
- condição: à noite

### item.ref.living_rust
- nome: Ferrugem viva
- descrição: Ferrugem que a chuva acordou e que tinge o que tocar.

### recipe.refine.living_rust
- saída: item.ref.living_rust
- entra: Sucata ×2
- pista: algo da chuva
- condição: durante chuva (garoa, chuva ou tempestade)

### item.ref.tin_mirror
- nome: Espelho de lata
- descrição: Lata polida ao sol até devolver mais luz do que recebeu.

### recipe.refine.tin_mirror
- saída: item.ref.tin_mirror
- entra: Sucata ×2
- pista: algo do sol
- condição: de dia, com sol forte

### item.ref.still_ectoplasm
- nome: Ectoplasma sereno
- descrição: Ectoplasma que o sereno assentou, e que para de tremer na mão.

### recipe.refine.still_ectoplasm
- saída: item.ref.still_ectoplasm
- entra: Ectoplasma ×2
- pista: algo da noite
- condição: à noite

## Componentes

Na Bancada de casa, refinados mais Essência. Vêm da página `page.components`.

### item.comp.sigil_ink
- nome: Tinta sigílica
- descrição: Tinta que seca na forma do sinal, não na do traço.

### recipe.comp.sigil_ink
- saída: item.comp.sigil_ink
- entra: Giz consagrado ×1, Água lustral ×1, Essência (qualquer) ×1
- pista: giz e água que já mudaram
- condição: na Bancada

### item.comp.seal_core
- nome: Núcleo de selo
- descrição: Um miolo de barro que lembra a última coisa que escutou.

### recipe.comp.seal_core
- saída: item.comp.seal_core
- entra: Barro branco ×1, Ectoplasma sereno ×1, Essência (qualquer) ×1
- pista: barro com um resto dentro
- condição: na Bancada

### item.comp.ether_filament
- nome: Filamento etéreo
- descrição: Um fio que só aparece quando está esticado.

### recipe.comp.ether_filament
- saída: item.comp.ether_filament
- entra: Ectoplasma sereno ×1, Fibra trançada ×1, Essência (qualquer) ×1
- pista: um fio que quase não existe
- condição: na Bancada

### item.comp.veil_weave
- nome: Trama do Véu
- descrição: Pano tingido de ferrugem, com mais dentro do que fora.

### recipe.comp.veil_weave
- saída: item.comp.veil_weave
- entra: Fibra trançada ×2, Ferrugem viva ×1, Essência de Traço (qualquer) ×1
- pista: fibra tingida
- condição: na Bancada

### item.comp.cold_setting
- nome: Engaste de ferro frio
- descrição: Uma garra de ferro que segura o que for posto nela, e não solta por educação.

### recipe.comp.cold_setting
- saída: item.comp.cold_setting
- entra: Ferro frio ×2, Sal de Essência ×1, Essência (qualquer) ×1
- pista: ferro e sal
- condição: na Bancada

### item.comp.sun_lens
- nome: Lente de sol
- descrição: Água presa entre dois espelhos, que mostra o meio-dia a qualquer hora.

### recipe.comp.sun_lens
- saída: item.comp.sun_lens
- entra: Espelho de lata ×1, Água lustral ×1, Essência (qualquer) ×1
- pista: luz presa em água
- condição: na Bancada

### item.comp.focus_extract
- nome: Extrato de foco
- descrição: Três gotas escuras que deixam o resto do mundo mais devagar.

### recipe.comp.focus_extract
- saída: item.comp.focus_extract
- entra: Infusão verde ×1, Ervas secas ×1, Essência (qualquer) ×1
- pista: erva duas vezes
- condição: na Bancada

### item.comp.white_wax
- nome: Lacre branco
- descrição: Cera de cal e ectoplasma, que fecha uma coisa e avisa quem a abriu.

### recipe.comp.white_wax
- saída: item.comp.white_wax
- entra: Cal viva ×1, Ectoplasma sereno ×1, Essência (qualquer) ×1
- pista: algo que fecha
- condição: na Bancada

## Peças de uso

Dão uso diário aos componentes. Vêm junto na página `page.components`. Não estavam no pedido: se não entrarem, tinta, núcleo e extrato só servem às receitas de lua.

### item.seal.sigil
- nome: Selo sigílico
- descrição: Selo de núcleo e tinta, que perdoa a mão que treme.
- efeito: mais tolerância que o Selo reforçado, sem tipo

### recipe.seal.sigil
- saída: item.seal.sigil
- entra: Núcleo de selo ×1, Tinta sigílica ×1
- pista: um selo feito por dentro
- condição: na Bancada

### item.tonic.vigil
- nome: Tônico de vigília
- descrição: Amargo, e o tempo passa mais devagar só de pensar em beber.
- efeito: mais tempo na sintonia que o Tônico de foco

### recipe.tonic.vigil
- saída: item.tonic.vigil
- entra: Extrato de foco ×1, Água lustral ×1
- pista: um tônico mais fundo
- condição: na Bancada

### item.tonic.rift
- nome: Tônico de fumaça
- descrição: Bebe-se de olhos fechados, e a sintonia espera você abrir.
- efeito: o tônico mais longo; é bônus de calendário, o caminho comum é o Tônico de vigília

### recipe.tonic.rift
- saída: item.tonic.rift
- entra: Extrato de foco ×1, Fumaça de Fenda ×1
- pista: algo de Fenda
- condição: na Bancada

## Receitas de lua

Pedem a luz engarrafada da fase, então podem ser feitas em qualquer noite ou dia depois de encher o frasco. Feitas durante a própria fase, sobem um nível de qualidade. Vêm da página `page.moon`.

### item.seal.umbral
- nome: Selo umbral
- descrição: Um selo que o Eco só percebe quando já fechou.
- efeito: selo de tipo Sombra, com mais tolerância que o Selo de Sombra

### recipe.moon.new.umbral_seal
- saída: item.seal.umbral
- entra: Núcleo de selo ×1, Luz de lua nova ×1, Pó de Essência de Sombra ×3
- pista: algo da lua que não se vê
- condição: Luz de lua nova engarrafada (melhor na lua nova)

### item.comp.hidden_ink
- nome: Tinta oculta
- descrição: Escreve-se com ela no claro e só se lê no escuro.
- efeito: componente (Pingente rúnico)

### recipe.moon.new.hidden_ink
- saída: item.comp.hidden_ink
- entra: Tinta sigílica ×1, Luz de lua nova ×1
- pista: algo da lua que não se vê
- condição: Luz de lua nova engarrafada (melhor na lua nova)

### item.seal.moonlit
- nome: Selo enluarado
- descrição: Brilha fraco na mão, e os Feéricos vêm ver o que é.
- efeito: selo de tipo Feérico, com mais tolerância que o Selo Feérico

### recipe.moon.full.moonlit_seal
- saída: item.seal.moonlit
- entra: Núcleo de selo ×1, Luz de lua cheia ×1, Pó de Essência Feérica ×3
- pista: algo da lua inteira
- condição: Luz de lua cheia engarrafada (melhor na lua cheia)

### item.seal.haunt
- nome: Selo de assombro
- descrição: Frio ao toque, como maçaneta de casa vazia.
- efeito: selo de tipo Espectral, com mais tolerância que o Selo Espectral

### recipe.moon.full.haunt_seal
- saída: item.seal.haunt
- entra: Núcleo de selo ×1, Luz de lua cheia ×1, Pó de Essência Espectral ×3
- pista: algo da lua inteira
- condição: Luz de lua cheia engarrafada (melhor na lua cheia)

### item.tonic.waxing
- nome: Tônico crescente
- descrição: Cada gole rende um pouco mais que o anterior.
- efeito: mais tempo na sintonia que o Tônico de vigília

### recipe.moon.waxing.tonic
- saída: item.tonic.waxing
- entra: Extrato de foco ×1, Luz de lua crescente ×1
- pista: algo da lua que cresce
- condição: Luz de lua crescente engarrafada (melhor na crescente)

### item.comp.waning_salt
- nome: Sal minguante
- descrição: Sal que desmancha o que não precisa mais ficar inteiro.
- efeito: componente (Amuleto da Folha Seca)

### recipe.moon.waning.salt
- saída: item.comp.waning_salt
- entra: Sal de Essência ×1, Luz de lua minguante ×1
- pista: algo da lua que some
- condição: Luz de lua minguante engarrafada (melhor na minguante)

## Amuletos de estação

Um espaço de amuleto no loadout. Cada receita só se fabrica na própria estação (datas astronômicas, hemisfério sul); o amuleto pronto funciona o ano inteiro. Vêm da página `page.seasons`.

### item.amulet.summer.downpour
- nome: Amuleto do Aguaceiro
- descrição: Pinga sem parar e nunca molha o bolso.
- efeito: mais 1 garrafa no cinto

### recipe.amulet.summer.downpour
- saída: item.amulet.summer.downpour
- entra: Água de chuva ×3, Engaste de ferro frio ×1, Lacre branco ×1
- pista: algo do verão
- condição: no verão

### item.amulet.summer.thunder
- nome: Amuleto da Trovoada
- descrição: Vibra um segundo antes de cada trovão, até dos que não vêm.
- efeito: garrafas enchem mais rápido; mais forte no verão

### recipe.amulet.summer.thunder
- saída: item.amulet.summer.thunder
- entra: Água de chuva ×3, Ferro frio ×2, Engaste de ferro frio ×1
- pista: algo do verão
- condição: no verão

### item.amulet.autumn.harvest
- nome: Amuleto da Colheita
- descrição: Um saquinho de pano que sempre tem lugar para mais um punhado.
- efeito: mais espaço na bolsa

### recipe.amulet.autumn.harvest
- saída: item.amulet.autumn.harvest
- entra: Ervas secas ×3, Trama do Véu ×1, Lacre branco ×1
- pista: algo do outono
- condição: no outono

### item.amulet.autumn.leaf
- nome: Amuleto da Folha Seca
- descrição: Uma folha que caiu e ficou parada no ar, à espera de onde pousar.
- efeito: mais tolerância no selo; mais forte no outono

### recipe.amulet.autumn.leaf
- saída: item.amulet.autumn.leaf
- entra: Ervas secas ×2, Sal minguante ×1, Engaste de ferro frio ×1
- pista: algo do outono
- condição: no outono

### item.amulet.winter.snow
- nome: Amuleto de Neve
- descrição: Neve que não derrete, presa em ferro, e que deixa o instante mais comprido.
- efeito: mais tempo de tônico; mais forte no inverno

### recipe.amulet.winter.snow
- saída: item.amulet.winter.snow
- entra: Neve ×2, Engaste de ferro frio ×1, Lacre branco ×1
- pista: algo que só cai uma vez por ano
- condição: no inverno (a Neve vem do Inverno do Véu e da Noite Branca; Água de neve não serve)

### item.amulet.winter.mist
- nome: Amuleto da Bruma
- descrição: Embaça por dentro nas manhãs frias, e o erro some junto.
- efeito: mais tolerância no selo

### recipe.amulet.winter.mist
- saída: item.amulet.winter.mist
- entra: Ectoplasma sereno ×3, Filamento etéreo ×1, Lacre branco ×1
- pista: algo do inverno
- condição: no inverno

### item.amulet.spring.sprout
- nome: Amuleto do Broto
- descrição: Um broto que nunca vira planta, e faz crescer o que estiver em volta.
- efeito: mais 1 coletor plantado; mais forte na primavera

### recipe.amulet.spring.sprout
- saída: item.amulet.spring.sprout
- entra: Infusão verde ×2, Trama do Véu ×1, Lacre branco ×1
- pista: algo da primavera
- condição: na primavera

### item.amulet.spring.bloom
- nome: Amuleto da Florada
- descrição: Uma flor de ipê atrás de uma lente, aberta desde o dia em que foi fechada.
- efeito: garrafas enchem mais rápido; mais forte na primavera

### recipe.amulet.spring.bloom
- saída: item.amulet.spring.bloom
- entra: Infusão verde ×2, Lente de sol ×1, Lacre branco ×1
- pista: algo da primavera
- condição: na primavera

## Equipáveis

Vêm da página `page.gear`. As bolsas aparecem na página com o nível que libera a receita.

### item.bag.satchel
- nome: Bolsa de andarilho
- descrição: Cabe mais do que parece, e pesa o mesmo.
- efeito: mais espaço na bolsa (sugestão: 60)

### recipe.bag.satchel
- saída: item.bag.satchel
- entra: Trama do Véu ×2, Fibra trançada ×4, Lacre branco ×1
- pista: pano e fibra
- condição: na Bancada, nível 8

### item.bag.deep
- nome: Alforje do Véu
- descrição: O fundo fica um pouco depois de onde a mão alcança.
- efeito: mais espaço na bolsa (sugestão: 80)

### recipe.bag.deep
- saída: item.bag.deep
- entra: Trama do Véu ×4, Filamento etéreo ×2, Engaste de ferro frio ×1
- pista: pano e um fio que quase não existe
- condição: na Bancada, nível 15

### item.belt.bandolier
- nome: Cinto de frascos
- descrição: Quatro alças de pano, e nenhuma garrafa bate na outra.
- efeito: mais 1 garrafa no cinto

### recipe.belt.bandolier
- saída: item.belt.bandolier
- entra: Trama do Véu ×1, Engaste de ferro frio ×2
- pista: pano e ferro
- condição: na Bancada

### item.grimoire.field
- nome: Grimório de campo
- descrição: Caderno de capa de pano que anota sozinho onde você deixou as coisas.
- efeito: mais 1 coletor plantado

### recipe.grimoire.field
- saída: item.grimoire.field
- entra: Tinta sigílica ×2, Trama do Véu ×1, Lente de sol ×1
- pista: tinta, pano e uma lente
- condição: na Bancada

### item.jewel.meteor
- nome: Anel de meteorito
- descrição: Uma lasca de céu num aro de ferro, ainda morna no dedo.
- efeito: mais tolerância no selo

### recipe.jewel.meteor
- saída: item.jewel.meteor
- entra: Meteorito ×1, Lente de sol ×1, Engaste de ferro frio ×1
- substituto: Ferro frio ×8 no lugar do Meteorito
- pista: algo que caiu do céu
- condição: na Bancada

### item.jewel.rune
- nome: Pingente rúnico
- descrição: Uma runa presa num galho, que muda de desenho quando ninguém olha.
- efeito: mais tempo de tônico

### recipe.jewel.rune
- saída: item.jewel.rune
- entra: Runa caída ×1, Galho de gelo ×1, Tinta oculta ×1
- substituto: Giz consagrado ×8 no lugar da Runa caída, Fibra trançada ×8 no lugar do Galho de gelo
- pista: um sinal que ninguém lê
- condição: na Bancada

## Páginas de grimório

Fenda e Mercador ainda não existem, então as quatro páginas chegam pelo mentor (Número desconhecido), como mensagens por acontecimento, uma vez cada.

### page.components
- nome: Página dos componentes
- libera: as 8 receitas `recipe.comp.*`, `recipe.seal.sigil`, `recipe.tonic.vigil` e `recipe.tonic.rift`
- quando: depois do terceiro refino fabricado, com a Bancada já liberada
- mensagem: Você anda deixando giz ao relento. Eu vi. O que se refina sozinho ainda é pouco: junto, e com Essência, vira outra coisa. Deixei uma página no seu grimório. A Bancada de casa sabe o resto. Você sabe o que está montando?

### page.moon
- nome: Página das luas
- libera: as 6 receitas `recipe.moon.*`
- quando: depois de encher a primeira garrafa, com qualquer conteúdo
- mensagem: Uma garrafa cheia. Bonito. A lua também cabe num frasco, se o vidro for escuro e a noite for inteira. Cada fase guarda uma coisa diferente, e nenhuma delas é luz. Mandei a página. O que você acha que a lua nova esconde?

### page.seasons
- nome: Página das estações
- libera: as 8 receitas `recipe.amulet.*`
- quando: depois do quinto componente fabricado
- mensagem: A cidade troca de pele quatro vezes por ano e quase ninguém repara. Há coisas que só se fazem numa estação, e elas esperam um ano inteiro por quem perdeu a hora. Deixei a página das estações. Em que estação você está, mesmo?

### page.gear
- nome: Página dos equipamentos
- libera: `recipe.bag.satchel`, `recipe.bag.deep`, `recipe.belt.bandolier`, `recipe.grimoire.field`, `recipe.jewel.meteor`, `recipe.jewel.rune`
- quando: na primeira vez que a bolsa enche; se nunca encher, ao chegar no nível 8
- mensagem: Bolsa cheia. Acontece com quem pega tudo o que brilha. Dá para costurar uma maior, e um cinto, e mais do que isso. A página já está no grimório. Quanto de cidade você pretende carregar?

## Quest da primeira garrafa

Ensina o crafting pelos coletores. Começa na primeira vez que o jogador pega Caco de vidro (0.24.2; antes era Sucata). Mensagens do mentor (Número desconhecido), uma vez cada, no tom de `docs/textos-mentor.md`.

| Id | Quando | Texto |
| --- | --- | --- |
| `craft_tut_start` | primeiro Caco de vidro na bolsa | Caco de vidro. Todo mundo desvia. Dois desses, refundidos, voltam a ser garrafa, e garrafa guarda o que cai do céu. Faça uma na Bancada. O que você guardaria, se desse para guardar o tempo? |
| `craft_tut_bottle` | passo (a): fez a garrafa | Uma garrafa vazia. Na bolsa ela só ocupa lugar. Abra a Bolsa, na aba Condições, e ponha a garrafa no cinto. Vazio também se carrega, não? |
| `craft_tut_belt` | passo (b): garrafa no cinto | Agora ela anda com você. Quando chover, enche sozinha, no seu passo. Se o céu demorar, plante a garrafa no chão e volte depois: ela espera melhor do que você. Você sabe esperar? |
| `craft_tut_fill` | passo (c): a garrafa encheu ou foi plantada | Pronto. O céu faz o resto. Água que não tocou o chão ainda lembra de onde veio, e a Bancada sabe a diferença. Quando a garrafa estiver cheia, faça uma receita com essa água. O que você acha que a chuva sabe? |
| `craft_tut_done` | passo (d): fez uma receita com a água | Feito. Você pegou uma coisa do céu e fez outra com as mãos. Há mais para guardar: neve, fumaça, a lua, cada uma no seu vidro. A cidade chove para todo mundo. Quem mais você acha que está guardando? |
| `craft_tut_gift` | abriu a aba Condições sem nenhuma garrafa | Você abriu o cinto e não tinha o que pôr nele. Deixei uma garrafa na sua bolsa. Não agradeça, é só vidro. As próximas você faz: dois Cacos de vidro, na Bancada. O que você pretende guardar nela? |

- O presente sai uma vez só e vale como o passo (a): quem ganhou a garrafa não recebe `craft_tut_bottle` e segue do passo (b). Se a quest ainda não tinha começado, o presente a começa.
- `craft_tut_fill` e `page_moon` (primeira garrafa cheia) podem cair juntas. Sugestão: `page_moon` só depois de `craft_tut_done`.

### Lista de tarefas
- `ui.craft_tut.title`: Primeira garrafa
- `ui.craft_tut.step.bottle`: Faça uma garrafa na Bancada
- `ui.craft_tut.step.belt`: Ponha a garrafa no cinto
- `ui.craft_tut.step.fill`: Encha na chuva ou plante a garrafa
- `ui.craft_tut.step.recipe`: Faça uma receita com a água

## Textos de interface

### Qualidade
Sai sempre depois da palavra "qualidade" e concorda com ela: "qualidade comum", "qualidade boa", "qualidade perfeita". Nunca "bom" ou "perfeito", nem quando o item é masculino.

- `ui.craft.quality.common`: comum
- `ui.craft.quality.good`: boa
- `ui.craft.quality.perfect`: perfeita

### Pistas do Experimentar
Aparecem quando os ingredientes estão certos e falta a condição.

- `ui.craft.hint.night`: Falta algo da noite.
- `ui.craft.hint.sun`: Falta algo do sol.
- `ui.craft.hint.rain`: Falta algo da chuva.
- `ui.craft.hint.water`: Falta algo de água por perto.
- `ui.craft.hint.green`: Falta chão verde.
- `ui.craft.hint.moon`: Falta algo da lua.
- `ui.craft.hint.season`: Falta a estação certa.
- `ui.craft.hint.bench`: Falta a Bancada de casa.
- `ui.craft.hint.level`: Falta nível. Volte no nível {n}.
- `ui.craft.hint.page`: Falta uma página do grimório.

### Experimentar sem resultado
- `ui.craft.try.nothing`: Isso não dá em nada. Nada foi gasto.
- `ui.craft.try.close`: Quase. Um dos dois está certo. Nada foi gasto.
- `ui.craft.try.found`: Receita nova no grimório: {nome}.

### Bolsa
- `ui.bag.full`: Bolsa cheia. Destile, descarte ou fabrique para abrir espaço.
- `ui.bag.next.locked`: A próxima bolsa se fabrica. A receita abre no nível {n}.
- `ui.bag.next.open`: A próxima bolsa se fabrica: {nome}, na Bancada.
- `ui.bag.next.none`: Esta é a maior bolsa que existe, por enquanto.
- `ui.bag.discard`: Descartar rende 1 Pó de Essência a cada 5 itens.
