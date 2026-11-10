# Auditoria do clima (0.17.1)

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
| Garoa (`drizzle`) | gotas finas | poças pequenas nas ruas | poças pequenas | poças pequenas dão água pura | — |
| Chuva (`rain`) | chuva, tom azul | poças nas ruas; brilho no chão (antes na tela) | poças que crescem, refletem o céu e secam em até 1 h depois | poças dão água pura e fazem nascer Ecos de Água | — |
| Tempestade (`storm`) | chuva inclinada, clarão | raio, marca queimada que fica 30 min; poças | marca queimada | Eco carregado no ponto do raio, sem aviso (só a faísca em volta dele no mapa) | — |
| Granizo (`hail`) | pedras quicando | pedrinhas brancas espalhadas no chão | granizo no chão | cristal de gelo coletável (época 8; até a 7, água pura) | — |
| Arco-íris (`rainbow`) | só um tom claro (o arco saiu da tela) | da época 8: o arco de pé num ponto do mapa, girando com ele, e o pé brilhando | pé do arco | Fragmento de luz no pé e chance de Feérico (Feérico sem espécie: sem alvo); o Prisma de orvalho aponta o pé | depois da chuva, por sorteio (ver Arco-íris) |
| Neblina (`fog`) | véu branco nas bordas | vultos parados no chão, longe do jogador (antes na tela) | vultos | visão dos Ecos até 60 m | — |
| Frio (`cold`) | sopro | geada nas áreas do mapa de manhã | geada (pontos brancos de manhã) | rastros duram 2× | — |
| Vento (`wind`) | folhas cruzando | folhas paradas no chão | folhas no chão | Fagulhas derivam com o vento | — |
| Vendaval (`gale`) | lixo voando | galhos e papéis no chão | galhos e papéis | Fagulhas derivam mais; papéis coletáveis viram rumores (rumores: sem alvo) | — |
| Poeira seca (`dry_dust`) | partículas amarelas | redemoinhos andando pela rua | redemoinho e trilha de poeira | Ecos de Terra no caminho (Terra sem espécie: sem alvo) | — |
| Fumaça de queimada (`smoke`) | céu laranja, cinza caindo | zonas de cinza | zona de cinza | Ecos de Fogo nas zonas | INPE quando online: sem alvo |
| Geada forte (`hard_frost`, novo) | tom frio, sopro | chão branco; poças viram gelo | poças congeladas | cristal de gelo em cada poça congelada; passantes fantasmas mais lentos | — |
| Trovoada seca (`dry_thunder`, novo) | céu laranja, clarão, sem chuva | raio e brasa no ponto | brasa por 5 min, depois marca queimada | a brasa solta Fagulhas de Fogo por 5 min; Eco carregado como na Tempestade | — |
| Smog (`smog`, novo) | céu marrom, bordas apagadas | fuligem sobre as avenidas | avenidas escurecidas | zonas de fuligem nas ruas com sucata extra | — |
| Neve (`snow`) | flocos | neve acumulando primeiro nas ruas pouco usadas; trilhas do tráfego nas avenidas; pegadas | neve nas ruas e pegadas | pegadas do jogador e dos Ecos; seguir pegadas leva ao Eco | events.json / debug |
| Nevasca (`blizzard`) | neve de lado, véu | neve acumulando 2× mais rápido | neve nas ruas | visão até 40 m, Aura −2 m | events.json / debug |
| Tempestade de areia (`sandstorm`) | parede de areia | dunas cobrindo parte das ruas; fantasmas mudam de rota | dunas | material escondido na duna só aparece a até 15 m (cavar = chegar perto; não há escavação) | events.json / debug |
| Dilúvio (`deluge`) | chuva forte | ruas baixas alagadas; carros viram barcos e canoas; passantes só nas calçadas altas | água sobre as ruas baixas | zonas de água com Ecos de Água; tráfego lento | events.json / debug |
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
| Procissão na névoa (`fog_procession`) | névoa, vinheta | figuras em fila andando pelo chão (antes na tela) | figuras e o rastro delas | visão até 60 m; no fim do rastro nasce um Eco de nível alto (provisório até existir a espécie ou o sistema: Espectral sem espécie) | Finados |
| Vento das Fendas (`rift_wind`) | fiapos violeta | riscos violeta no chão na direção do vento | riscos no chão | Fagulhas derivam; apontar a Fenda: sem Fendas | Fenda crescendo: sem Fendas |
| Céu Invertido (`inverted_sky`) | chuva subindo | sombras de coisas flutuando | sombras flutuando | Fagulhas somem no céu em 3 min | — |
| Maré do Véu (`veil_tide`) | tom violeta leve | o chão ondula (antes na tela); prédios de outra era | prédios translúcidos | prédios dão Ectoplasma (provisório até existir a espécie ou o sistema); spawns antigos: sem alvo | — |
| Sol Negro (`black_sun`) | dia escuro | sombras invertidas (antes na tela) | sombras claras no chão | sombras dão Ectoplasma (provisório até existir a espécie ou o sistema); Sombra em dobro: sem alvo | eclipse solar visto do centro da região do clima, parcial conta (ver Eclipses) |
| Garoa Prismática (`prismatic_drizzle`) | gotas coloridas | poças com reflexo em cores | poças prismáticas | chance de Brilhante 2× | — |
| Chuva congelante (`freezing_rain`, novo) | gotas brancas | ruas brilhando de gelo; galhos caídos | gelo nas ruas | galhos coletáveis (madeira; sem o item: ervas); carros fantasmas derrapam e andam devagar | events.json / debug |
| Furacão (`hurricane`, novo) | chuva forte | bandas girando em volta do olho; o olho atravessa o mapa | olho e bandas | dentro do olho nasce um Eco raro; tráfego do Véu mais lento | events.json |
| Chuva de Runas (`rune_rain`, novo) | glifos violeta caindo | runas no chão | runas | a runa vira Giz e guarda um bônus (`conjurer.rune_bonus` no save): o próximo ritual aberto revela um espaço ??? | — |
| Lua Dupla (`double_moon`, novo) | segunda lua no céu | sombras duplas: cada Eco pode ter um par só de sombra | par de sombra | chance de variante 2× | lua cheia muito perto da Terra |
| Vigília (`vigil`, novo) | olhos entre as nuvens, satélites | olhares andando pelo chão | olhar no chão | no olhar nasce um Eco de nível alto; Exposição: sem alvo | Os Que Escutam (events.json) |

## Eventos que forçam clima

Ordem: o forçado pelo debug, o `events.json` assinado, o calendário da época (7: datas fixas; 8: mais o calendário do Véu), os eclipses, a astronomia, o sorteio. O app Céu mostra o motivo (`ClimateOutlook`, `app/lib/world/climate_outlook.dart`).

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

## Calendário do Véu (época 8)

O sorteio e o clima real só trazem os nativos. O calendário do Véu do GDD (rev 333) traz cada clima de outra região e cada místico ao menos uma vez por ano. Mora no bloco `climate.calendar` da época 8 (`epochs.json`), na ordem abaixo: a primeira regra que bate ganha. Tudo pela hora local do meio da janela de 3 h (fuso fixo -3) e pela seed, sem a região: a cidade inteira vê o mesmo. Código: `app/lib/core/veil_calendar.dart`; datas móveis em `app/lib/core/astro.dart`.

| Evento (`id`) | Quando | Clima |
| --- | --- | --- |
| Ano-Novo (`ano_novo`) | 1º de janeiro, o dia todo | Chuva de Fagulhas |
| Carnaval do Véu (`carnaval`) | segunda e terça de Carnaval (Páscoa − 48 e − 47) | Garoa Prismática |
| Cinzas (`cinzas`) | Quarta-feira de Cinzas (Páscoa − 46) | Cinzas do Véu |
| Dia do Avesso (`dia_do_avesso`) | 1º de abril | Céu Invertido |
| Noite das Runas (`runas_marco`, `runas_setembro`) | data local dos equinócios, das 18h à meia-noite | Chuva de Runas |
| Noite Branca (`noite_branca`) | data local do solstício de junho (inverno do sul), das 18h à meia-noite | Neve do Véu |
| Maré da Cidade (`mare_da_cidade`) | 14 de julho, aniversário de Campinas | Maré do Véu |
| Sexta dos Olhos (`sexta_dos_olhos`) | toda sexta-feira 13 | Vigília |
| Noite Calada (`noite_calada`) | 31 de outubro, das 18h à meia-noite | Silêncio |
| (da época 7) | Finados, São João, Festa Junina, chuvas de meteoros | como na época 7 |
| Águas do Véu (`aguas_do_veu`) | fevereiro e março: 3 dias de Dilúvio e 1 de Furacão | Dilúvio, Furacão |
| Semana da Fuligem (`semana_fuligem`) | maio: 7 dias seguidos, Chuva ácida e Smog alternados pela seed | Chuva ácida, Smog |
| Inverno do Véu (`inverno_do_veu`) | julho: 2 dias de Neve, 1 de Nevasca, 1 de Chuva congelante | Neve, Nevasca, Chuva congelante |
| Estação Seca do Véu (`estacao_seca`) | agosto e setembro: 2 dias de Tempestade de areia, 2 de Onda de calor, 1 de Tornado | Tempestade de areia, Onda de calor, Tornado |
| Noite Boreal (`noite_boreal`) | dezembro: 2 noites de Aurora e 1 de Estática, das 18h à meia-noite | Aurora, Estática |

- **Períodos.** Uma regra com `climates` escolhe, por ano, um dia do período para cada clima da lista (a lista repete o clima para dar mais dias; `consecutive`: dias seguidos). A escolha sai de `hash(seed, ano, id)`: todo clima da lista aparece no ano, o dia muda de ano para ano e é o mesmo em todo aparelho. Os dias de uma regra anterior (Carnaval, Cinzas, 14 de julho, sextas-feiras 13, as noites de meteoros) não entram na escolha, para nenhum período perder o dia dele.
- **Datas móveis.** Páscoa pelo algoritmo de Meeus/Jones/Butcher. Equinócios e solstícios pelo cap. 27 de Meeus (termos periódicos da tabela 27.C, ΔT de 69 s): erro de cerca de 1 min contra o USNO (teste: 2024 a 2026, tolerância 3 min). A data é a local: o equinócio de 23/09/2026 às 00h05 UTC cai no dia 22 em Campinas.
- **Feed.** O `events.json` assinado continua passando na frente (`kind: climate`). Para mudar uma data, `kind: calendar_skip` com o `event` desliga a regra no período e um `climate` manda o clima na data nova. A 0.17.0 ignora o `calendar_skip`.
- **App Céu.** Mostra o próximo evento do calendário (nome, clima, dia e hora locais), sem contar o que já está valendo.
- **Sem data no calendário.** Sol Negro e Chuva Carmim (eclipses), Vento das Fendas e Tempestade de Ecos (Fendas) e Lua Dupla (lua cheia no perigeu) continuam só pelo evento deles, como no GDD: não aparecem todo ano. Pendente: revisão (se devem ganhar data no calendário).
- **Teste.** `app/test/core/veil_calendar_test.dart` varre 2030, 2031 e 2033 com três seeds: os 22 outros climas de outra região e místicos aparecem todos.

## Arco-íris (época 8)

- **Quando.** Não sai mais do sorteio da estação (os pesos de `rainbow` e a regra `after` saíram da época 8). Na primeira janela de 3 h sem chuva depois de uma com chuva (`rain`, `storm`, `drizzle`, `hail`), na região do clima (tile z12), nasce um arco com 25% de chance, no começo da janela, e dura de 20 a 40 min. Sorteio por `hash(seed, época, região, janela)`. Com o clima Arco-íris forçado (feed ou debug), vale a janela inteira.
- **Onde.** O pé fica num ponto da seed a até 400 m do centro da região, levado à rua mais próxima (até 35 m; tenta 8 pontos). É fixo enquanto o arco dura. Os números ficam na peça `rainbow` do clima `rainbow` da época 8 (`chance`, `duration_s`, `within_m`, `after`, `radius_m`): decidem o mundo, então não estão no `balance.json`.
- **Desenho.** Objeto do mapa (`app/lib/ui/game/rainbow_painter.dart`), entre o chão e os spawns: a base vai de um pé ao outro na direção da seed, gira e dá zoom com o mapa, e a altura sobe na tela. Aparece em 90 s e some nos últimos 5 min. Raio, faixas, cores e esmaecer no `clima.json` (`rainbow_arc`), só desenho. A camada de tela `arc` saiu.
- **Pé.** Uma zona de 8 m enquanto o arco dura: Fragmento de luz (`item.prism_shard`) e 30% de Feérico (sem espécie: sem alvo).
- **Prisma de orvalho** (`item.dew_prism`). Bancada: 2 Água pura, 1 Fragmento de luz e 1 Cristal de gelo (`recipe.dew_prism`). No app Céu, "Usar Prisma de orvalho" mostra a distância e o rumo até o pé do arco ativo mais perto (até `prism_search_m`, 6 km, no `balance.json`) e gasta o prisma; sem arco ativo, não gasta. Código: `app/lib/world/dew_prism.dart`.
- **Itens novos.** Cristal de gelo (`item.ice_crystal`: granizo e poças da Geada forte) e Fragmento de luz (`item.prism_shard`: pé do arco e, na época 8, as miragens do Sol forte, 25%). Os dois têm `since_epoch: 8` no `items.json`: nas épocas 6 e 7 as peças continuam com o fallback de antes (água pura, Ectoplasma), e o que essas épocas geram não muda.
- **Debug.** "Efeito do clima no toque" > Arco-íris solta um arco com o pé no ponto tocado; "Ir até o pé do arco-íris" teleporta o GPS simulado até o pé ativo mais perto.

## Raio do debug e céu do HUD

- **Raio aqui** (debug, Tempo e mundo): o próximo toque no mapa faz o raio cair ali, com traço, clarão, trovão, poeira, marca queimada e o Eco carregado. O raio do debug anima mesmo a menos de `strike_min_player_m` do jogador e mesmo tocado no fim de um segundo.
- **Eco carregado.** Sem aviso nenhum (o toast saiu, e não há notificação nem Chat): ele aparece no mapa com a faísca ciano em volta.
- **Céu do HUD.** A lua e a segunda lua da Lua Dupla e o Sol Negro moram na faixa logo abaixo dos avisos (`HudLayout.sky`, `app/lib/ui/game/hud_layout.dart`), fora de todas as zonas; o teste de layout confere em 360×800, 412×915 e 480×1000 dp. O arco-íris é do mapa e fica por baixo do HUD, como os Ecos.

## Decisões

- **Ruas baixas** (Dilúvio): não há relevo no projeto. Cada rua do pacote visual (tile z15 e índice da linha) é baixa se `hash(seed, tile, linha)` cai abaixo da fração da classe: local 40%, secundária 25%, principal 15%, caminho de pedestre 0% (as calçadas altas). Fixas pela seed: as mesmas ruas alagam em todo Dilúvio.
- **Poças**: sem SRTM, os pontos baixos são fixos por célula z17 (`hash(seed, época, célula)`), levados à rua mais próxima pelo mesmo `WalkPaths` dos spawns. Crescem em 30 min de chuva, duram enquanto chove e secam na hora seguinte.
- **Neve nas ruas**: cobre primeiro os caminhos e as ruas locais, depois as secundárias, por último as principais, onde ficam duas trilhas escuras do tráfego.
- **Dunas**: por janela de 3 h, um trecho de parte das ruas; os fantasmas não entram em rua com duna.
- **Barcos**: carro fantasma em rua baixa alagada vira barco (moto vira canoa); passante não nasce nem entra em rua alagada.
- Cobertura das ruas, barcos, dunas e decoração do chão são só desenho (`clima.json`). Poças, crateras, brasas, olhares, runas e zonas são do mundo (época 7).

## Efeitos sem alvo

Espécies Elétrica, Terra, Sombra, Espectral, Feérica, Luz, Metal, Digital, Dracônica, Carmesim e Antiga; rumores do fórum; Exposição ao Véu; microfendas; Fendas; Corrompidas; escavação; INPE; NOAA; temporadas de panteão; puxar Fagulhas no tornado.
