# Auditoria do clima (0.17.0)

Base: `docs/GDD.md`, "Tempo, astronomia e clima" (rev 328), o `assets/data/clima.json` e o bloco `climate` da época 6 em `assets/data/epochs.json`. Cada clima tem duas camadas:

- **Tela** (`clima.json`, `layers`): só o que cai do céu ou cobre a vista. Não gira nem dá zoom com o mapa.
- **Mapa** (`clima.json`, `ground`, e as peças do bloco `climate` da época): tudo que está no chão. Desenhado em células z21, com a transformação da câmera (gira, move, dá zoom), em posições que saem da seed, da célula e da janela, iguais em dois aparelhos.

O que muda o mundo (onde algo nasce, o que nasce, quanto dura a coleta) fica na época 7. O que é só desenho (cobertura das ruas, barcos, decoração espalhada pelo chão) fica no `clima.json` e pode mudar sem época nova; mesmo assim sai de hash da seed e da posição, para amigos juntos verem o mesmo.

"Proposta" marca o que o GDD não define e foi escolhido aqui, para revisão. "Sem alvo" marca o efeito que o dado declara, mas que ainda não existe no jogo (espécie, sistema ou fonte).

## Climas

| Clima | Tela | Mapa | Marca no mapa | Interação de jogo | Evento |
| --- | --- | --- | --- | --- | --- |
| Limpo (`clear`) | nada | reflexos de sol no chão de dia; poças de chuva anterior secando | reflexos de sol (proposta) | rastros do Radar duram 1,25× (proposta) | — |
| Sol forte (`strong_sun`) | tom lavado | miragens; asfalto tremendo em faixas presas ao chão | miragem | Ecos de Fogo nascem nas miragens | — |
| Nublado (`cloudy`) | tom cinza | sombras de nuvem andando (antes na tela) | sombra de nuvem | Ecos de Sombra nascem nas sombras (Sombra sem espécie: sem alvo) | — |
| Garoa (`drizzle`) | gotas finas | poças pequenas nas ruas | poças pequenas (proposta) | poças pequenas dão água pura (proposta) | — |
| Chuva (`rain`) | chuva, tom azul | poças nas ruas; brilho no chão (antes na tela) | poças que crescem, refletem o céu e secam em até 1 h depois | poças dão água pura e fazem nascer Ecos de Água | — |
| Tempestade (`storm`) | chuva inclinada, clarão | raio, marca queimada que fica 30 min; poças | marca queimada | Eco carregado no ponto do raio | — |
| Granizo (`hail`) | pedras quicando | pedrinhas brancas espalhadas no chão | granizo no chão (proposta) | cristal de gelo coletável (sem o item: água pura) | — |
| Arco-íris (`rainbow`) | arco no céu | pé do arco brilhando; poças secando | pé do arco | material raro e chance de Feérico (Feérico sem espécie: sem alvo) | — |
| Neblina (`fog`) | véu branco nas bordas | vultos parados no chão, longe do jogador (antes na tela) | vultos | visão dos Ecos até 60 m | — |
| Frio (`cold`) | sopro | geada nas áreas do mapa de manhã | geada (proposta: pontos brancos de manhã) | rastros duram 2× | — |
| Vento (`wind`) | folhas cruzando | folhas paradas no chão | folhas no chão (proposta) | Fagulhas derivam com o vento | — |
| Vendaval (`gale`) | lixo voando | galhos e papéis no chão | galhos e papéis (proposta) | Fagulhas derivam mais; papéis coletáveis viram rumores (rumores: sem alvo) | — |
| Poeira seca (`dry_dust`) | partículas amarelas | redemoinhos andando pela rua | redemoinho e trilha de poeira | Ecos de Terra no caminho (Terra sem espécie: sem alvo) | — |
| Fumaça de queimada (`smoke`) | céu laranja, cinza caindo | zonas de cinza | zona de cinza | Ecos de Fogo nas zonas | INPE quando online: sem alvo |
| Geada forte (`hard_frost`, novo) | tom frio, sopro | chão branco; poças viram gelo | poças congeladas | cristal de gelo em cada poça congelada; passantes fantasmas mais lentos | — |
| Trovoada seca (`dry_thunder`, novo) | céu laranja, clarão, sem chuva | raio e brasa no ponto | brasa por 5 min, depois marca queimada | a brasa solta Fagulhas de Fogo por 5 min; Eco carregado como na Tempestade (proposta) | — |
| Smog (`smog`, novo) | céu marrom, bordas apagadas | fuligem sobre as avenidas | avenidas escurecidas | zonas de fuligem nas ruas com sucata extra | — |
| Neve (`snow`) | flocos | neve acumulando primeiro nas ruas pouco usadas; trilhas do tráfego nas avenidas; pegadas | neve nas ruas e pegadas | pegadas do jogador e dos Ecos; seguir pegadas leva ao Eco | events.json / debug |
| Nevasca (`blizzard`) | neve de lado, véu | neve acumulando 2× mais rápido | neve nas ruas (proposta) | visão até 40 m, Aura −2 m | events.json / debug |
| Tempestade de areia (`sandstorm`) | parede de areia | dunas cobrindo parte das ruas; fantasmas mudam de rota | dunas | material escondido na duna só aparece a até 15 m (cavar = chegar perto, proposta; não há escavação) | events.json / debug |
| Dilúvio (`deluge`) | chuva forte | ruas baixas alagadas; carros viram barcos e canoas; passantes só nas calçadas altas | água sobre as ruas baixas | zonas de água com Ecos de Água; tráfego lento | events.json / debug |
| Onda de calor (`heat_wave`) | sol branco | asfalto tremendo em faixas presas ao chão | asfalto tremendo | Fagulhas evaporam em 2 min | events.json / debug |
| Tornado (`tornado`) | tom escuro, folhas | funil andando (o funil saiu da tela) e trilha de destroços | trilha de destroços | destroços coletáveis pela trilha (sucata e ervas); puxar Fagulhas: sem alvo | events.json / debug |
| Aurora (`aurora`) | céu ondulando | faixas verdes e violeta no chão | luz da aurora no chão (proposta) | tolerância da sintonia 1,25× | NOAA: sem fonte (events.json) |
| Chuva ácida (`acid_rain`) | gotas verdes | poças esverdeadas | poças verdes (proposta) | sucata extra no Urbano | events.json / debug |
| Chuva de meteoros (`meteor_shower`) | estrelas cadentes | risco termina num impacto: tremor leve, poeira e cratera | cratera que brilha 2 h e some aos poucos em mais 1 h | Fagulhas raras no impacto; material raro na cratera; chance de Dracônico (Dracônico sem espécie: sem alvo) | calendário de chuvas de meteoros |
| Neve do Véu (`veil_snow`) | flocos violeta maiores e densos | brilho onde o floco tocou o chão | brilho do floco (proposta) | o floco vira Pó de Essência por pouco tempo | — |
| Chuva Carmim (`crimson_rain`) | gotas vermelhas | poças vermelhas | poças vermelhas | poças dão Pó de Essência de Fogo (proposta); Carmesins: sem alvo | Lua Carmim (proposta: eclipse lunar total; datas a conferir) |
| Chuva de Fagulhas (`spark_rain`) | brasas caindo | brasa apagando onde caiu | brasas no chão (proposta) | Fagulhas caem do céu | Festa Junina |
| Tempestade de Ecos (`echo_storm`) | céu rachado, raios violeta | raio violeta e marca violeta | marca violeta | nível dos Ecos +3; Eco de nível alto no raio; microfendas: sem alvo | Fenda crescendo: sem Fendas |
| Estática (`static`) | glitch, pixels | pixels falhando no chão | pixels no chão (proposta) | sintonia com ruído, menos ao Tecnomante | NOAA: sem fonte (events.json) |
| Silêncio (`silence`) | cores sem saturação | o tráfego do Véu para no lugar | fantasmas parados (proposta) | Ecos não fogem; Exposição ao Véu: sem alvo | Os Que Escutam (events.json) |
| Cinzas do Véu (`veil_ash`) | cinza violeta caindo | manchas de cinza violeta | manchas de cinza (proposta) | nas manchas nascem Ecos de nível +1 a +3 (proposta, no lugar das Corrompidas: sem alvo) | — |
| Procissão na névoa (`fog_procession`) | névoa, vinheta | figuras em fila andando pelo chão (antes na tela) | figuras e o rastro delas | visão até 60 m; no fim do rastro nasce um Eco de nível alto (proposta; Espectral sem espécie) | Finados |
| Vento das Fendas (`rift_wind`) | fiapos violeta | riscos violeta no chão na direção do vento | riscos no chão (proposta) | Fagulhas derivam; apontar a Fenda: sem Fendas | Fenda crescendo: sem Fendas |
| Céu Invertido (`inverted_sky`) | chuva subindo | sombras de coisas flutuando | sombras flutuando (proposta) | Fagulhas somem no céu em 3 min | — |
| Maré do Véu (`veil_tide`) | tom violeta leve | o chão ondula (antes na tela); prédios de outra era | prédios translúcidos | prédios dão Ectoplasma (proposta); spawns antigos: sem alvo | — |
| Sol Negro (`black_sun`) | dia escuro | sombras invertidas (antes na tela) | sombras claras no chão | sombras dão Ectoplasma (proposta); Sombra em dobro: sem alvo | eclipse solar (datas a conferir) |
| Garoa Prismática (`prismatic_drizzle`) | gotas coloridas | poças com reflexo em cores | poças prismáticas (proposta) | chance de Brilhante 2× | — |
| Chuva congelante (`freezing_rain`, novo) | gotas brancas | ruas brilhando de gelo; galhos caídos | gelo nas ruas | galhos coletáveis (madeira; sem o item: ervas); carros fantasmas derrapam e andam devagar | events.json / debug |
| Furacão (`hurricane`, novo) | chuva forte | bandas girando em volta do olho; o olho atravessa o mapa | olho e bandas | dentro do olho nasce um Eco raro; tráfego do Véu mais lento (proposta) | events.json |
| Chuva de Runas (`rune_rain`, novo) | glifos violeta caindo | runas no chão | runas | a runa vira Giz (proposta); bônus no próximo ritual: sem alvo (pede campo no save) | — |
| Lua Dupla (`double_moon`, novo) | segunda lua no céu | sombras duplas: cada Eco pode ter um par só de sombra | par de sombra | chance de variante 2× | lua cheia muito perto da Terra |
| Vigília (`vigil`, novo) | olhos entre as nuvens, satélites | olhares andando pelo chão | olhar no chão | no olhar nasce um Eco de nível alto; Exposição: sem alvo | Os Que Escutam (events.json) |

## Eventos que forçam clima

Ordem: o forçado pelo debug, o `events.json` assinado, o calendário da época 7, a astronomia, o sorteio. O app Céu mostra o motivo (`ClimateOutlook`, `app/lib/world/climate_outlook.dart`).

| Evento | Clima | Fonte | Situação |
| --- | --- | --- | --- |
| Lua Carmim | Chuva Carmim | calendário (proposta: noites de eclipse lunar total) e `events.json` | datas a conferir |
| Eclipse real | Sol Negro | calendário com datas UTC de eclipses solares vistos do Brasil | datas a conferir |
| Fenda crescendo | Vento das Fendas, Tempestade de Ecos | — | sem alvo: não há Fendas |
| Chuva de meteoros do calendário | Chuva de meteoros | calendário: Quadrântidas, Líridas, Eta Aquáridas, Perseidas, Oriônidas, Geminídeas, só à noite, por chance | ativo |
| Tempestade geomagnética (NOAA) | Aurora, Estática | `events.json` | sem fonte automática: não há NOAA |
| Finados | Procissão na névoa | calendário, 2 de novembro | ativo |
| Festa Junina | Chuva de Fagulhas | calendário, noites de junho (23 e 24 sempre, as outras por chance) | ativo |
| Temporada de panteão | clima do panteão | — | sem alvo: não há temporadas |
| Os Que Escutam | Silêncio ou Vigília | `events.json` | sem fonte automática |
| Lua cheia muito perto da Terra | Lua Dupla | astronomia: lua ≥ 98,5% cheia a menos de 358 mil km, à noite, por chance | ativo |

## Decisões

- **Ruas baixas** (Dilúvio): não há relevo no projeto. Cada rua do pacote visual (tile z15 e índice da linha) é baixa se `hash(seed, tile, linha)` cai abaixo da fração da classe: local 40%, secundária 25%, principal 15%, caminho de pedestre 0% (as calçadas altas). Fixas pela seed: as mesmas ruas alagam em todo Dilúvio.
- **Poças**: sem SRTM, os pontos baixos são fixos por célula z17 (`hash(seed, época, célula)`), levados à rua mais próxima pelo mesmo `WalkPaths` dos spawns. Crescem em 30 min de chuva, duram enquanto chove e secam na hora seguinte.
- **Neve nas ruas**: cobre primeiro os caminhos e as ruas locais, depois as secundárias, por último as principais, onde ficam duas trilhas escuras do tráfego.
- **Dunas**: por janela de 3 h, um trecho de parte das ruas; os fantasmas não entram em rua com duna.
- **Barcos**: carro fantasma em rua baixa alagada vira barco (moto vira canoa); passante não nasce nem entra em rua alagada.
- Cobertura das ruas, barcos, dunas e decoração do chão são só desenho (`clima.json`). Poças, crateras, brasas, olhares, runas e zonas são do mundo (época 7).

## Efeitos sem alvo

Espécies Elétrica, Terra, Sombra, Espectral, Feérica, Luz, Metal, Digital, Dracônica, Carmesim e Antiga; rumores do fórum; Exposição ao Véu; microfendas; Fendas; Corrompidas; escavação; bônus de ritual da runa; INPE; NOAA; temporadas de panteão; puxar Fagulhas no tornado.
