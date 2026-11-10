# Auditoria do clima (0.17.0)

Base: `docs/GDD.md`, "Tempo, astronomia e clima" (rev 328), o `assets/data/clima.json` e o bloco `climate` da época 6 em `assets/data/epochs.json`. Cada clima tem duas camadas:

- **Tela** (`clima.json`, `layers`): só o que cai do céu ou cobre a vista. Não gira nem dá zoom com o mapa.
- **Mapa** (`clima.json`, `ground`, e as peças do bloco `climate` da época): tudo que está no chão. Desenhado em células z21, com a transformação da câmera (gira, move, dá zoom), em posições que saem da seed, da célula e da janela, iguais em dois aparelhos.

O que muda o mundo (onde algo nasce, o que nasce, quanto dura a coleta) fica na época 7. O que é só desenho (cobertura das ruas, barcos, decoração espalhada pelo chão) fica no `clima.json` e pode mudar sem época nova; mesmo assim sai de hash da seed e da posição, para amigos juntos verem o mesmo.

O que o GDD não define e foi escolhido aqui foi aprovado na revisão da 0.17.0. "Provisório" marca o substituto que vale até existir a espécie ou o sistema (campo `provisional` no `clima.json`); "pendente" marca o que ainda espera revisão. "Sem alvo" marca o efeito que o dado declara, mas que ainda não existe no jogo (espécie, sistema ou fonte).

## Climas

| Clima | Tela | Mapa | Marca no mapa | Interação de jogo | Evento |
| --- | --- | --- | --- | --- | --- |
| Limpo (`clear`) | nada | reflexos de sol no chão de dia; poças de chuva anterior secando | reflexos de sol | rastros do Radar duram 1,25× | — |
| Sol forte (`strong_sun`) | tom lavado | miragens; asfalto tremendo em faixas presas ao chão | miragem | Ecos de Fogo nascem nas miragens | — |
| Nublado (`cloudy`) | tom cinza | sombras de nuvem andando (antes na tela) | sombra de nuvem | Ecos de Sombra nascem nas sombras (Sombra sem espécie: sem alvo) | — |
| Garoa (`drizzle`) | gotas finas | poças pequenas nas ruas, formando aos poucos | poças pequenas (pixel, três variantes) | poças pequenas dão água pura | — |
| Chuva (`rain`) | chuva, tom azul | poças nas ruas; brilho no chão (antes na tela) | poças em pixel (redonda, comprida, dois lóbulos), da cor do asfalto mais escura e azulada: pontos molhados que crescem em 30 min, reflexo claro de leve, anéis de gota enquanto chove, secam em até 1 h depois | poças dão água pura e fazem nascer Ecos de Água | — |
| Tempestade (`storm`) | chuva inclinada, clarão | raio, marca queimada que fica 30 min; poças | marca queimada | Eco carregado no ponto do raio | — |
| Granizo (`hail`) | pedras quicando | pedrinhas brancas espalhadas no chão | granizo no chão | cristal de gelo coletável (sem o item: água pura) | — |
| Arco-íris (`rainbow`) | arco no céu | pé do arco brilhando; poças secando | pé do arco | material raro e chance de Feérico (Feérico sem espécie: sem alvo) | — |
| Neblina (`fog`) | véu branco nas bordas | vultos parados no chão, longe do jogador (antes na tela) | vultos | visão dos Ecos até 60 m | — |
| Frio (`cold`) | sopro | geada nas áreas do mapa de manhã | geada (pontos brancos de manhã) | rastros duram 2× | — |
| Vento (`wind`) | folhas cruzando | folhas paradas no chão | folhas no chão | Fagulhas derivam com o vento | — |
| Vendaval (`gale`) | lixo voando | galhos e papéis no chão | galhos e papéis | Fagulhas derivam mais; papéis coletáveis viram rumores (rumores: sem alvo) | — |
| Poeira seca (`dry_dust`) | partículas amarelas | redemoinhos andando pela rua | redemoinho e trilha de poeira | Ecos de Terra no caminho (Terra sem espécie: sem alvo) | — |
| Fumaça de queimada (`smoke`) | céu laranja, cinza caindo | zonas de cinza | zona de cinza | Ecos de Fogo nas zonas | INPE quando online: sem alvo |
| Geada forte (`hard_frost`, novo) | tom frio, sopro | chão branco; poças viram gelo | poças congeladas | cristal de gelo em cada poça congelada; passantes fantasmas mais lentos | — |
| Trovoada seca (`dry_thunder`, novo) | céu laranja, clarão, sem chuva | raio e brasa no ponto | brasa por 5 min, depois marca queimada | a brasa solta Fagulhas de Fogo por 5 min; Eco carregado como na Tempestade | — |
| Smog (`smog`, novo) | céu marrom, bordas apagadas | fuligem sobre as avenidas | avenidas escurecidas | zonas de fuligem nas ruas com sucata extra | — |
| Neve (`snow`) | flocos | pó fino, depois a grama, o chão e os telhados (tudo fora das ruas e da água), por último as ruas (caminhos e locais antes das avenidas); derrete ao contrário; pegadas | branco azulado com sombra, montes e textura de pixel; nas ruas, neve suja com trilhas escuras do tráfego | pegadas do jogador e dos Ecos; seguir pegadas leva ao Eco | events.json / debug |
| Nevasca (`blizzard`) | neve de lado, véu | neve acumulando 2× mais rápido | neve nas ruas | visão até 40 m, Aura −2 m | events.json / debug |
| Tempestade de areia (`sandstorm`) | parede de areia | dunas subindo aos poucos sobre parte das ruas; fantasmas mudam de rota quando a duna já subiu | dunas com crista clara e lado sombreado, ondulações de vento, cor de areia, bordas misturadas com a rua | material escondido na duna só aparece a até 15 m (cavar = chegar perto; não há escavação) | events.json / debug |
| Dilúvio (`deluge`) | chuva forte | a água sobe nas ruas baixas em 20 min e escoa em 1 h; carros viram barcos e canoas; passantes só nas calçadas altas | água sobre as ruas baixas; as zonas de água crescem de pontos molhados até o raio | zonas de água com Ecos de Água; tráfego lento | events.json / debug |
| Onda de calor (`heat_wave`) | sol branco | asfalto tremendo em faixas presas ao chão | asfalto tremendo | Fagulhas evaporam em 2 min | events.json / debug |
| Tornado (`tornado`) | tom escuro, folhas | funil andando (o funil saiu da tela) e trilha de destroços | trilha de destroços | destroços coletáveis pela trilha (sucata e ervas); puxar Fagulhas: sem alvo | events.json / debug |
| Aurora (`aurora`) | céu ondulando | faixas verdes e violeta no chão | luz da aurora no chão | tolerância da sintonia 1,25× | NOAA: sem fonte (events.json) |
| Chuva ácida (`acid_rain`) | gotas verdes | poças esverdeadas | poças verdes | sucata extra no Urbano | events.json / debug |
| Chuva de meteoros (`meteor_shower`) | estrelas cadentes | risco termina num impacto: tremor leve, poeira e cratera | cratera que brilha 2 h e some aos poucos em mais 1 h | Fagulhas raras no impacto; material raro na cratera; chance de Dracônico (Dracônico sem espécie: sem alvo) | calendário de chuvas de meteoros |
| Neve do Véu (`veil_snow`) | flocos violeta maiores e densos | brilho onde o floco tocou o chão | brilho do floco | o floco vira Pó de Essência por pouco tempo | — |
| Chuva Carmim (`crimson_rain`) | gotas vermelhas | poças vermelhas | poças vermelhas | poças dão Essência carmesim (`item.essence.crimson`); Carmesins: sem alvo | Lua Carmim: eclipse lunar total visto do centro da região do clima (ver Eclipses) |
| Chuva de Fagulhas (`spark_rain`) | brasas caindo | brasa apagando onde caiu | brasas no chão | Fagulhas caem do céu | Festa Junina |
| Tempestade de Ecos (`echo_storm`) | céu rachado, raios violeta | raio violeta e marca violeta | marca violeta | nível dos Ecos +3; Eco de nível alto no raio; microfendas: sem alvo | Fenda crescendo: sem Fendas |
| Estática (`static`) | glitch, pixels | pixels falhando no chão | pixels no chão | sintonia com ruído, menos ao Tecnomante | NOAA: sem fonte (events.json) |
| Silêncio (`silence`) | cores sem saturação | o tráfego do Véu para no lugar | fantasmas parados (pendente: aguardando vídeo) | Ecos não fogem; Exposição ao Véu: sem alvo | Os Que Escutam (events.json) |
| Cinzas do Véu (`veil_ash`) | cinza violeta caindo | manchas de cinza violeta | manchas de cinza | nas manchas nascem Ecos de nível +1 a +3 (provisório até existir a espécie ou o sistema: no lugar das Corrompidas) | — |
| Procissão na névoa (`fog_procession`) | névoa, vinheta | fila de 12 a 20 figuras encapuzadas (tamanho de passante, túnica clara com contorno escuro, vela com luz fraca na mão) a 0,8 m/s pelas ruas, numa rota pelo grafo costurado até o Eco do fim; visível até 120 m | velas acesas no chão por onde a fila passou, por 30 min, e a trilha até o Eco | visão até 60 m; no fim do rastro nasce um Eco de nível alto (provisório até existir a espécie ou o sistema: Espectral sem espécie) | Finados |
| Vento das Fendas (`rift_wind`) | fiapos violeta | riscos violeta no chão na direção do vento | riscos no chão | Fagulhas derivam; apontar a Fenda: sem Fendas | Fenda crescendo: sem Fendas |
| Céu Invertido (`inverted_sky`) | chuva subindo | sombras de coisas flutuando | sombras flutuando | Fagulhas somem no céu em 3 min | — |
| Maré do Véu (`veil_tide`) | tom violeta leve | o chão ondula (antes na tela); prédios de outra era | prédios translúcidos | prédios dão Ectoplasma (provisório até existir a espécie ou o sistema); spawns antigos: sem alvo | — |
| Sol Negro (`black_sun`) | dia escuro | sombras invertidas (antes na tela), formando em 10 min | sombras claras no chão (enfeite espalhado e as zonas do mundo, agora claras) | sombras dão Ectoplasma (provisório até existir a espécie ou o sistema); Sombra em dobro: sem alvo | eclipse solar visto do centro da região do clima, parcial conta (ver Eclipses) |
| Garoa Prismática (`prismatic_drizzle`) | gotas coloridas | poças com reflexo em cores | poças prismáticas | chance de Brilhante 2× | — |
| Chuva congelante (`freezing_rain`, novo) | gotas brancas | ruas brilhando de gelo; galhos caídos | gelo nas ruas | galhos coletáveis (madeira; sem o item: ervas); carros fantasmas derrapam e andam devagar | events.json / debug |
| Furacão (`hurricane`, novo) | chuva forte | bandas girando em volta do olho; o olho atravessa o mapa | olho e bandas | dentro do olho nasce um Eco raro; tráfego do Véu mais lento | events.json |
| Chuva de Runas (`rune_rain`, novo) | glifos violeta caindo | runas no chão | runas | a runa vira Giz e guarda um bônus (`conjurer.rune_bonus` no save): o próximo ritual aberto revela um espaço ??? | — |
| Lua Dupla (`double_moon`, novo) | segunda lua no céu | sombras duplas: cada Eco pode ter um par só de sombra | par de sombra | chance de variante 2× | lua cheia muito perto da Terra |
| Vigília (`vigil`, novo) | olhos entre as nuvens, satélites | olhares andando pelo chão | olhar no chão | no olhar nasce um Eco de nível alto; Exposição: sem alvo | Os Que Escutam (events.json) |

## Eventos que forçam clima

Ordem: o forçado pelo debug, o `events.json` assinado, o calendário da época 7, os eclipses, a astronomia, o sorteio. O app Céu mostra o motivo (`ClimateOutlook`, `app/lib/world/climate_outlook.dart`).

| Evento | Clima | Fonte | Situação |
| --- | --- | --- | --- |
| Lua Carmim | Chuva Carmim | eclipses lunares totais da época 7 (NASA), vistos do centro da região, e `events.json` | ativo |
| Eclipse real | Sol Negro | eclipses solares da época 7 (NASA), vistos do centro da região | ativo |
| Fenda crescendo | Vento das Fendas, Tempestade de Ecos | — | sem alvo: não há Fendas |
| Chuva de meteoros do calendário | Chuva de meteoros | calendário: Quadrântidas, Líridas, Eta Aquáridas, Perseidas, Oriônidas, Geminídeas, só à noite, por chance | ativo |
| Tempestade geomagnética (NOAA) | Aurora, Estática | `events.json` | sem fonte automática: não há NOAA |
| Finados | Procissão na névoa | calendário, 2 de novembro | ativo |
| Festa Junina | Chuva de Fagulhas | calendário, noites de junho (23 e 24 sempre, as outras por chance) | ativo |
| Temporada de panteão | clima do panteão | — | sem alvo: não há temporadas |
| Os Que Escutam | Silêncio ou Vigília | `events.json` | sem fonte automática |
| Lua cheia muito perto da Terra | Lua Dupla | astronomia: lua ≥ 98,5% cheia a menos de 358 mil km, à noite, por chance | ativo |

## Eclipses

O Sol Negro e a Lua Carmim não têm mais data fixa: valem só onde o eclipse é visível, calculado offline (`app/lib/core/eclipse.dart`) com os elementos da NASA guardados no bloco `climate.eclipses` da época 7 (`epochs.json`). Os elementos moram na época porque a visibilidade decide o clima, e o clima muda o mundo (regra 8).

- **Fontes.** Solares: elementos besselianos (x, y, d, μ, l1, l2, tan f1, tan f2, t0, ΔT) do Five Millennium Canon of Solar Eclipses (Espenak e Meeus, NASA/TP-2006-214141), copiados de https://eclipse.gsfc.nasa.gov/JSEX/SE2001.js. Lunares: Lunar Eclipse Elements (Espenak e Meeus, 2007), com P1, U1, U2, máximo, U3, U4, P4, magnitudes, paralaxe, semidiâmetro e a posição da Lua, de https://eclipse.gsfc.nasa.gov/JLEX/LE2001.js. O cálculo segue os programas da NASA: https://eclipse.gsfc.nasa.gov/JSEX/program.js e https://eclipse.gsfc.nasa.gov/JLEX/program.js.
- **Quais entraram.** Os 22 solares de 2026 a 2035 e os 8 lunares totais (2026-03-03, 2028-12-31, 2029-06-26, 2029-12-20, 2032-04-25, 2032-10-18, 2033-04-14, 2033-10-08). Ficaram fora os 7 lunares parciais e os 8 só penumbrais (a Lua Carmim é só no total). Os de 2026 vêm antes da época 7 e nunca disparam.
- **Solar.** Circunstâncias locais na altitude 0: há eclipse se a magnitude local passa de 0 com o Sol acima do horizonte (altura > -0,3°, o critério da NASA) em algum instante entre o 1º e o 4º contato. Parcial conta. O trecho visível corta no nascer ou no pôr do sol.
- **Lunar.** Visível se a Lua está acima do horizonte (altura topocêntrica ≥ semidiâmetro − 0,5667°) em algum instante entre U1 e U4: a Lua que nasce já na fase parcial conta. A fase só penumbral (P1 a U1, U4 a P4) não conta.
- **Onde.** No centro da região do clima (tile z12, ~10 km), não no ponto do jogador: amigos juntos veem o mesmo, como no sorteio do clima. A janela de 3 h vira Sol Negro ou Chuva Carmim se cruza o trecho visível; a cauda de segundos de um contato também conta.
- **Precisão.** Contra os programas da NASA com os mesmos elementos, o erro é de até 1 s nos instantes e abaixo de 0,001 na magnitude (`app/test/core/eclipse_test.dart`; tolerância do teste: 1 min e 0,005). Os ΔT são os previstos pelo Canon (75 s em 2026, contra ~69 s medidos): ~2 km na faixa, bem menos que a região.
- **Vetores.** 2024-04-08 em Dallas: máximo às 18h42 UT, magnitude 1,056 (total); nada em Campinas. 2027-02-06: parcial em Campinas (máximo 16h22 UT, magnitude 0,825) e em quase todo o Brasil; o limite norte passa em Roraima (Boa Vista vê 0,03, o Monte Caburaí já não); nada em Bogotá; em Luanda o Sol se põe eclipsado. Lunar 2029-06-26 visto de Campinas; 2028-12-31, não (Lua abaixo do horizonte).
- **App Céu.** O motivo traz a hora local (fuso do clima, -3) do máximo visível: "… Máximo às 13h22."

## Decisões

- **Ruas baixas** (Dilúvio): não há relevo no projeto. Cada rua do pacote visual (tile z15 e índice da linha) é baixa se `hash(seed, tile, linha)` cai abaixo da fração da classe: local 65%, secundária 50%, principal 35%, caminho de pedestre 0% (as calçadas altas; na 0.17.0 eram 40, 25 e 15%, e numa tela de 60 m quase nada alagava). Fixas pela seed: as mesmas ruas alagam em todo Dilúvio.
- **Poças**: sem SRTM, os pontos baixos são fixos por célula z17 (`hash(seed, época, célula)`), levados à rua mais próxima pelo mesmo `WalkPaths` dos spawns. Crescem em 30 min de chuva, duram enquanto chove e secam na hora seguinte.
- **Neve**: o pacote visual não tem prédios, então "telhado" é tudo que não é rua nem água. A neve cobre primeiro a grama (áreas verdes), depois o chão e os telhados, e só então as ruas: caminhos e locais antes das secundárias e das principais. Nas avenidas ficam duas trilhas escuras do tráfego; nas locais, uma no meio.
- **Dunas**: dentro da rua sorteada, o trecho da duna cresce do meio para as pontas; os fantasmas só desviam depois de a duna passar de 30%. Frações: caminho e local 40%, secundária 30%, principal 20%.
- Por janela de 3 h, as dunas mudam de rua.
- **Barcos**: carro fantasma em rua baixa alagada vira barco (moto vira canoa); passante não nasce nem entra em rua alagada.
- Cobertura das ruas, barcos, dunas e decoração do chão são só desenho (`clima.json`). Poças, crateras, brasas, olhares, runas e zonas são do mundo (época 7).

## Formação no tempo (0.17.1)

Nada aparece pronto (`app/lib/world/climate_form.dart`). O estado de cada marca é função do tempo desde o começo do clima no lugar (`PlayerClimate.runStartUtc`, o começo da primeira das janelas seguidas com ele) e, depois que ele acaba, desde o fim (`prevEndUtc`, com o clima de antes em `prevId`). Os dois instantes saem do mundo (seed, região e janela): dois aparelhos juntos veem a mesma fase. Os tempos são só desenho, em `clima.json`: `grow_s` e `fade_s` em cada camada `ground` (padrão 15 min e 30 min) e em cada peça desenhada como zona (padrão 20 s).

| Marca | Forma em | Some em | Como |
| --- | --- | --- | --- |
| Poças (Chuva, Garoa, Carmim, ácida, Prismática) | 30 min (época 7, `grow_s` da peça) | até 1 h (`dry_s`) | pontos molhados que se juntam e crescem; secando, encolhem |
| Neve e Nevasca | 1 h e 30 min | 1 h | pó (camada `scatter`, 10 e 5 min), grama, chão e telhados, ruas; derrete ao contrário |
| Dunas | 30 min | 40 min | o trecho cresce do meio, a duna sobe |
| Água do Dilúvio | 20 min (ruas), 15 min (zonas) | 1 h (ruas), 15 min (zonas) | a água sobe de borda a borda; zonas de pontos molhados ao raio |
| Gelo nas ruas (Chuva congelante) | 20 min | 45 min | o brilho cobre a rua aos poucos |
| Fuligem (Smog) | 30 min (ruas), 10 min (zonas) | 45 min e 10 min | as avenidas escurecem |
| Geada (Frio, Geada forte) | 30 e 20 min | 30 e 40 min | pontos brancos aparecendo |
| Cinzas (Fumaça, Cinzas do Véu) | 20 min (enfeite), 10 min (zonas) | 40 min e 10 min | manchas aparecendo |
| Sombras do Sol Negro | 10 min (enfeite), 5 min (zonas) | 15 min e 5 min | sombras claras aparecendo |
| Brasas e marcas de raio | já eram no tempo (`glow_s`, `mark_s`) | — | brasa acesa, depois marca queimada que some |

No debug, o clima forçado começa do zero no instante em que é forçado; trocar de clima forçado deixa o anterior secando. "Velocidade do clima" (1×, 10×, 60×; Tempo e mundo) acelera só a formação do clima forçado, neste aparelho (`DebugForce.phase`). O mundo de quem não força nada não muda: a impressão digital do que nasce (Finados de 2027 e uma semana de janeiro) é a mesma da 0.17.0 (`test/world/climate_form_test.dart`).

**Simulação de clima** (debug, Tempo e mundo): passa por todos os climas do `clima.json`, cada um do zero por um tempo configurável (1, 2 ou 5 min de parede; padrão 2 min a 60×). Em cada passo, o clima forma nos primeiros três quartos e no último acaba (vira Limpo) e o que deixou no chão seca. A zona de avisos mostra "SIMULAÇÃO n/N · CLIMA · FASE · 60X". Dá para pular para qualquer clima e repetir o atual. Ligada, nada do que se pega dá recompensa (`DevTools.sandboxed`), como o GPS simulado sem recompensa.

## Procissão (0.17.1)

- **Por que sumia.** Três coisas juntas: (1) a camada do mapa só lia as zonas das células z17 (~290 m) a até um raio da tela (~60 m em volta), e a Procissão anda ~900 m a partir da célula onde nasce, então quase sempre estava fora da leitura quando passava pela tela; (2) cada célula tem uma Procissão de 20 min por janela de 3 h, então forçar o clima no debug caía, em ~9 de cada 10 vezes, num momento sem nenhuma perto; (3) as figuras eram retângulos `#3a3350` com 50% de opacidade, quase invisíveis no mapa escuro e atrás do véu claro da névoa.
- **Agora.** A leitura do desenho procura as zonas que andam a até 1,1 km e as mantém por 31 min depois do fim (as velas), sem mudar o que o mundo faz nascer. A rota é a do grafo de ruas costurado (`stitch`, o mesmo do Modo Viagem), a pé, do ponto onde a zona nasce até o ponto de rua mais perto de onde nasce o Eco do fim (`app/lib/world/procession.dart`). A frente da fila anda a 0,8 m/s e chega ao fim no instante em que o Eco aparece; se a rota é mais longa que o caminho a 0,8 m/s, a fila sai da névoa já no meio dela. Sem rua perto, a fila anda na reta da zona, como antes. Números no bloco `procession` do `clima.json`.
- **Épocas até a 7.** O Eco do fim continua no ponto da reta (às vezes fora da rua: a trilha de velas vai do fim da rota até ele) e só existe até o fim da zona (60 s depois de aparecer: o `ttl_s` de 20 min do dado nunca valeu para zonas).
- **Época 8 (parâmetro para quem monta a época).** `"street_route": true` na peça `procession` do clima `fog_procession`: o Eco do fim nasce no ponto de rua mais perto do fim (o fim da rota e das velas) e fica `spawn.ttl_s` depois de aparecer, mesmo com a zona acabada.

## Efeitos sem alvo

Espécies Elétrica, Terra, Sombra, Espectral, Feérica, Luz, Metal, Digital, Dracônica, Carmesim e Antiga; rumores do fórum; Exposição ao Véu; microfendas; Fendas; Corrompidas; escavação; INPE; NOAA; temporadas de panteão; puxar Fagulhas no tornado.
