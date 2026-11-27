# Checklist do celular

O que precisa ser conferido no moto g54 quando a versão for instalada nele. É cumulativo: cobre tudo desde a última versão
que está no celular (hoje a **0.25.0**, release instalada em 2026-11-18 por cima da 0.24.3, com o save mantido, e depois uma build de profile da medição da 0.25.1; a 0.25.1 não chegou a ser instalada; a 0.24.3 tinha entrado em 2026-11-17 por cima da 0.24.1, com o save mantido; a 0.24.2 nunca foi para o celular, então os itens dela continuam; a 0.24.1 tinha entrado por cima da 0.24.0 (e esta da 0.23.2, e esta da 0.23.1, e esta da 0.23.0, que entrou por cima da 0.22.1), com o save mantido; a 0.22.2 nunca foi para o celular, então os itens dela continuam; continuam as pendências desde a 0.20.0), e cada versão nova acrescenta os itens
dela. **Um item só sai daqui quando o relatório confirmar que passou.** A ordem vai da versão mais nova para a mais antiga;
as pendências antigas ficam no fim. O código entre crases é o id do item (o workbench guarda as notas por ele: não mude).

Antes de qualquer captura: tela de bloqueio desligada (`isKeyguardShowing=false`) e o Kenoma em primeiro plano.

**Desempenho:** todo número de custo por quadro diz o tipo de build. Só vale build de **profile** (`flutter run --profile`) ou **release**, no moto g54. A build de debug do Flutter é várias vezes mais lenta e o emulador não conta.

## 0.26.0

Não muda o save. Antes de qualquer toque pelo adb: o dono libera o aparelho na sessão, e tudo passa por `scripts/celular.sh`.

- [ ] `0260-hud-sol` **HUD ao sol.** Na rua, de dia e com sol forte: a barra do topo (hora, bateria, lua, clima), o retrato com o nível, o botão do celular e a bússola se leem sem esforço; o selo DEBUG e o aviso do relógio forçado nunca parecem o jogo normal.
- [ ] `0260-icones` **Ícones pequenos.** A lua e o clima na barra (uns 18 dp) se reconhecem: lua nova, crescente, cheia; chuva, tempestade, neblina; os ícones dos apps na grade, e o bloqueado com glitch.
- [ ] `0260-telas` **As telas no estilo da bolsa.** Bestiário, Círculo, Loadout, Perfil, Rotas, Patrulha, Céu, Chat, Fórum, Ajustes, Destilar e Fusão: painéis, botões (apertar afunda), abas, interruptores e diálogos novos; nada cortado nem sobreposto.
- [ ] `0260-tipos` **Cores dos tipos.** As etiquetas de tipo (ícone + nome) e as Fagulhas do mapa nas cores novas, distinguíveis entre si.
- [ ] `0260-dilúvio` **Barco, cachorro e corrida.** Na rua alagada o barco e a canoa; o passante com cachorro e a guia; o carro da corrida com a luz do teto acesa.
- [ ] `0260-molduras` **Molduras que esticam.** Os espaços vazios do Círculo e do Loadout, os cartões de família do Bestiário, as fichas do Perfil, as mensagens do Chat e os pedidos do Fórum com a moldura inteira, sem blocos claros e escuros no meio; a barra de XP do Perfil com a moldura mesmo em 0 XP.
- [ ] `0260-criaturas-28` **Ecos novos a 28 px, de noite e de dia.** Sootling (saruê), Frondling (fronde), Umbrel (morcego com a sombra presa: de noite lê quase só pela borda e pelos olhos), Wisplet (coruja; a ponta da chama no concreto), Wyrmlet (teú; as costuras não podem roubar a brasa) e o Humoth no amarelo novo. Os Espíritos novos a 36 px: a grelha do Cinderkin, a raiz-mão do Thicketkin, o braço de laje do Shadekin, a vela no peito do Hollowkin, o buraco de rua do Wyrmkin e o olho no peito do Coilkin.
- [ ] `0260-sombra-shade` **Shade sem sombra no chão.** O Umbrel e o Shadekin no mapa sem a sombra oval embaixo; as outras criaturas continuam com ela.
- [ ] `0260-fagulhas` **Fagulhas novas.** Elétrica (ocelo de LED), fogo (tufo com a brasa), planta (lobo da fronde), sombra (lasca com o olho), espectral (toco de vela) e dracônica (escama com a junta acesa), pairando e legíveis no mapa.
- [ ] `0260-gatilhos` **De onde nascem.** O Sootling sai do bueiro (a tampa desliza, fagulhas e fumaça), o Frondling da rachadura da calçada (a luz verde corre por dentro), o Wyrmlet do asfalto rachado com brasa e, na chuva de meteoros, da cratera rosa; legíveis embaixo do corpo, de noite e de dia.
- [ ] `0260-rituais` **Espécies de ritual.** Kilnshade (saruê sentado com a boca de fornalha), Rootseer (a fronde enrolada em olho sobre a placa de calçada) e Wellmirror (o sapo na manilha com a lua no papo) a 36 px; o Wellmirror é o que mais corre risco de não ler.
- [ ] `0260-textos-shade` **Bestiário do Shade.** O Umbrel e o Shadekin com o texto do morcego (sem "vulto").
- [ ] `0260-criaturas-28b` **Ecos e Espíritos das seis famílias restantes, de noite e de dia.** A 28 px: Glimlet (beija-flor-tesoura de vidro), Bitling (pombo com a faixa fora do lugar), Pebblet (tatu-bola), Rillet (cururu com o dorso de espelho), Rustling (besouro de élitros de grade; a luz do Metal é um cinza-azulado, conferir se lê) e Sprigglet (maritaca com asa batendo). A 36 px: Prismkin, Glitchkin (três cabeças), Bouldkin (guia de concreto), Brookkin (boca de lobo), Gratekin (portão) e Fairkin (pousada na pedra). As costuras do Véu não podem roubar o emissivo.
- [ ] `0260-fagulhas-b` **Fagulhas das seis famílias.** Luz (caco de vidro com a estrela), digital (pena em pixels), terra (placa de cascalho), água (gota pendente), metal (caco de grade) e feérico (sâmara), pairando e legíveis no mapa.
- [ ] `0260-retratos-b` **Retratos no Bestiário.** Os retratos de 96 dos Ecos e Espíritos das seis famílias, com as variantes trocando a cor sem perder a forma.
- [ ] `0260-gatilhos-b` **De onde nascem Glare, Bit, Rust e Sprig.** Glimlet de dia com o clarão de sol (estrela e risco de reflexo) e, com arco-íris à vista, descendo da faixa dele; de noite sem efeito. Bitling: a placa, banca ou ponto mais perto pisca em estática verde e os pixels chegam nele. Rustling: a grade range atrás dele e a limalha se junta. Sprigglet: redemoinho de folhas secas, com pólen rosa no crepúsculo.
- [ ] `0260-bestiario-fagulhas` **Fagulhas e células no Bestiário.** A coluna da Fagulha com o sprite do mapa pairando nas doze famílias (no lugar dos ícones de chama, glifo, fantasminha e folha); Umbrel e Shadekin legíveis na célula com a luz fraca atrás, de dia e de noite.
- [ ] `0260-rituais-fase1` **Criaturas de ritual da fase 1.** Stormlamp (Hum, tempestade à noite), Noonglass (Glare, sol forte ou arco-íris das 11h às 14h), Eaveshroud (Shade, nublado à noite ou Sol Negro), Staticroost (Bit, Estática), Vigilwick (Wisp, neblina ou Procissão), Cairnhollow (Clod, poeira seca), Duskwreath (Sprig, crepúsculo de lua cheia) Cratercoil (Wyrm, eclipse ou chuva de meteoros) e Gatewarden (Rust, smog). O Eco de ritual aparece no bioma de casa, a pesquisa revela os espaços, a condição do mundo confere com o clima da célula, o verbete abre no Bestiário (também o de Kilnshade, Rootseer e Wellmirror) e o mentor manda a dica da família ao ver o primeiro.

## 0.25.2

Muda o save (schema 14: saem a época em teste e a seção Desenvolvedor). Antes de qualquer toque pelo adb: o dono libera o aparelho na sessão, e tudo passa por `scripts/celular.sh`.

- [ ] `0252-dev` **Modo de desenvolvimento.** Depois de instalar por cima: o save continua (nível, Familiar, Bolsa); os Ajustes mostram "ÉPOCA 12 · DESENVOLVIMENTO" em Dados, sem a seção Desenvolvedor; o HUD não mostra "Época 12 em teste"; o mundo novo (NPCs, Ônibus Espectral, Caco de vidro) aparece sem ligar nada; nenhum aviso de mundo desatualizado.
- [ ] `0252-ponto` **Ponto de ônibus inteiro de pé.** Girando o mapa com dois dedos (ou "Giro dos objetos" no debug): poste com a placa azul, cobertura, painel e banco saem iguais em qualquer ângulo; nada no chão gira com a rua embaixo dele. Banca e placas de rua também.
- [ ] `0252-sp` **São Paulo sem baixar.** No simulador, em São Paulo (Paulista): o mapa abre direto, com prédios, relevo e tráfego, sem pedir download; nos Ajustes a região aparece pronta.
- [ ] `0252-apk` **APK de 170 MB.** A instalação por cima cabe e não demora demais (antes, 100 MB).

## 0.25.1

- [ ] `0251-criaturas` **As famílias em 2 dp.** Soot, Rill e Frond (as que você mais encontra) e as da fase 1 com as animações novas: paradas, andando, em alerta perto de você, nascendo, fugindo e se desfazendo ao sintonizar; de noite os olhos e as brasas acesos por cima do escuro. Os Rituais do tamanho dos Espíritos.
- [ ] `0251-nascer` **Gatilhos de nascer.** Na tempestade o Humoth nasce num raio; de noite, perto de poste, nas faíscas que saem dele; na chuva o Rill numa poça que ondula; o Clod do chão revirado; na neblina o Wisp de fiapos que se juntam.
- [ ] `0251-trafego` **Tráfego novo.** Carros, motos, ciclistas, ônibus e passantes do Aseprite, girando com as ruas sem tremer; roupas de chuva, frio e calor por cima; faróis e janelas do ônibus acesos de noite.
- [ ] `0251-fagulhas` **Fagulhas.** Uma forma por tipo (chama, gota, folha, faísca...), legíveis na calçada clara e no asfalto, de dia e de noite.
- [ ] `0251-bestiario` **Retratos.** Todo cartão do Bestiário animado; no detalhe, escolher uma variante troca as cores do retrato como no mapa.
- [ ] `0251-simples` **Simplificado a 80 m** (build de profile): caiu de 19,5 para 12,3 ms de raster no p50; conferir que as áreas verdes e a água continuam com textura e borda.

## 0.25.0

O mapa passa a pixel de 2 dp. Antes de qualquer toque pelo adb: o dono libera o aparelho na sessão, e tudo passa por `scripts/celular.sh`.

- [ ] `0250-2dp` **Mapa em 2 dp andando na rua.** Conjurador, Familiar, árvores, postes, telhados, NPCs e materiais com mais detalhe e o mesmo tamanho de antes; nada borrado nem com pixel desigual, parado e girando.
- [ ] `0250-custo` **Custo por quadro** (build de profile): zoom fechado, zoom aberto e Vigília com Tempestade abaixo de 16 ms; no emulador ficou igual ao de 3 dp. *Medido no g54 na 0.25.1, a frio: o Completo passou nos três (p90 até 14,8 ms); números em `docs/marcos.md`. Falta a sua conferência andando de verdade.*
- [ ] `0250-humoth` **Humoth de noite.** Perto de poste, de noite: o corpo escuro, os ocelos ciano piscando como letreiro com mau contato e os veios amarelos acesos por cima da noite e da chuva; em alerta com você perto; nascendo em faíscas; se desfazendo em faíscas que vêm até você ao sintonizar; subindo de lado ao fugir.
- [ ] `0250-humoth-sintonia` **Sintonia do Humoth.** Os LEDs acendem a cada salto de frequência e ficam fixos quando o sinal trava.
- [ ] `0250-plural` **Concordância.** "Falta 1 dia" e "Faltam 3 dias" na banca e nos rumores; "1 Folha seca", "3 Folhas secas" na troca dos NPCs.

## 0.24.5

Muda o save (schema 13). Os NPCs e a sintonia são da época 12 (desde a 0.25.2, a época de desenvolvimento, sempre ativa).

- [ ] `0245-onibus` **Ônibus nos pontos.** Num ponto de avenida, o ônibus comum encosta ao lado do ponto desenhado, quem espera embarca e às vezes alguém desce e segue andando.
- [ ] `0245-espectral` **Ônibus Espectral.** No minuto que o painel do ponto mostra, ele chega translúcido, para, deixa ou leva um passageiro que some na calçada, e segue; tocando no ponto com ele parado, a fala de "parado agora". Igual no celular de um amigo no mesmo ponto e hora.
- [ ] `0245-npcs` **Outros Veilbreakers.** No fim da tarde, nas praças e no Iluminado, de vez em quando um NPC andando pela calçada; quase nenhum de madrugada. Às vezes ele para e um Eco perto some com o anel do sinal (nunca um Eco a menos de 30 m de você).
- [ ] `0245-folha` **Folha do NPC.** Tocando a até 30 m, a pé: nome, escola, fala, a troca do dia (uma por NPC por dia, recusada sem material ou com a bolsa cheia) e às vezes um rumor que confere (o Espectral no minuto dito, a família perto).
- [ ] `0245-conhecidos` **Conhecidos.** Um conhecido aparece no mesmo bairro nos dias e horas dele; trocando com ele dias seguidos, a relação sobe e fica depois de fechar o app.
- [ ] `0245-veiculos` **Veículos do Véu.** Fabricar bicicleta ou skate (nível 6) e a carroça (nível 11), equipar nos espaços novos do Loadout; de bicicleta o avatar aparece nela, de ônibus ou carro (Modo Viagem) na carroça, a pé nada; o baú e as Fagulhas da viagem iguais aos de sem veículo.

## 0.24.4

- [ ] `0244-voltar` **Voltar.** No menu de debug, Voltar com busca limpa a busca; no topo, volta ao mapa (nunca fecha o app). Nos apps do celular, Voltar sai do app para o celular e do celular para o mapa; no Loadout com a lista de troca aberta e no Experimentar com a escolha de material aberta, o primeiro Voltar só fecha a lista.

## 0.24.3

Não muda o save. Antes de qualquer toque pelo adb: o dono libera o aparelho na sessão, e tudo passa por `scripts/celular.sh`.

- [ ] `0243-copa` **A copa balança.** Tocar uma árvore de calçada ou de praça (a até 30 m, a pé): o topo da copa vai e volta umas duas vezes e para em pouco mais de 1 s; a base e a sombra ficam. Vale também sem folha.

## 0.24.2

Muda o save (schema 12). Antes de qualquer toque pelo adb: o dono libera o aparelho na sessão, e tudo passa por `scripts/celular.sh`.

- [ ] `0242-passaros` **Pássaros por cima.** Pombos voando e maritacas passam por cima dos telhados e das árvores; pombo que pousa num prédio fica no telhado.
- [ ] `0242-vidro` **Caco de vidro:** cai no Urbano e mais no Iluminado; 2 cacos fazem a garrafa; o primeiro caco abre a quest.
- [ ] `0242-toques` **Toques no mapa, a pé e a até 30 m:** ponto (próximo Ônibus Espectral), banca (manchete igual à de um amigo no mesmo dia), placa (nome da rua), bando (voa, às vezes pena), árvore (folha no outono, flor no ipê florido; uma vez por dia), poça na chuva (onda; Eco de Água se vira), poste à noite (pisca; Hum fica à vista), gato (coração, segue um quarteirão, às vezes larga algo). De carro, nada responde.
- [ ] `0242-limites` **Limites do dia:** depois de 3 penas, 6 árvores e 3 presentes de gato, o aviso do limite aparece; no dia seguinte volta.

## 0.24.1

- [ ] `0241-topo` **Telas do celular até o topo.** Bolsa, Bancada, Loadout e Radar sem a faixa preta: a barra de status fina divide o topo com o furo da câmera.
- [ ] `0241-limite` **Bolsa no limite.** Com a bolsa cheia, pegar material, colher um plantado, tirar do cinto ou do loadout é recusado com aviso; a conta nunca passa do total.
- [ ] `0241-quest` **Primeira garrafa.** Num jogo que ainda não pegou Sucata: a primeira Sucata traz a mensagem do mentor e a lista de tarefas na Bolsa e na Bancada; cada passo marcado em violeta na tela certa; na chuva de verdade, a garrafa do cinto enche; o tônico com a água fecha a quest e traz a página da lua.
- [ ] `0241-presente` **Presente.** Sem nenhum recipiente, abrir a aba Condições dá uma Garrafa de vidro e a mensagem do mentor, uma vez.
- [ ] `0241-coletor` **Coletor no mapa.** O plantado fica menor que o Conjurador e ainda se reconhece (garrafa, frasco, pote); a base muda de cor cheio, enchendo e esperando.

## 0.24.0

Muda o save (schema 10): instalar por cima da 0.23.2 e conferir que nada some.

- [ ] `0240-save` **Save da 0.23.2.** Depois de instalar por cima: o inventário inteiro aparece na Bolsa como comum (um ponto), as criaturas continuam na Coleção (Círculo, "Ver a Coleção") e as receitas antigas (selos, tônico, prisma) aparecem na Bancada.
- [ ] `0240-plantado-chuva` **Coletor plantado numa caminhada de verdade na chuva.** Com uma Garrafa de vidro na bolsa, a pé, plantar pela Bolsa (aba Condições) num ponto e seguir andando; outro a menos de 100 m é recusado. Uns 20 minutos de chuva depois (mesmo longe), o Radar e Rotas mostram "cheio"; voltar até ele e colher pelo toque no mapa: vai para o cinto com a qualidade da chuva (garoa um ponto, chuva dois, tempestade três).
- [ ] `0240-carro` **Plantar de carro.** Num ônibus ou carro, "Plantar" recusa com "Só a pé".
- [ ] `0240-patrulha` **Aviso da Patrulha.** Com um coletor plantado e a Patrulha ligada (app em segundo plano), quando ele encher sai uma notificação "Coletor plantado cheio" e o celular vibra; ao abrir o app, o aviso não se repete no mapa.
- [ ] `0240-cinto` **Garrafa no cinto na chuva.** Uma garrafa vazia no cinto, app aberto ou Patrulha, uns 5 minutos de chuva: enche, com aviso. Depois de alguns dias, a neve engarrafada (Inverno do Véu, Noite Branca) vira água de neve, menos no frasco térmico.
- [ ] `0240-bolsa-visual` **Bolsa e Bancada no aparelho.** Molduras, abas e ícones nítidos (pixel de 3 dp, sem borrão) em 412 × 915; a grade de 4 colunas cabe; segurar "Descartar" leva um segundo e soltar antes cancela.
- [ ] `0240-equip` **Equipamento no Conjurador.** Com bolsa, garrafas no cinto e amuleto equipados, o sprite do mapa mostra a bolsa, de 1 a 3 garrafas e o brilho; "Mostrar no personagem" desligado tira cada um; virando para a esquerda, tudo espelha junto; girando o mapa, fica de pé.

## 0.23.2

- [ ] `0232-pinca` **Chão na pinça.** Dando zoom devagar com dois dedos no Centro: o chão (calçada portuguesa, faixas, ladrilho) não estica mais durante o gesto; o pixel muda de tamanho em passos pequenos (6%) e volta à grade nítida ao soltar.
- [ ] `0232-topo` **HUD no topo.** Na tela cheia, sem faixa preta acima do HUD: a barra começa no topo da tela, a hora e a bateria à esquerda do furo da câmera, o selo à direita. Com "Barras do Android" ligado, o HUD fica embaixo da barra de status, como antes.
- [ ] `0232-nevoa` **Névoa curta.** A passagem do céu para o mapa é uma faixa curta de pontos soltos, sem xadrez nem grade, sobre telhado claro e sobre grama.
- [ ] `0232-sombra` **Sombras translúcidas.** De manhã ou no fim da tarde (relógio do debug), no estacionamento do Dom Pedro: a sombra dos prédios escurece o asfalto e deixa ver as vagas, a grama e a calçada. O shopping, com o centro fora da tela, continua com telhado e parede (antes sobrava só a planta escura no chão).

## 0.23.1

- [ ] `0231-giro-sprites` **Árvore e telhado de pé.** Debug, "Giro dos objetos", girando o mapa com o dedo devagar: a copa de cada árvore e de cada ipê não muda de forma (a sombra também não, só muda de lado com o sol), e a caixa d'água, o ar-condicionado e a antena ficam no mesmo ponto do telhado e de pé. Pare a 30° e tire uma foto.
- [ ] `0231-chao` **O chão pelo uso do solo.** Num estacionamento (o do Shopping Iguatemi ou de um supermercado), num terreno baldio e numa rua de bairro: o estacionamento é asfalto com vagas, o terreno é terra com mato, o bairro tem o chão do lote, e ladrilho só em praça e calçadão. Nada de piso branco paginado ao longo das avenidas.
- [ ] `0231-calcada` **Calçada.** No Centro, a calçada portuguesa (ondas pretas e brancas); fora dele, concreto liso com junta discreta, sem a faixa grossa.
- [ ] `0231-pixel` **Mesma grade de pixel.** (Medido em 2026-11-17 na 0.23.1: o borrão era o chão no meio do giro e da pinça, refeito em menos de 1 s ao soltar; a 0.23.2 refaz o chão em passos de zoom na pinça, item `0232-pinca`.) Parado e logo depois de girar e de dar zoom: paredes, telhados, chão e Ecos com o mesmo tamanho de pixel, nítidos, nada borrado ou esticado. Se ainda aparecer, uma foto de perto e o que estava fazendo (girando, pinçando ou parado).
- [ ] `0231-paredes` **Prédio alto.** Perto de um prédio alto do Centro, na borda da tela e no meio: a parede escura se lê como lado de prédio e não cobre a rua inteira (o telhado sai no máximo um quarto da distância do centro da tela até a borda).
- [ ] `0231-materiais` **Materiais.** Os quadrados cinza e brancos viraram sprites (engrenagem de sucata, giz, ervas, frasco de água...): leem bem ao sol e não se confundem com Fagulha nem Eco.
- [ ] `0231-tela-cheia` **Tela cheia.** Sem barra de status e de navegação no mapa, na sintonia e no celular do jogo; um deslize da borda mostra as barras, que somem de novo sozinhas. O HUD fica fora do recorte da câmera, a bateria aparece ao lado da hora (laranja com 20% ou menos) e o céu aparece inteiro embaixo da barra do HUD. Ajustes, "Barras do Android" ligado: as barras voltam e o mapa não passa por baixo delas.
- [ ] `0231-california` **Simulador depois do mapa da rede.** Com o GPS real fora das regiões (ou o mapa da rede de qualquer lugar sem pacote), abra o mapa, espere carregar e ligue o simulador pela folha do modo: o app não pode parar de responder. No emulador (2026-11-17) a sequência não travou em duas tentativas; a trava da 0.23.0 coincidiu com o notebook sem memória.

## 0.23.0

- [ ] `0230-overture-centro` **Centro andando, com os prédios do Overture.** Uma volta de uns 10 minutos no Centro de Campinas (Praça Ramos de Azevedo, Rua 13 de Maio, Largo do Rosário): onde antes havia quarteirão vazio agora há prédios. Anote o endereço de cada **prédio fantasma** (prédio onde a rua tem praça, terreno vazio ou estacionamento) e de cada **prédio faltando** (construção de verdade sem contorno no mapa), e se algum prédio aparece em cima da rua ou da calçada.
- [ ] `0230-overture-ouro-verde` **Ouro Verde andando.** O mesmo no Ouro Verde (em volta da Avenida Ruy Rodriguez): o bairro passou de 53 para uns 4.950 prédios, quase todos casas detectadas por satélite, sem altura (todas com a altura estimada pelo tamanho). Anote fantasma e faltando como acima, e se os quarteirões cheios de casas ficam legíveis (o Conjurador e os Ecos destacam).
- [ ] `0230-overture-desempenho` **Desempenho com 30 vezes mais prédios.** Build de profile, Completo, andando no Ouro Verde e no Centro por 5 minutos em cada: fps e p90 do build e do raster (método da 0.22.1) e a linha "Prédios" do Debug, Desempenho (abaixo de 24 MB). Meta: p90 abaixo de 16 ms, como na 0.22.1.
- [ ] `0230-shade` **Mais lugares para a Shade, com teto.** Com a Shade no Círculo, à noite, no Centro: o Eco dela aparece em calçadas de comércio onde antes não aparecia (as células com comércio, bar ou beco passaram de 4.456 para 15.695 em Campinas), mas no máximo 2 por quarteirão (célula z18, desde a 0.23.1). Vale da época 12 em diante, que ainda não tem data (início em 2099 até ser publicada); antes, só forçando a época pelo Debug.
- [ ] `0230-arvore-sombra` **Sombras das árvores.** Num parque, com o sol baixo (manhã ou fim de tarde) e alto (meio-dia), girando o mapa: a sombra de cada árvore tem a forma da copa dela (ipê, árvores redondas e lobadas), não um oval igual para todas.
- [ ] `0230-creditos` **Créditos.** Ajustes, botão "Créditos": OpenStreetMap, Overture Maps Foundation, Microsoft, Google Open Buildings, as fontes dos places, Foursquare e SRTM, cada um com a licença; a tela rola até o fim.

## 0.22.2

- [ ] `0222-perfil-zoom` **Zoom ampliado e Rotas em profile.** Com a build de profile (mesma chave), Ajustes, "Zoom ampliado" ligado: andando no Centro com a tela em 250 m (Debug, "Largura da tela", 250 m) e o mapa de Rotas aberto no máximo (Rotas, Nova viagem, No mapa). Anote o fps e o p90 do build e do raster (método da 0.22.1, em `docs/marcos.md`). Meta: abaixo de 16 ms no p90.
- [ ] `0222-zoom-troca` **A troca de estilo pelo zoom, sem tranco.** Com o Zoom ampliado, abra a pinça devagar de 80 m até 250 m e feche de novo: acima de 120 m o mapa fica Simplificado (sem prédios, sem tráfego, sem chuva), e ao voltar abaixo de uns 112 m o Completo reaparece sem um quadro preso.
- [ ] `0222-sp-predios` **São Paulo com prédios andando de verdade.** Depois que o arquivo de prédios de São Paulo for publicado (hoje não está): na Paulista, os prédios aparecem em volta em menos de um segundo ao chegar num pedaço novo, e o Debug, Desempenho, linha "Prédios", fica abaixo de 24 MB andando por 20 minutos.
- [ ] `0222-giro-rotulos` **Giro dos objetos.** Debug, "Giro dos objetos" ligado, girando o mapa com o dedo: tudo que diz "gira com o chão" gira junto com o chão, inclusive a textura do asfalto, da calçada e do telhado; o que diz "de pé" fica de pé; carros, ônibus e nomes de rua dizem "gira com o rumo" (exceção esperando a sua decisão).
- [ ] `0222-arte-aseprite` **A arte do Aseprite no celular.** Desde a 0.23.0 a arte do Aseprite é o padrão; Debug, "Arte em código" ligado e desligado no mesmo lugar, de dia e de noite: a do Aseprite lê tão bem quanto a de código ao sol (telhados contra a rua, árvores, ipês, ponto de ônibus, banca, calçada), e o Conjurador e os Ecos destacam igual.

## 0.22.0 e 0.22.1

- [x] `0220-perfil-antes-depois` **Perfil no celular, em profile.** Feito em 2026-11-16 (números em `docs/marcos.md`, 0.22.1): Completo a 62–118 fps andando, p90 abaixo de 16 ms em todos os casos; os dois travamentos achados foram corrigidos na 0.22.1.
- [ ] `0220-custo-release` **Custo por quadro na release, nos dois estilos.** Ajustes, "Gráficos do mapa": Completo e depois Simplificado, andando no Centro por um minuto em cada; Debug, Desempenho, anote o custo médio do mapa nos dois, marcado "release".
- [ ] `0220-mapa-rua` **O mapa novo andando na rua.** Uma volta de uns 10 minutos (Centro ou bairro): os prédios com paredes e telhados variados, árvores e ipês nas praças, calçada portuguesa no Centro, faixas de pedestre e pontos de ônibus nos lugares certos do OSM; ao andar, o chão não pisca e nenhum bloco fica vazio por mais de um instante.
- [ ] `0220-giro` **Girar o mapa.** Arraste girando devagar e rápido: o chão gira em passos pequenos durante o gesto e, um instante depois de soltar, fica nítido no ângulo exato; árvores, postes, props, Ecos e o Conjurador ficam sempre de pé; as paredes e os telhados saem do centro da tela para fora em qualquer giro.
- [ ] `0220-leitura-sol` **Leitura ao sol.** Com o brilho no automático, ao sol do meio-dia: dá para ver o Conjurador, os Ecos, as Fagulhas, a Aura e o alcance sem procurar, e o telhado sobre o Conjurador ou um Eco fica translúcido.
- [ ] `0220-sugestao-simplificado` **A sugestão do Simplificado sai uma vez só.** Só se o Completo ficar lento (mais de 20 ms por quadro em média por um minuto): um aviso sugere os gráficos Simplificado, sem trocar sozinho; não volta a aparecer depois.
- [ ] `0220-chuva-noite` **Chuva à noite.** Com chuva (de verdade ou forçada) depois do pôr do sol: o asfalto fica molhado, com brilho e o reflexo dos postes embaixo de cada um, além das poças.


## 0.21.0

- [ ] `0210-pilha-sexta13` **Vigília e Tempestade juntas.** Debug, "Clima forçado" Tempestade e "Eventos forçados" Vigília: chove inclinado com raio, os olhos aparecem no alto, e a linha de aviso mostra "PILHA TEMPESTADE · EVENTOS VIGÍLIA · COMBINAÇÃO VIGÍLIA COM TEMPESTADE"; os raios caem nos olhares quando há um por perto.
- [ ] `0210-ceu-camadas` **O app Céu separa clima e evento.** Com a Lua Carmim forçada sobre a Chuva: "Clima agora" mostra Chuva, "Eventos ativos" mostra a Lua Carmim com até quando vale, e o Calendário do Véu lista os próximos três, marcados como clima ou evento.
- [ ] `0210-lua-carmim` **A Lua Carmim tinge a chuva e, com sol, fica só no céu.** Forçada sobre Chuva: gotas e poças vermelhas, HUD "Chuva Carmim · Lua Carmim". Forçada sobre Limpo: só o tom vermelho, nada caindo.
- [ ] `0210-laboratorio` **O Laboratório visual no aparelho.** Debug, "Laboratório visual": o quarteirão da Praça Ramos de Azevedo abre, o arrastar move, o giro gira o mapa e o céu junto, e os botões Antes, Depois, Manhã, Meio-dia, Pôr do sol, Noite, Chuva e Vigília + Tempestade trocam a cena. Os pixels de arte ficam nítidos (3 dp), sem borrão.
- [ ] `0210-laboratorio-desempenho` **Desempenho do laboratório.** Na build de release, a linha de baixo do laboratório mostra o custo do quadro: anote o de Antes e o de Depois ao meio-dia e à noite (no emulador, na build de debug, deu 0,4 ms antes e 17 a 47 ms depois; só a comparação vale).
- [ ] `0210-variantes-rua` **As variantes se leem na rua, ao sol.** Com o debug forçando variante no próximo Eco (e o Brilhante), ande até ver uma de cada: dá para dizer qual é pelo acessório (abafador, broto, pingos, telhado, neon, auréola, chifres, estrela) sem chegar perto, com o brilho da tela no automático, ao sol. O Brilhante é o único que pisca.
- [ ] `0210-reabrir-mapa` **Reabrir o mapa pelo debug não empilha.** No mapa, selo de modo, "Menu de debug", e logo "Abrir mapa do jogo": abre um mapa só, sem tela vermelha de "setState during build".
- [ ] `0210-save-v9` **O save sobe para o schema 9 sem perder nada.** Ao instalar por cima da 0.20.x: a coleção, a Bolsa e o Bestiário continuam; Debug, Assinaturas, mostra o schema 9.

## 0.20.4

- [ ] `0204-emulador-sem-recompensa` **O emulador não dá recompensa.** No emulador (não no celular), com o interruptor "GPS simulado dá recompensa" do debug desligado, pegue uma Fagulha: o aviso diz "(debug, fora da Bolsa)" e a Bolsa não muda. Ligado o interruptor, a Fagulha entra.
- [ ] `0204-workbench-tailscale` **O workbench abre no celular pelo Tailscale.** Com o servidor rodando no notebook ou no PC, abra o endereço do `docs/workbench.md` no navegador do celular, dentro da tailnet. Mande uma nota de um item: ela tem de aparecer no `workbench/notes.json` da máquina.
- [ ] `0204-workbench-checklist` **A aba Checklist do workbench mostra estes itens**, na ordem deste arquivo, com o filtro por versão, e aceita nota em cada item.
- [ ] `0204-desempenho-4ms` **Desempenho medido no celular.** Debug, Desempenho, com o tráfego, a neblina forçada e uma chuva: tráfego, véu da neblina, bichos e vento e a cobertura do clima somados abaixo de 4 ms por quadro; o cálculo da água do relevo uma vez por tile, fora do quadro. O emulador só serve para comparar antes e depois.

## 0.20.3

- [ ] `0203-pocas-rill` **Dá para perceber as poças do Rill andando na chuva.** Numa chuva de verdade (ou forçada no debug), com um Rill no Círculo, em cada uma das três faixas (níveis 1 a 9, 10 a 19, 20): 2, 4 e 6 poças a mais por quadra de uns 150 m, sempre na rua ou na calçada, algumas com Eco de Água.
- [ ] `0203-marcador-pocas` **O marcador de poças e o "ir até a poça mais próxima".** Debug, Spawns, "Poças no mapa": alvo laranja nas poças do Rill e ciano nas da água do relevo. O botão "Ir até a poça mais próxima" liga o GPS simulado sem recompensa e leva até uma poça.
- [ ] `0203-agua-relevo` **A água do relevo nas baixadas, sem tranco.** Chuva forçada perto da Lagoa do Taquaral e Dilúvio forçado na Norte-Sul (perto da Orosimbo Maia): as poças nas baixadas e a rua alagada aparecem; entrar de bicicleta simulada num bloco novo não dá tranco (o tile da água é calculado fora do quadro e chega em menos de um segundo na build de release).
- [ ] `0203-hum-noite` **Hum à noite perto de postes, e na tempestade.** À noite (ou com o relógio do debug à noite), numa rua com semáforos ou pontos de ônibus, com um Hum no Círculo: Ecos Elétricos a mais junto dos postes, em postes diferentes. De dia com tempo limpo, nenhum; de dia com tempestade forçada, aparecem.
- [ ] `0203-hash-camadas` **Hash da camada base igual no celular e no emulador.** Ponha o emulador no lugar do celular (`scripts/emulador/rota.py --fixo=lat,lon`, com o lat e lon do celular), e compare no debug ("Camada pessoal de spawn") a célula, a janela e os dois hashes: a `base` tem de ser igual e a `pessoal`, diferente.

## 0.20.2

- [ ] `0202-shade-becos` **Shade em becos à noite.** À noite, com um Shade no Círculo, num beco (`service=alley`) ou num caminho estreito entre prédios: às vezes um Eco a mais ali, como sob as marquises. Só na época 12 em diante (os becos vêm no arquivo de pontos dela).
- [ ] `0202-hum-wisp-hora` **Hum e Wisp por hora.** Com um Hum (à noite, perto de postes) ou um Wisp (na neblina ou no Sagrado) no Círculo, 1, 2 e 3 Ecos a mais por quadra de uns 300 m e por hora, nas três faixas; os da mesma hora continuam lá a hora inteira.
- [ ] `0202-trabalho-gdd` **O Trabalho das famílias com o texto do GDD**, na aba Atributos do Bestiário: "Trabalho: forja e fornalha (em breve)" para o Soot e a frase depois, e assim nas doze.

## 0.20.1

- [ ] `0201-interruptor-pessoal` **O interruptor da camada pessoal.** Debug, "Camada pessoal de spawn": esconder tira os extras do mapa (o mundo base fica igual), mostrar devolve; o contador de Ecos, poças e materiais sobe enquanto se anda.
- [ ] `0201-shade-wisp-sprig` **Shade, Wisp e Sprig à noite acrescentam o que dizem.** À noite, na mesma célula, com o Círculo vazio e depois com Shade, Wisp e Sprig: os Ecos a mais (sob marquises, Espectrais na neblina ou no Sagrado) e mais variantes entre eles.
- [ ] `0201-clod-bit` **Clod e Bit.** Com um Clod no Círculo, de vez em quando um material vem com uma unidade a mais. Com um Bit, mais Ocultos entre os Ecos da camada pessoal, e destilar um Eco que era Oculto rende 2 de Essência a mais.
- [ ] `0201-janela-seguinte` **Trocar o Círculo muda a camada pessoal só a partir da janela seguinte.** Parado numa célula, troque o Círculo: os extras da janela atual não mudam; mudam quando a janela da célula vira (até 20 min).
- [ ] `0201-texto-habilidade` **A habilidade por extenso.** Na aba Atributos do Bestiário e no Círculo: o efeito por extenso, com a faixa atual e a próxima, e o Trabalho como "em breve". Nenhuma habilidade de mapa diz "em breve".
- [ ] `0201-marcar` **Marcar até 3 espécies.** No Bestiário, marcar destaca a espécie no mapa (cantos e seta em ciano, seta na borda quando fora da tela) e no Radar (losango sem pulso), dentro do alcance do Radar; na Patrulha, avisa uma vez por Eco. A quarta marca é recusada com aviso.

## 0.20.0

- [ ] `0200-sem-som` **Nenhum som toca**, em lugar nenhum, e os Ajustes não têm interruptor de som. A vibração continua.
- [ ] `0200-wyrm-nivel` **O Wyrm não aparece antes do nível 10** do Conjurador, nem nos eclipses, na chuva de meteoros ou no Vento das Fendas.
- [ ] `0200-sintonia-tipos` **A sintonia de cada tipo novo**, pelo debug (Captura, uma espécie de cada tipo): o padrão de resistência certo (faixas pesadas da Terra, salto do Elétrico, blindagem do Metal, clarão da Luz, tinta da Sombra, cópia atrasada do Espectral, glitch do Digital, dial invertido do Feérico, etapas do Dracônico).
- [ ] `0200-bestiario` **O Bestiário.** A vista por família, a grade com filtro, a busca, as 4 abas do detalhe, as bolinhas de variante trocando a arte e as setas entre as formas.
- [ ] `0200-sem-arisco` **Nenhum Eco Arisco ou Agressivo**, e o Eco não foge depois de uma sintonia falha com o Xamã Urbano.

## Pendências antigas

- [ ] `antigo-teste-de-rua` **O teste de rua** de `docs/teste-de-rua.md`, inteiro.
- [ ] `antigo-notificacoes-corrida` **O texto real das notificações de uma corrida de Uber ou 99**, para o Modo Viagem reconhecer o passageiro.
