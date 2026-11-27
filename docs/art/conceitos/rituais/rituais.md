# Espécies de ritual das nove famílias

Uma espécie de ritual para cada família que ainda não tinha: Hum, Clod, Rust, Glare, Shade, Wisp, Bit, Sprig e Wyrm. Seguem a regra das três atuais (`docs/art/conceitos/rituais.md`): etapa Espírito (quadro de 36, retrato de 96), parada como um ídolo, sem olho aberto, partes em número certo e uma parte do corpo que virou o altar com o elemento dentro, duas costuras do Véu de 2 px só no emissivo.

**Estado: aprovadas pelo dono em 2026-11-26, as doze** (estas nove e Kilnshade, Rootseer e Wellmirror). Todas têm arte final, receita, verbete do Bestiário, Eco de ritual na época de desenvolvimento e dica do mentor. A folha das doze é `docs/art/final/rituais_doze.png`.

## Estado final

Arte final em `tools/art/creatures/<nome>/build.lua` (kit da família, `tools/art/rodar.sh`), copiada para `app/assets/art/creatures/<nome>/` por `scripts/sync_creature_art.py`. Etapa Espírito, quadro de 36 e retrato de 96, seis animações nas três camadas (corpo, `_leds`, `_glow`) e sete variantes. As receitas estão em `app/assets/data/rituals.json`, com Círculo `min_level` 5. Os verbetes finais estão em `docs/textos-bestiario.md` e as dicas do mentor em `docs/textos-mentor.md`.

| Espécie | Como ficou | Luz (emissivo) | Condição | Materiais |
|---|---|---|---|---|
| Stormlamp (`hum.ritual`) | Mariposa pousada, de asas fechadas em delta, com o tórax de globo de lâmpada de rua e o raio dentro. | o globo e o raio, os veios das asas, as costuras, as faíscas | tempestade, das 19h às 5h | `item.glass_shard` ×2, `item.essence.electric`, `item.rain_water` |
| Noonglass (`glare.ritual`) | Beija-flor-tesoura pousado no vergalhão, de olho fechado, com a lente de farol e o sol do meio-dia no peito; o vergalhão vai junto na fuga. | a lente, as três cores da cauda, as costuras, os reflexos | sol forte ou arco-íris, das 11h às 14h | `item.glass_shard` ×2, `item.essence.light`, `item.prism_shard` |
| Eaveshroud (`shade.ritual`) | Morcego embrulhado nas asas debaixo da marquise, com o Sol Negro onde elas se cruzam; no alerta abre um olho de sombra no disco. | a coroa e os raios do Sol Negro (o disco é corpo), as costuras | nublado, das 20h às 5h, ou Sol Negro | `item.moonlight.new` ×2, `item.essence.shadow`, `item.vessel.dark` |
| Staticroost (`bit.ritual`) | Pombo estufado no alto da placa, com as penas do peito se desfazendo em Estática; a placa vai junto no salto da fuga. | a Estática no peito e solta à frente, os LEDs da placa, a emenda do glitch, as costuras | Estática | `item.feather` ×2, `item.essence.digital`, `item.scrap` |
| Vigilwick (`wisp.ritual`) | Coruja-buraqueira de pé na toca, com o nicho ogival escuro no rosto e só a chama da vela acesa; a chama fica fixa na mesma coluna. | a chama, o frio na boca da toca, as costuras, o frio solto | neblina ou Procissão | `item.ectoplasm` ×2, `item.essence.spectral`, `item.vessel.candle` |
| Cairnhollow (`clod.ritual`) | Tatu-bola partido como geodo: cinco cachos irregulares de cristal (onze prismas de tamanhos e ângulos diferentes) pela borda da abertura, o fundo escuro torto e a parede esquerda nua no meio; a cabeça e as garras saem pela abertura. | os cachos (um acende por fase do idle, todos no alerta), duas juntas das cintas, as costuras, a poeira | poeira seca | `item.chalk` ×2, `item.essence.earth`, `item.ref.white_clay` |
| Duskwreath (`sprig.ritual`) | Maritaca com as asas em dois ramos de folha seca serrilhada abertos em leque em volta do corpo, sem fechar, e o crepúsculo nos vãos; azul na garganta. | a nervura de cada folha, o ponto claro entre as folhas, as costuras, o pólen | crepúsculo real e lua cheia | `item.dry_leaf` ×3, `item.essence.fae`, `item.ipe_flower` |
| Cratercoil (`wyrm.ritual`) | Teiú saindo até o peito de um buraco no asfalto, garras na borda, faixas pretas e brancas com divisas rosa; o buraco é fixo e a fuga é mergulhar nele. | a língua e a frincha da boca, as divisas, as rachaduras da borda, as costuras | Sol Negro ou chuva de meteoros | `item.meteorite` ×2, `item.essence.draconic`, `item.rift_smoke` |
| Gatewarden (`rust.ritual`) | Besouro-rinoceronte de perfil, de olho fechado: cúpula alta de grade de portão enferrujada, cabeça baixa e chifre curvo na mesma ferrugem, seis patas curtas; duas barras do flanco se afastaram em amêndoa e a luz sai só por essa fresta; um cadeado de latão aberto pendurado. | a fresta e o vazamento nos vãos vizinhos, as costuras, a limalha solta | smog | `item.scrap` ×3, `item.essence.metal`, `item.ref.living_rust` |

Desvios do criativo aprovados com a arte: o poleiro que vai junto na fuga (Noonglass e Staticroost), o olho no Sol Negro no alerta (Eaveshroud), a chama fixa (Vigilwick), o azul na garganta (Duskwreath) e o mergulho no buraco (Cratercoil).

As condições usam os tipos de `app/lib/crafting/ritual_data.dart`: `climate` (clima e evento da célula), `twilight` (crepúsculo real) e as combinações `all` e `any`, além de `hour`, `biome`, `moon` e `weather`. A coluna "Gravável hoje" das receitas propostas, abaixo, ficou para trás.

### Gatewarden: conceito substituído

O conceito das revisões 2 a 4 (o besouro com os élitros em duas folhas de portão e a limalha ou a cunha de luz no vão) **foi substituído** pela cúpula de grade acima, por decisão do dono, depois de reprovar duas vezes a 36 px. Os arquivos ficam como registro, sem uso: `tools/art/creatures/conceitos/rituais/gatewarden/` (o `build.lua` traz o aviso no cabeçalho) e a coluna do Gatewarden em `rituais.png` e `rituais_revisao.png`. Tudo o que fala de folhas de portão no histórico abaixo vale só para esse conceito.

## Histórico das propostas

O que segue é o registro das revisões, mais novo primeiro, e a proposta original. Não descreve o jogo; o estado final está acima.


### Revisão 4

Gatewarden, Cratercoil e Duskwreath refeitos; o Cairnhollow foi corrigido à parte. Nomes e regra não mudam.

| Espécie | Como ficou |
|---|---|
| Gatewarden | besouro-rinoceronte baixo e largo, de perfil, chifre rente ao chão; os élitros são duas folhas de portão abertas para trás, com uma cunha sólida de luz Metal entre elas; seis patas curtas. |
| Cratercoil | teú atarracado até o peito para fora do buraco, patas da frente dobradas no cotovelo, mãos de três garras fora do buraco; cabeça larga e rombuda, língua bífida; faixas pretas e brancas, divisas rosa por cima. |
| Duskwreath | maritaca igual à revisão 3; cada asa é um raminho com folhas secas serrilhadas em leque (quatro à esquerda, três à direita), o crepúsculo solto nos cinco vãos. |

`confere.lua`: 18 de 18 quadros passam. Dois pontos que o criativo deve olhar na folha: no Cratercoil o fundo entre braço e tronco é a parede de asfalto escura (o cotovelo lê pouco a 36 px) e as faixas brancas têm pouco contraste na cabeça; no Duskwreath a folha foi alargada 12% (s máx 2,0) e o raminho engrossado para o contorno caber no piso (0,28).

### Revisão 3

Cinco conceitos redesenhados; os nomes e a regra do ser de ritual não mudam. Os textos de Lore (verbetes) ficam como estão.

| Espécie | Como ficou |
|---|---|
| Gatewarden | em três quartos, sobre quatro patas de vergalhão (exceção pedida: o besouro tem seis), cabeça e chifre à vista; os élitros erguidos são as duas folhas do portão, abertas para o lado, com a limalha no vão. |
| Cratercoil | meio corpo para fora de um buraco aberto no asfalto, mãos no chão, boca aberta com a brasa; rachaduras planas em volta, sem borda nem degrau. |
| Duskwreath | a maritaca grande, na frente; as asas de folha seca sobem atrás em dois braços que não se fecham, uma coroa quebrada, com o crepúsculo entre as folhas. |
| Cairnhollow | um terço da bola aberto como geodo partido, coroa de cristal acesa e fundo escuro; a cabeça e as garras saem pela abertura. |
| Vigilwick | o nicho em arco fica escuro; dentro, só a chama da vela. |

- Folha da revisão: `docs/art/conceitos/rituais/rituais_revisao.png` (6 colunas: as três finais, as quatro aprovadas e as cinco refeitas).
- Conferência (`confere.lua`): 18 de 18 quadros passam.
- A 36 px, ainda não lidos como pedido: Gatewarden (a limalha forma uma faixa de chuvisco, não a cunha clara aberta para a esquerda) e Cairnhollow (o C de cristal é fraco de noite, emissivo 0,12, e a cabeça ocupa boa parte da abertura de dia).

### Revisão 2 (decisão do dono sobre a primeira folha)

- **Aprovadas, sem mudança:** Stormlamp, Noonglass e Eaveshroud. O disco no centro do corpo fica só nessas três.
- **Refeitas, sem disco e sem pedestal** (a criatura fica no chão ou presa no próprio objeto):

| Espécie | Como era | Como ficou |
|---|---|---|
| Staticroost | tela redonda de Estática no papo | o pombo estufado é o mesmo; as penas do peito e do pescoço se desfazem em Estática, mais densa para a frente, e o chuvisco continua solto no ar. Segue na placa. |
| Gatewarden | rosácea no élitro, de perfil, sobre um capitel | de pé como mourão, visto pelas costas, no chão; os dois élitros são folhas de portão com lanças, entreabertas, e a limalha gira no vão entre elas. |
| Cairnhollow | oco redondo de geodo, sobre um monte de entulho | a bola no chão, com uma rachadura em zigue-zague de cima a baixo; por ela saem a cabeça (de olho fechado) e as duas mãos de garras, com o cristal aceso por dentro. |
| Vigilwick | nicho redondo, cabeça e corpo num vulto só, sobre névoa | silhueta de buraqueira (cabeça chata e larga, pernas compridas, rabo curto) no montinho de terra da toca; o nicho é um arco ogival. |
| Duskwreath | a maritaca ao lado de um aro com o sol dentro, num toco | a maritaca de pé dentro da guirlanda: onze folhas que saem dos ombros e dão a volta no corpo; a luz é a nervura de cada folha e o ponto claro entre uma e outra. |
| Cratercoil | enrolado em roda, visto de cima, com o meteoro no meio | de perfil, baixo, arqueado sobre a borda da cratera, cabeça erguida e boca aberta; o rosa está na boca, nas escamas das costelas e nas rachaduras da borda. |

- Folha da revisão: `docs/art/conceitos/rituais/rituais_revisao.png` (as três aprovadas e as seis refeitas).
- Folha: `docs/art/conceitos/rituais/rituais.png` (as três atuais com a arte final e as nove novas; por espécie, de cima para baixo: mapa a 4× de noite, mapa a 4× de dia, retrato a 2× de noite, retrato a 2× de dia).
- Fontes: `tools/art/creatures/conceitos/rituais/<nome>/build.lua` (um por criatura), o ajudante `_ritual.lua`, `folha.lua` (monta a folha) e `confere.lua` (régua, margens e peças soltas dos 18 quadros).
- Rodar (MCP do Aseprite): `KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/rituais/confere.lua')` e depois `.../folha.lua`.

### As nove

| Família | Nome proposto | O que ela é | O altar e o que tem dentro | Condição do mundo (GDD, "Onde e quando") |
|---|---|---|---|---|
| Hum (Elétrico, Ozongon) | **Stormlamp** | A mariposa pousada, de asas fechadas em delta e os dois ocelos de pálpebra baixa. | O tórax é um globo de lâmpada de rua (aro de cobre, isoladores de porcelana) com o raio dentro. | Tempestade, à noite. |
| Clod (Terra) | **Cairnhollow** | Um terço da bola aberto como geodo partido, coroa de cristal acesa e fundo escuro; a cabeça e as garras saem pela abertura. | A bola rachou em zigue-zague, de cima a baixo, e o cristal de geodo está aceso por dentro. | Poeira seca. |
| Rust (Metal, Oxiayal) | **Gatewarden** | Baixo e largo, de perfil, sobre seis patas curtas, chifre rente ao chão; os élitros são duas folhas de portão abertas para trás, com a cunha de luz entre elas. | Uma cunha sólida de luz cinzenta na fresta entre as duas folhas. | Smog (ou chuva ácida). |
| Glare (Luz, Iaida) | **Noonglass** | O beija-flor-tesoura pousado num vergalhão, de olho fechado, a asa de caco fechada e a tesoura pendendo. | O peito é uma lente de farol com o sol do meio-dia dentro. | Sol forte, de dia. |
| Shade (Sombra, Ors no texto) | **Eaveshroud** | O morcego-da-cara-branca pendurado na marquise, embrulhado nas asas, de olhos fechados. | A sombra entrou no embrulho: onde as asas se cruzam abriu um Sol Negro, disco escuro com a coroa acesa. | Noite nublada (ou Sol Negro). |
| Wisp (Espectral, Teloch) | **Vigilwick** | O nicho em arco fica escuro; dentro, só a chama da vela. | No rosto, um nicho de oratório em arco ogival com um toco de vela aceso; a cera escorre pelo peito. | Neblina (ou Procissão). |
| Bit (Digital) | **Staticroost** | O pombo estufado no alto de uma placa, de cabeça encolhida, com a faixa de glitch no dorso. | As penas do peito e do pescoço se desfazem em Estática, sem borda, e o chuvisco sai solto para a frente. | Estática. |
| Sprig (Feérico) | **Duskwreath** | A maritaca grande, na frente; cada asa é um raminho com folhas secas serrilhadas em leque, abertas atrás do corpo. | O crepúsculo solto no vão entre as folhas, a nervura de cada folha e um ponto claro em cada forquilha. | Crepúsculo real, na lua cheia. |
| Wyrm (Dracônico, Vovina) | **Cratercoil** | Até o peito para fora do buraco, patas da frente dobradas no cotovelo, mãos de garras fora; faixas pretas e brancas; língua bífida. | A língua, a frincha da boca, as divisas rosa de 1 px e o início das rachaduras. | Eclipse (Sol Negro), chuva de meteoros ou cicatriz de Fenda. |

Nomes alternativos, se o dono preferir: Hum `Thunderbulb`, Clod `Dustgeode`, Rust `Rosegrate`, Glare `Sunlens`, Shade `Eclipsecowl`, Wisp `Nichelight`, Bit `Noisenest`, Sprig `Gloamwreath`, Wyrm `Scarcoil`.

### Receitas propostas

No formato do `rituals.json`: uma condição, três espaços de material (o material da família, a Essência do tipo, um terceiro item) e o Círculo com `min_level` 5, como as três atuais. Todos os ids existem em `items.json`.

O `rituals.json` de hoje só aceita **uma** condição, dos tipos `hour`, `biome`, `moon` e `weather`, e o `weather` só conhece `clear`, `cloudy`, `rain` e `storm` (`app/lib/crafting/ritual_data.dart`). A coluna "ideal" usa ids que existem em `epochs.json` (`climate.climates` e `climate.events`), mas que o ritual ainda não lê; a coluna "gravável hoje" é o que entra sem código novo.

| Espécie | Condição ideal | Gravável hoje | Materiais | Círculo |
|---|---|---|---|---|
| `hum.ritual` Stormlamp | clima `storm` e hora 19 a 5 (duas condições) | `{ "kind": "weather", "value": "storm" }` | `item.glass_shard` ×2, `item.essence.electric` ×1, `item.rain_water` ×1 | `min_level` 5 |
| `clod.ritual` Cairnhollow | clima `dry_dust` | `{ "kind": "biome", "value": "green" }` | `item.chalk` ×2, `item.essence.earth` ×1, `item.ref.white_clay` ×1 | `min_level` 5 |
| `rust.ritual` Gatewarden | clima `smog` (`acid_rain` é de outra região) | `{ "kind": "biome", "value": "urban" }` | `item.scrap` ×3, `item.essence.metal` ×1, `item.ref.living_rust` ×1 | `min_level` 5 |
| `glare.ritual` Noonglass | clima `strong_sun` e hora 11 a 14 | `{ "kind": "hour", "from": 11, "to": 14 }` | `item.glass_shard` ×2, `item.essence.light` ×1, `item.prism_shard` ×1 | `min_level` 5 |
| `shade.ritual` Eaveshroud | clima `cloudy` e hora 20 a 5; ou evento `black_sun` | `{ "kind": "weather", "value": "cloudy" }` | `item.moonlight.new` ×2, `item.essence.shadow` ×1, `item.vessel.dark` ×1 | `min_level` 5 |
| `wisp.ritual` Vigilwick | clima `fog`; ou evento `fog_procession` | `{ "kind": "biome", "value": "sacred" }` | `item.ectoplasm` ×2, `item.essence.spectral` ×1, `item.vessel.candle` ×1 | `min_level` 5 |
| `bit.ritual` Staticroost | evento `static` | `{ "kind": "biome", "value": "lit" }` | `item.feather` ×2, `item.essence.digital` ×1, `item.scrap` ×1 | `min_level` 5 |
| `sprig.ritual` Duskwreath | crepúsculo real (`twilight_deg`) e lua cheia | `{ "kind": "moon", "value": "fullMoon" }` | `item.dry_leaf` ×3, `item.essence.fae` ×1, `item.ipe_flower` ×1 | `min_level` 5 |
| `wyrm.ritual` Cratercoil | evento `black_sun` ou `meteor_shower` (ou `crimson_moon`, `rift_wind`, os que já fazem o Wyrm nascer) | nenhuma serve | `item.meteorite` ×2, `item.essence.draconic` ×1, `item.rift_smoke` ×1 | `min_level` 5 (o Wyrm pede nível 10 do Conjurador) |

#### O que falta no jogo para as condições pedidas

- **Duas condições na mesma receita** (Hum: tempestade e noite; Sprig: crepúsculo e lua cheia; Glare e Shade): a receita tem um campo `condition` só.
- **Clima além dos quatro do `Weather`**: `dry_dust`, `smog`, `strong_sun`, `fog` existem em `climate.climates`, mas a condição `weather` do ritual não os enxerga.
- **Evento como condição**: `static`, `black_sun`, `meteor_shower`, `fog_procession`, `rainbow` existem em `climate.events`; não há tipo de condição para evento.
- **Crepúsculo real**: existe para o nascer dos Ecos (`conditions.twilight_deg`), não como condição de ritual; `hour` com faixa fixa é só uma aproximação.
- **Relevo** (morro do Clod, vale do Wisp): só existe na regra de nascer (`hill`, `valley`).
- **Cicatriz de Fenda**: não existe no jogo (nenhuma Fenda ainda); do que o GDD pede para o Wyrm, o que há são os eventos `black_sun`, `meteor_shower`, `crimson_moon` e `rift_wind`.
- Os ids de bioma (`urban`, `sacred`, `lit`) seguem as chaves de variante; só `green` aparece hoje numa receita, os outros precisam ser conferidos com `spawnKey` antes de gravar.

### Rascunho dos verbetes do Bestiário (substituído pelo texto final em `docs/textos-bestiario.md`)

Clod, Bit e Sprig não têm deus nos dados; os textos deles não citam nenhum.

**Stormlamp** (`hum.ritual`). Mariposa pousada, de asas fechadas, com um globo de lâmpada no lugar do tórax e a tempestade dentro.

- Lore I: Pousa de asas fechadas e não levanta mais. O tórax virou um globo de lâmpada de rua, com aro de cobre, e lá dentro um raio cai sem parar no mesmo lugar.
- Lore II: Os dois ocelos das asas estão de pálpebra baixa. Ela não procura a luz que pisca: é ela que faz o poste piscar.
- Lore III: Os ventos de Ozongon precisam de onde pousar. Na noite de tempestade, quem conta os trovões e os clarões do globo acha sempre um a mais dentro dele.

**Cairnhollow** (`clod.ritual`). Tatu-bola fechado em bola e rachado de cima a baixo, com cristal aceso na rachadura e a cabeça e as garras saindo por ela.

- Lore I: Fechou em bola e a bola rachou. Pela rachadura saem a cabeça, de olho fechado, e as duas mãos de garras; lá dentro não há tatu: há cristal, e a luz que vazava pelas juntas agora mora ali.
- Lore II: Não rola mais. Quando a poeira seca levanta, a rachadura abre um dedo e fecha de novo, como quem respira.
- Lore III: Quem põe o ouvido na rachadura não ouve o mar: ouve pedra assentando, muito devagar, como um morro que ainda está se decidindo.

**Gatewarden** (`rust.ritual`). Besouro-rinoceronte baixo e largo, com os élitros em duas folhas de portão entreabertas e uma fresta de luz entre elas.

- Lore I: Fica rente ao chão, baixo e largo, sobre seis patas curtas, o chifre apontado para a frente. Os élitros são duas folhas de portão de ferro, com as lanças viradas para trás, e nunca fecham de todo: pela fresta entre elas sai uma luz cinzenta, de ferro limado.
- Lore II: No smog, a ferrugem dele escorre até o chão e o portão mais perto amanhece sem tranca.
- Lore III: Oxiayal é o trono poderoso; todo trono tem uma porta, e toda porta tem alguém que não sai da frente dela. Ele não abre nem fecha: decide o que é dentro.

**Noonglass** (`glare.ritual`). Beija-flor-tesoura pousado, de olho fechado, com uma lente de farol no peito e o sol do meio-dia dentro.

- Lore I: O único beija-flor que alguém viu parado. Pousa num vergalhão, fecha o olho e a asa de caco, e o peito, uma lente de farol, guarda o sol do meio-dia.
- Lore II: A sombra dele é a mesma a qualquer hora: curta, bem debaixo dos pés. As três cores na ponta da cauda são o que sobra da luz depois que ela passa por ele.
- Lore III: Iaida, o altíssimo, não desce. Ao meio-dia a distância é a menor que há, e é por essa lente que ele olha.

**Eaveshroud** (`shade.ritual`). Morcego-da-cara-branca embrulhado nas asas debaixo da marquise, com um Sol Negro onde elas se cruzam.

- Lore I: Dorme embrulhado nas próprias asas, e a sombra não está mais ao lado: entrou no embrulho. Onde as asas se cruzam abriu um disco escuro com uma coroa de luz em volta.
- Lore II: De dia não deixa sombra nenhuma no chão. Debaixo da marquise dele a noite chega alguns minutos antes.
- Lore III: Os cadernos chamam de Ors a escuridão de onde a sombra vem. Os outros morcegos a carregam; este é a fresta por onde ela olha para cá, e por isso mantém os olhos fechados.

**Vigilwick** (`wisp.ritual`). Coruja-buraqueira de pé na toca, sem olhos, com um nicho de oratório em arco no rosto e um toco de vela aceso dentro.

- Lore I: As duas chamas dos olhos viraram uma só. No rosto abriu um nicho de oratório, em arco pontudo, com um toco de vela dentro, e a cera escorre pelo peito sem nunca acabar.
- Lore II: Fica de pé na neblina, em cima da própria toca, e não vira a cabeça. Quem passa por ela sente que foi contado.
- Lore III: Teloch não leva ninguém, e o Hollowkin acompanha só até a metade do caminho. A Vigilwick é a vela que fica acesa para quem ainda não chegou.

**Staticroost** (`bit.ritual`). Pombo estufado no alto de uma placa, de cabeça encolhida, com o peito se desfazendo em Estática.

- Lore I: Dorme empoleirado numa placa, estufado, a cabeça encolhida. As penas do peito e do pescoço viram chuvisco e saem para a frente sem cair, e uma faixa do dorso continua dois dedos fora do lugar.
- Lore II: Enquanto ele dorme, todo painel da quadra mostra a mesma imagem com um instante de atraso.
- Lore III: Os Tecnomantes dizem que o Bitling é transmitido. Este é o que fica quando a transmissão acaba: o canal vazio, esperando.

**Duskwreath** (`sprig.ritual`). Maritaca de pé com as asas feitas ramos de folha seca abertos em leque, o crepúsculo nos vãos.

- Lore I: As duas asas viraram ramos de folha seca, serrilhada, abertos em leque atrás do corpo, e não chegam a se fechar. Pelos vãos entre uma folha e outra passa a luz da hora em que o sol encosta no horizonte, mesmo de madrugada.
- Lore II: Não fala Aklo: fica calada, de olho fechado, e as outras maritacas se calam em volta. O pólen que cai da guirlanda não cai para baixo.
- Lore III: Dizem que as fadas antigas entravam por rodas assim. Ninguém sabe se a guirlanda é a porta ou se ela é quem ficou no meio para segurá-la aberta.

**Cratercoil** (`wyrm.ritual`). Teú atarracado saindo até o peito de um buraco no asfalto, de olho fechado e língua bífida.

- Lore I: Sai até o peito de um buraco no asfalto, as patas da frente fincadas na borda, o couro em faixas pretas e brancas. O olho está fechado; a língua bifurcada prova o ar, da cor da brasa que vaza pelas rachaduras.
- Lore II: As escamas das costelas acendem e apagam no passo da cratera, não no da respiração. Não é ele que a esquenta: é ela que o mantém.
- Lore III: Vovina é um só, e caiu em pedaços. O Cratercoil é o pedaço que não saiu do lugar onde caiu; os cadernos dizem que ele guarda o ponto, para quando os outros voltarem.

### Peças e luz

| Espécie | Pasta | Kit de cores | Luz (tipo) | Emissivo |
|---|---|---|---|---|
| Stormlamp | `stormlamp/` | `_hum.lua` | Elétrico `#B8901C`, `#FFD23A`, `#FFEE9A`; o ciano `#5fd3c6` só no ponto do meio | o halo e o raio no globo, os dois veios das asas, as costuras, as faíscas |
| Cairnhollow | `cairnhollow/` | `_clod.lua` | Terra `#7E5A32`, `#C0915A`, `#E6C594` | o cristal na rachadura, duas juntas das cintas, as costuras, a poeira |
| Gatewarden | `gatewarden/` | `_rust.lua` | Metal `#566274`, `#93A1B3`, `#CCD6E2` | a limalha no vão, a quina de dentro das duas folhas, as costuras, a limalha solta |
| Noonglass | `noonglass/` | `_glare.lua` | Luz `#CDB468`, `#FFF0B8`, `#FFFBE6`, mais o espectro (a exceção do Glare) | a lente, as três cores na cauda, as costuras, os reflexos |
| Eaveshroud | `eaveshroud/` | `_shade.lua` | Sombra `#68426E`, `#A677AB`, `#D2ABD6` | a coroa e os raios do Sol Negro (o disco é corpo, `#120D1C`), as costuras |
| Vigilwick | `vigilwick/` | `_wisp.lua` | Espectral `#8A9DBA`, `#D3E2F4`, `#F2F7FF` | a chama e a luz no nicho, o frio na boca da toca, as costuras, o frio solto |
| Staticroost | `staticroost/` | `_bit.lua` | Digital `#62A01E`, `#A8F040`, `#DCFA9E` | a Estática no peito e solta à frente, os LEDs da placa, a emenda do glitch, as costuras |
| Duskwreath | `duskwreath/` | `_sprig.lua` | Feérico `#C0669E`, `#FFA8E0`, `#FFD6F1` | a nervura de cada folha, o ponto claro entre uma folha e outra, as costuras, o pólen |
| Cratercoil | `cratercoil/` | `_wyrm.lua` | Dracônico `#8E2852`, `#DE4F84`, `#F797B6` | a brasa na boca, as escamas das costelas, as rachaduras da borda, as costuras |

Conferência (`confere.lua`), depois da revisão 2: os 18 quadros passam nos pisos do Espírito (cores, detalhe, contorno, emissivo, três cores emissivas), ficam dentro das margens e saem numa peça só.

### Exceções e pontos fracos, para a decisão do dono

- **Stormlamp de cima e simétrica**, como o Humoth e o Coilkin; o "parado" dela é só as asas fechadas.
- **Cairnhollow:** a 36 px a rachadura quase some atrás da cabeça e das garras; lê como "bola com um tatu saindo", não como "bola rachada com cristal".
- **Gatewarden:** as seis patas abertas dos lados lembram aranha; a limalha no vão é chuvisco claro, o giro só se lê no retrato.
- **Vigilwick:** o arco ogival só se lê no retrato; a 36 px é uma mancha clara alta no rosto.
- **Duskwreath:** a roda de folhas continua sendo um círculo em volta do bicho (agora é a asa, não um aro ao lado); a maritaca fica pequena dentro dela a 36 px.
- **Cratercoil:** de perfil lê como lagarto genérico em cima de uma pedra; a borda da cratera é um degrau de asfalto e pode ser lida como pedestal. Ocupa só os dois terços de baixo do quadro.
- **Staticroost:** de dia, sem o emissivo, a Estática vira um pontilhado escuro no peito, pouco legível.
- A textura dos conceitos é de ajudante (hachura por material), abaixo da arte final das três atuais; pena, escama e pelo são refeitos no kit de cada família se a espécie for aprovada.
- Acessórios das variantes, animações e a separação em `leds` e `glow` ficam para a arte final.
