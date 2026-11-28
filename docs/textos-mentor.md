# Textos do mentor e do fórum

Para revisão. **A fonte é o JSON** (`app/assets/data/mentor.json` e `forum.json`): o app lê de lá. Este arquivo é gerado por `python3 scripts/mentor_md.py`; mude o texto no JSON, rode o script e o teste confere que os dois batem. Se preferir, edite aqui e me diga o que mudou que eu passo para o JSON.

## Tom do mentor

Um dos Que Escutam, o único que ficou em silêncio, falando pelo celular como se fosse um ocultista humano. Parece benevolente e pronto para ajudar, e nunca deixa de parecer suspeito. Responde perguntas com outras perguntas, faz pedidos que não fazem sentido na hora e sabe coisas que não deveria saber. Recusa dar um nome (nomes fazem barulho). Frases curtas, sem pressa, sem exclamação. No celular aparece como **Número desconhecido**.

## Chat: Número desconhecido

O tutorial sai uma mensagem de cada vez, depois de alguns segundos de jogo com o mapa aberto (o tempo é contado desde a mensagem anterior). Uma mensagem pode esperar um acontecimento do jogo.

| # | Id | Espera | Só depois de | Texto |
| --- | --- | --- | --- | --- |
| 1 | `m01` | 20 s | - | Boa noite. Você deixava o celular gravando estática, não era? Ele ainda está ouvindo. Posso ajudar a entender o que ele escuta. Posso? |
| 2 | `m02` | 25 s | - | Não me pergunte o nome. Nomes fazem barulho. Chame-me do que quiser, menos de um nome. |
| 3 | `m03` | 30 s | - | Veja o círculo em volta de você. É a sua Aura: até onde o aparelho enxerga através do Véu. Fagulhas e Ecos só respondem lá dentro. Por que será que tudo se aproxima quando você anda? |
| 4 | `m04` | 30 s | - | As Fagulhas entram sozinhas na Aura e viram pó de Essência. Os pontos de material você precisa tocar. Quanto de você cabe numa caixinha de giz, afinal? |
| 5 | `m05` | 35 s | - | Toque num Eco dentro da Aura e escolha um selo. Depois gire o dial até a sua onda violeta cobrir a dele. O sinal dele anda, e os Ecos mais fortes andam mais depressa. Você ouve quando ele vai mudar? |
| 6 | `m06` | 25 s | - | Alinhado, o progresso sobe. Solto, cai. Aqui não existe batalha, só escuta. Quem escuta com mais calma costuma ganhar. Você tem calma? |
| 7 | `m07` | 5 s | capture ≥ 1 | Você capturou? Não é bem capturar, é? É devolver o sinal a quem o perdeu. Guarde o Ectoplasma: tudo que se escuta deixa um resto. |
| 8 | `m08` | 40 s | - | Abra a Bancada, no celular. Um selo simples é giz e ectoplasma, nada mais. Com duas Essências você faz um selo reforçado. De onde você acha que vem o giz? |
| 9 | `m09` | 40 s | - | Um Eco que você já tem pode virar Essência: é a destilação. Parece cruel? A Essência não se perde, só muda de forma. Os que estão no seu Círculo não podem ser destilados, a menos que você os tire de lá. |
| 10 | `m10` | 40 s | - | Escolha até três criaturas para o seu Círculo. Cada uma melhora o seu mapa: Aura maior, coleta mais longe, Radar mais fundo. E um tipo forte facilita a sintonia contra o tipo que ele vence. Fogo vence quem mesmo? |
| 11 | `m11` | 40 s | - | Segure o dedo sobre um Eco dentro da Aura e o sinal dele fica preso por cinco minutos. Dá tempo de fazer outra coisa. Dá tempo de se arrepender. |
| 12 | `m12` | 40 s | - | Existe um fórum, o Limen. Pedem coisas pequenas todos os dias. Faça o que pedirem, ou não. Quem pede sempre sabe o que quer? |
| 13 | `m13` | 45 s | - | Por ora é só. Se o celular tremer sozinho, não atenda. Última pergunta: quem mais anda por aí com a mesma frequência que a sua? |
| 14 | `fusion_01` | 20 s | level_6 ≥ 1 | Seis. Você anda há tempo bastante para ouvir uma coisa nova. Cinco Ecos da mesma família, mais Essência do tipo deles, cabem num molde só. O que sai não é mais um Eco. Procure a Fusão na Bancada. |
| 15 | `fusion_02` | 40 s | - | Você escolhe quais cinco entram, e eles não voltam. Se algum estiver no Círculo, a vaga fica vazia. O que nasce guarda o nível médio deles e até dois traços: o Brilhante primeiro, depois as variantes. Quem vale mais para você, o Eco ou o que ele pode virar? |

## Falas do Familiar

O Familiar ainda não fala (GDD): ele se comunica por gestos, ícones e silêncios, então as falas são **gestos entre asteriscos**. Cada uma sai sozinha, uma vez, quando o acontecimento acontece, e aparece no chat com o nome FAMILIAR.

| # | Id | Quando | Texto |
| --- | --- | --- | --- |
| 1 | `f01` | variant_seen ≥ 1 | *O Familiar inclina o corpo para a cor nova do Eco e fica parado, como quem escuta. Um chiado curto sai dele. Parece dizer: tem o lugar dentro dele.* |
| 2 | `f02` | shiny_seen ≥ 1 | *O Familiar acende por um instante, violeta e depois quase branco, e dá três voltas ao seu redor sem tocar o chão. Depois fica quieto, olhando o brilho. Parece querer que você olhe também.* |
| 3 | `f03` | hidden_revealed ≥ 1 | *O Familiar arrepia o contorno quando o Radar varre. Aponta para onde nada estava e a estática fecha atrás do dedo dele. Parece dizer: eu já sabia que estava ali.* |
| 4 | `school_best_technomancer` | school_best_technomancer ≥ 1 | *O Familiar eriça uma antena fina quando o sinal firmou na sua mão. Aponta para ela, depois para você. Parece dizer: este foi o seu melhor.* |
| 5 | `school_best_shaman` | school_best_shaman ≥ 1 | *O Familiar se abaixa e fica imóvel, igual ao Eco que parou de fugir. Ergue uma folha pequena na sua direção. Parece dizer: este foi o seu melhor.* |
| 6 | `school_best_sealer` | school_best_sealer ≥ 1 | *O Familiar passa o contorno pelo traço que você deixou no ar, como quem confere uma costura. Parece dizer: este foi o seu melhor.* |
| 7 | `school_choose_technomancer` | school_chosen_technomancer ≥ 1 | *O Familiar pisca em ciano e o corpo dele ganha linhas retas, como um circuito. Uma antena sobe e capta algo que você não ouve.* |
| 8 | `school_choose_shaman` | school_chosen_shaman ≥ 1 | *O Familiar esquenta até ficar laranja e solta uma folha de dentro de si. Ela cheira a terra molhada, mesmo em cima do asfalto.* |
| 9 | `school_choose_sealer` | school_chosen_sealer ≥ 1 | *O Familiar fica ainda mais violeta e um fio de costura o atravessa de lado a lado. Ele parece satisfeito, como quem acha a própria família.* |
| 10 | `fusion_f01` | fusion ≥ 1 | *O Familiar encosta a testa na tela quando as costuras se fecham e fica assim, parado, até o Espírito respirar. Depois dá uma volta devagar em torno dele. Parece dizer: agora são um só.* |
| 11 | `floor_f01` | map_floor_seen ≥ 1 | *O Familiar estica o contorno até quase sumir e tateia o chão, sem achar rua nenhuma. Volta encolhido e olha para você. Parece dizer: aqui o Véu está fino demais para ler as ruas.* |

## Escola no nível 3

No nível 3, na primeira sessão em que os testes ainda não foram oferecidos (também em saves que já passaram do nível), o mentor manda o convite aos três testes, com um botão que abre os testes no Chat. Sai uma vez só. Depois de escolher, o mentor comenta e o Familiar reage (`school_choose_*`). O comentário do Familiar sobre o teste em que o jogador foi melhor (`school_best_*`) aparece na tela de escolha.

| Id | Quando | Botão | Texto |
| --- | --- | --- | --- |
| `school_tests` | nível ≥ 3 e testes ainda não oferecidos | `school_tests` | Você já anda pelo Véu sem tropeçar. Falta escolher o jeito de andar. Preparei três testes curtos, um de cada escola: sinal, calma e sigilo. Faça todos, na ordem que quiser, quantas vezes quiser. Eu não tenho preferência. Isso deveria te preocupar. |
| `school_after` | school_chosen ≥ 1 | - | Está feito. A escola agora te molda, e não volta tão fácil. Só bem mais tarde alguém fala em desfazer isso. Eu falaria, mas não agora. Faça valer. |
## Mensagens do mentor por acontecimento (ritual)

Saem sozinhas, uma vez cada, quando o acontecimento acontece, sem esperar a fila do tutorial (lista `event_messages` do JSON). `ritual_teach` sai ao chegar no nível do ritual (8); as dicas, na primeira vez que o jogador vê um Eco de ritual da família.

| Id | Quando | Texto |
| --- | --- | --- |
| `ritual_teach` (mentor) | ritual_unlocked ≥ 1 | Algumas coisas não respondem ao dial. Não ouvem sinal nenhum. Para elas existe o ritual: um círculo, materiais, a hora certa e alguém seu ao lado. Se errar, elas vão embora e o que você pôs se perde. Quem já se aproximou de algo que não escuta? |
| `ritual_hint_soot` (mentor) | ritual_seen_soot ≥ 1 | Aquela brasa que você viu não é um Eco. Kilnshade só se deixa chamar quando o dia já esfriou. O que arde precisa de alguém que o apague, não? |
| `ritual_hint_frond` (mentor) | ritual_seen_frond ≥ 1 | Rootseer não se mexe por sintonia. Ela escuta onde o chão ainda é verde. Quem queima o mato aprende a respeitá-lo. Você olhou o que cresce debaixo do concreto? |
| `ritual_hint_rill` (mentor) | ritual_seen_rill ≥ 1 | Wellmirror só se mostra quando a luz da noite está inteira. Água se espelha, mas a raiz bebe até o fundo. Você anda de noite? |
| `ritual_hint_hum` (mentor) | ritual_seen_hum ≥ 1 | Stormlamp não acende em noite limpa: ela espera a hora em que o céu inteiro pisca junto com o poste. Você sai de casa quando troveja? |
| `ritual_hint_glare` (mentor) | ritual_seen_glare ≥ 1 | Noonglass só pousa quando a sombra some debaixo dos pés e o sol pesa, ou quando a luz se abre em cores depois da chuva. Você já olhou para cima na hora em que ninguém olha? |
| `ritual_hint_shade` (mentor) | ritual_seen_shade ≥ 1 | Eaveshroud pede uma noite de céu tampado, sem estrela nenhuma, ou então o dia em que o sol escurece no meio. Você saberia dizer qual dos dois é mais escuro? |
| `ritual_hint_bit` (mentor) | ritual_seen_bit ≥ 1 | Staticroost não vem com tempo bom nem com tempo ruim: vem quando o ar chia e a tela do seu celular começa a falhar. Nessa hora você guarda o aparelho, ou fica olhando o chuvisco? |
| `ritual_hint_wisp` (mentor) | ritual_seen_wisp ≥ 1 | Vigilwick só se acende quando não dá para ver o fim da rua, ou na noite em que a neblina anda em fila. Você já parou para deixar alguém passar sem ver quem era? |
| `ritual_hint_clod` (mentor) | ritual_seen_clod ≥ 1 | Cairnhollow só abre quando a terra está com sede e o vento levanta o chão. Você reparou em que época a cidade fica com gosto de poeira? |
| `ritual_hint_sprig` (mentor) | ritual_seen_sprig ≥ 1 | Duskwreath tem duas chaves, e as duas viram juntas: o sol encostando no horizonte e a lua subindo inteira do outro lado. Quantas tardes dessas você acha que cabem num mês? |
| `ritual_hint_wyrm` (mentor) | ritual_seen_wyrm ≥ 1 | Cratercoil não sobe por qualquer céu: só quando o sol se apaga de dia, ou quando a noite risca pedra caindo. O que caiu uma vez gosta de ver cair de novo, não? |
| `ritual_hint_rust` (mentor) | ritual_seen_rust ≥ 1 | Gatewarden só se deixa chamar quando o ar da cidade fica grosso e cinzento, com gosto de ferro. Você já reparou no portão que amanhece aberto depois de um dia assim? |
| `major_hint_soot` (mentor) | major_seen_soot ≥ 1 | Aquilo é Slagthroat: a tampa do bueiro com três pescoços, e o fogo pingando das bocas. O dial não a segura, só um ritual. Ou você a faz: três Cinderkin fundidos, com um Kilnshade de oferenda. Você daria o forno para ter o incêndio? |
| `major_hint_frond` (mentor) | major_seen_frond ≥ 1 | Slabwhorl é a calçada inteira de pé, rachada em caracol. Não se sintoniza uma calçada: prende-se por ritual, ou se funde de três Thicketkin com uma Rootseer entregue em oferenda. Você entregaria quem ficou olhando? |
| `major_hint_rill` (mentor) | major_seen_rill ≥ 1 | Gutterjaw: a boca é a boca de lobo, e os olhos ficam atrás da grade. Só o ritual o prende. O outro caminho é a fusão, três Brookkin e um Wellmirror de oferenda. Você devolveria a lua ao poço? |
| `major_hint_hum` (mentor) | major_seen_hum ≥ 1 | Pylonward é o poste do bairro com uma boca aberta no transformador. Sintonia nenhuma a alcança: é ritual, ou a fusão de três Coilkin com uma Stormlamp em oferenda. Você apagaria uma lâmpada para acender a rua inteira? |
| `major_hint_clod` (mentor) | major_seen_clod ≥ 1 | Rubblebrood é uma bola de entulho que não abre, com três cabeças saindo por onde não há porta. O dial escorrega nela. Prende-se por ritual, ou se funde de três Bouldkin com um Cairnhollow de oferenda. O que você faz com uma coisa que não abre? |
| `major_hint_rust` (mentor) | major_seen_rust ≥ 1 | Hingeback: as asas são as duas folhas de um portão, e quem o segura são vergalhões que saem do chão. Só se prende por ritual. Ou por fusão, três Gratekin e um Gatewarden em oferenda. Você abriria mão do porteiro para ter o portão? |
| `major_hint_glare` (mentor) | major_seen_glare ≥ 1 | Hourpane tem três vidraças, e cada uma guarda uma hora do céu. Não há frequência que sirva às três: é ritual, ou a fusão de três Prismkin com um Noonglass de oferenda. Em qual das três horas você pretende chegar? |
| `major_hint_shade` (mentor) | major_seen_shade ≥ 1 | Awninghang é a marquise inteira: o corpo pendurado embaixo, a sombra pousada em cima. A sintonia pega um dos dois, nunca os dois. Prende-se por ritual, ou se funde de três Shadekin com um Eaveshroud de oferenda. Qual dos dois você acha que manda? |
| `major_hint_wisp` (mentor) | major_seen_wisp ≥ 1 | Tallowshrine é um velário que ficou de pé, com a chama queimando para baixo. Não se sintoniza: chama-se por ritual, ou se funde de três Hollowkin com uma Vigilwick em oferenda. Você apagaria a vela de quem ainda não chegou? |
| `major_hint_bit` (mentor) | major_seen_bit ≥ 1 | Lagflock parece um bando e é um pombo só, com três atrasos dele atrás. O dial acerta sempre a cópia errada. Só se prende por ritual, ou pela fusão de três Glitchkin com um Staticroost de oferenda. Você saberia dizer qual deles é o de agora? |
| `major_hint_sprig` (mentor) | major_seen_sprig ≥ 1 | Clamorwing é um bando que virou um corpo só, com quatro cabeças gritando. Não há dial que acompanhe quatro vozes. Prende-se por ritual, ou se funde de três Fairkin com uma Duskwreath em oferenda. Você daria a que ficou calada para ter as que gritam? |
| `major_hint_wyrm` (mentor) | major_seen_wyrm ≥ 1 | Roadbreach nada no asfalto como peixe em rio e não abre buraco. Não se sintoniza o que está debaixo da rua: é ritual, ou a fusão de três Wyrmkin com um Cratercoil de oferenda. Você tiraria do buraco o único que ficou esperando? |
| `archetype_hint_soot` (mentor) | archetype_seen_soot ≥ 1 | Você viu Darkhearth: a brasa que escurece o que está perto. Não procure selo nem círculo para isso. Ainda não existe o que o prenda. Guarde o que viu; você se lembra de que cor era o escuro? |
| `archetype_hint_frond` (mentor) | archetype_seen_frond ≥ 1 | Aquela fronde de pedra é Eldfrond, a primeira, de que as outras são cópia. Ninguém a prende, nem eu, nem os cadernos: ainda não há como. Você reparou que ela era mais pesada em cima e não caiu? |
| `archetype_hint_rill` (mentor) | archetype_seen_rill ≥ 1 | Undersky. O céu que você viu na boca dele não é o nosso: o nosso tem uma lua só. Não há ritual que o segure, por enquanto. Anote o que viu. Você contou as luas? |
| `archetype_hint_hum` (mentor) | archetype_seen_hum ≥ 1 | Levinmaw: a boca de onde o raio sai. Você viu, e isso já é raro. Prender é outra conversa, e ela ainda não começou: não existe selo nem círculo para aquilo. Você olhou para dentro do túnel, ou desviou? |
| `archetype_hint_clod` (mentor) | archetype_seen_clod ≥ 1 | Gritglass. O cascalho caía de lado, não foi? Para dentro dele. Não tente o dial nem o giz: ainda não há como prender o que não tem chão. O Bestiário guarda que você viu, e por ora isso basta. |
| `archetype_hint_rust` (mentor) | archetype_seen_rust ≥ 1 | Aquela jaula alta é Stiltcage. Está vazia e não está aberta. Ninguém sabe prender uma coisa que já é a prisão, pelo menos ainda não. Você viu se alguma pata encostava no chão? |
| `archetype_hint_glare` (mentor) | archetype_seen_glare ≥ 1 | Sunshatter: os cacos não se tocam e a forma fica. Não há selo que junte o que não quer ser juntado, e ritual também não. Por enquanto só se vê. Você conseguiu olhar sem fechar os olhos? |
| `archetype_hint_shade` (mentor) | archetype_seen_shade ≥ 1 | Você viu Gloamhusk, pendurado na própria sombra. Para prender, seria preciso saber qual dos dois segura o outro, e isso ninguém sabe ainda. Fica o registro. A sombra olhou para você? |
| `archetype_hint_wisp` (mentor) | archetype_seen_wisp ≥ 1 | Aquela roda é Waxhalo: a procissão que não chega porque anda em volta. Não se prende, ainda não; não há círculo que caiba em volta de outro círculo. Você viu para onde as chamas apontavam? |
| `archetype_hint_bit` (mentor) | archetype_seen_bit ≥ 1 | Tearframe. Você viu um pombo em três lugares e mais um dentro do peito, e todos eram o mesmo. O dial não tem onde parar, e o ritual também não: ainda não há como prendê-lo. Qual das fatias você viu primeiro? |
| `archetype_hint_sprig` (mentor) | archetype_seen_sprig ≥ 1 | Shriekwreath: seis bicos abertos e nenhum corpo no meio do anel. Não há como prender isso ainda, e desconfio de quem diz que sabe. Fica o que você viu. Você ouviu alguma coisa, ou só achou que ouviu? |
| `archetype_hint_wyrm` (mentor) | archetype_seen_wyrm ≥ 1 | Scalecorona. Uma coroa em volta de nada: um eclipse sem sol nem lua. Você viu, e pouca gente viu. Prender, ninguém prende ainda; nem selo, nem ritual. Você notou que as brasas caíam para dentro? |
| `ritual_first` (Familiar) | ritual_done ≥ 1 | *O Familiar anda uma vez em volta do desenho que se fechou, devagar, como quem confere uma costura. Depois se senta no centro, onde a criatura estava. Parece dizer: ainda está quente.* |
| `radar_gift` (mentor) | level_5 ≥ 1 | Cinco. Você já ouve o que está perto. Deixei uma coisa no seu celular: o Radar. Um pulso, e o que está longe responde, por dois minutos, na beira da tela. Depois some. Você acha que só você ouve o pulso? |
| `page_components` (mentor) | refine ≥ 3 | Você anda deixando giz ao relento. Eu vi. O que se refina sozinho ainda é pouco: junto, e com Essência, vira outra coisa. Deixei uma página no seu grimório. A Bancada de casa sabe o resto. Você sabe o que está montando? |
| `page_moon` (mentor) | craft_tut_done ≥ 1 | Uma garrafa cheia. Bonito. A lua também cabe num frasco, se o vidro for escuro e a noite for inteira. Cada fase guarda uma coisa diferente, e nenhuma delas é luz. Mandei a página. O que você acha que a lua nova esconde? |
| `page_seasons` (mentor) | component ≥ 5 | A cidade troca de pele quatro vezes por ano e quase ninguém repara. Há coisas que só se fazem numa estação, e elas esperam um ano inteiro por quem perdeu a hora. Deixei a página das estações. Em que estação você está, mesmo? |
| `page_gear` (mentor) | level_8 ≥ 1 | Bolsa cheia. Acontece com quem pega tudo o que brilha. Dá para costurar uma maior, e um cinto, e mais do que isso. A página já está no grimório. Quanto de cidade você pretende carregar? |
| `page_vehicle_light` (mentor) | level_6 ≥ 1 | Vi você passar depressa. O Véu não gosta de pressa, mas gosta de quem passa bem. Deixei uma página no grimório: nela cabem duas rodas e também quatro, menores. Não levam a lugar nenhum que os seus pés não levem. Então para que servem? |
| `page_vehicle_cart` (mentor) | level_11 ≥ 1 | Há ruas que passam por você, e não o contrário. Para elas existe uma carroça. Nada a puxa, e é melhor não perguntar o quê. A página está no grimório. Ela não rende nada, só te mostra. Quem você quer que te veja passando? |
| `craft_tut_start` (mentor) | craft_tut_start ≥ 1 | Caco de vidro. Todo mundo desvia. Dois desses, refundidos, voltam a ser garrafa, e garrafa guarda o que cai do céu. Faça uma na Bancada. O que você guardaria, se desse para guardar o tempo? |
| `craft_tut_bottle` (mentor) | craft_tut_bottle ≥ 1 | Uma garrafa vazia. Na bolsa ela só ocupa lugar. Abra a Bolsa, na aba Condições, e ponha a garrafa no cinto. Vazio também se carrega, não? |
| `craft_tut_belt` (mentor) | craft_tut_belt ≥ 1 | Agora ela anda com você. Quando chover, enche sozinha, no seu passo. Se o céu demorar, plante a garrafa no chão e volte depois: ela espera melhor do que você. Você sabe esperar? |
| `craft_tut_fill` (mentor) | craft_tut_fill ≥ 1 | Pronto. O céu faz o resto. Água que não tocou o chão ainda lembra de onde veio, e a Bancada sabe a diferença. Quando a garrafa estiver cheia, faça uma receita com essa água. O que você acha que a chuva sabe? |
| `craft_tut_done` (mentor) | craft_tut_done ≥ 1 | Feito. Você pegou uma coisa do céu e fez outra com as mãos. Há mais para guardar: neve, fumaça, a lua, cada uma no seu vidro. A cidade chove para todo mundo. Quem mais você acha que está guardando? |

## Falas de desbloqueio do celular

Quando um app novo do celular se forma (o nível do Conjurador liberou), o Familiar comenta num balão dentro do celular. Os apps de nível 1 já vêm abertos e não têm fala.

| App | Texto |
| --- | --- |
| `radar` | *O Familiar encosta no ícone novo e uma onda fraca sai dele, em círculo. Parece dizer: agora eu alcanço mais longe.* |
| `bench` | *O Familiar rodeia o ícone novo e solta um estalo seco, como giz riscando pedra. Parece dizer: aqui se faz coisa.* |
| `chat` | *O Familiar vira o rosto para o ícone novo e fica imóvel. A tela pisca uma vez, sem som. Parece dizer: alguém está do outro lado.* |
| `forum` | *O Familiar espia o ícone novo por cima do seu ombro e bate de leve na tela, duas vezes. Parece dizer: tem gente pedindo.* |

## Fusão (nível 6)

O mentor ensina a fusão quando o Conjurador chega ao nível 6 (evento `level_6`): cinco Ecos da mesma família mais Essência do tipo viram o Espírito da família. O Familiar comenta a primeira fusão. Estas são as falas, também listadas nas tabelas acima.

| Id | Quando | Texto |
| --- | --- | --- |
| `fusion_01` | level_6 ≥ 1 | Seis. Você anda há tempo bastante para ouvir uma coisa nova. Cinco Ecos da mesma família, mais Essência do tipo deles, cabem num molde só. O que sai não é mais um Eco. Procure a Fusão na Bancada. |
| `fusion_02` | depois da anterior | Você escolhe quais cinco entram, e eles não voltam. Se algum estiver no Círculo, a vaga fica vazia. O que nasce guarda o nível médio deles e até dois traços: o Brilhante primeiro, depois as variantes. Quem vale mais para você, o Eco ou o que ele pode virar? |
| `fusion_f01` | fusion ≥ 1 | *O Familiar encosta a testa na tela quando as costuras se fecham e fica assim, parado, até o Espírito respirar. Depois dá uma volta devagar em torno dele. Parece dizer: agora são um só.* |

## Rádio do Véu

Falas curtas, em rodízio, no painel do Modo Viagem em moto, carro e ônibus, para quem vai de passageiro. Quem dirige não ouve o rádio. As falas do Familiar continuam sendo gestos.

| Id | Quem | Texto |
| --- | --- | --- |
| `radio_01` | mentor | A cidade passa mais depressa que o Véu. Quem acompanha quem? |
| `radio_02` | mentor | Não olhe para mim. Olhe pela janela. Alguém acenou de volta? |
| `radio_03` | Familiar | *O Familiar encosta o contorno no vidro e deixa um chiado baixo, igual ao do motor.* |
| `radio_04` | mentor | Tem um sinal andando na mesma velocidade que você. Faz tempo. Isso te incomoda? |
| `radio_05` | mentor | Eu guardo o que passar perto. Você só precisa chegar. Consegue não fazer nada? |
| `radio_06` | Familiar | *O Familiar conta alguma coisa nos postes, um a um, e perde a conta de propósito.* |
| `radio_07` | mentor | As ruas têm mão e contramão. O Véu não. Para onde você acha que está indo? |
| `radio_08` | mentor | Este chiado é o trânsito ou sou eu? Você já sabe a resposta. |
| `radio_09` | Familiar | *O Familiar dorme de um olho só. O outro acompanha um carro que não está ali.* |
| `radio_10` | mentor | Falta pouco, ou falta tudo. Depende de quem pergunta. Quem está perguntando? |

## Mensagens com números (Patrulha e passos)

Saem pelo código, quantas vezes for preciso (lista `direct` do JSON). O resumo da Patrulha sai quando ela termina (ou quando o app abre e vê que ela acabou), com `{min}` (minutos), `{sparks}` (Fagulhas), `{materials}` (materiais) e `{marks}` (Ecos marcados). Os marcos de passos saem uma vez por dia local, ao passar de 5 mil e de 10 mil passos.

| Id | Quem | Texto |
| --- | --- | --- |
| `patrol_summary` | mentor | Patrulha encerrada. Tempo: {min} min. Fagulhas: {sparks}. Materiais: {materials}. Ecos presos ao seu sinal: {marks}. A cidade nem percebeu. Ou percebeu e ficou quieta? |
| `steps_5k` | Familiar | *O Familiar bate no chão cinco vezes com a ponta do contorno e encosta no seu tornozelo. Parece dizer: cinco mil passos hoje, e o chão lembra de cada um.* |
| `steps_10k` | Familiar | *O Familiar se deita atravessado no caminho e só levanta quando você para também. Dez mil passos. Parece dizer: chega por hoje, ou ainda não?* |
| `craft_tut_gift` | mentor | Você abriu o cinto e não tinha o que pôr nele. Deixei uma garrafa na sua bolsa. Não agradeça, é só vidro. As próximas você faz: dois Cacos de vidro, na Bancada. O que você pretende guardar nela? |

## Fórum Limen: pedidos diários

Três pedidos por dia, sorteados por `hash(seed, época, data, slot)`. O texto tem `{n}` (a meta), `{tipo}` (Fogo, Planta, Água ou qualquer tipo) e `{item}` (giz, ervas, água pura). Usuários: `vesper`, `static_saint`, `mapmaker`, `null_hypothesis`, `candlewick`, `wren_`.

### `walk` · explorar · mapmaker
Conta o evento `walk_m`, meta de 500 a 1500 (cresce com o nível). Recompensa: 150 XP e 1× `item.chalk`.

- alguém consegue andar uns {n} m por aí hoje? preciso saber se o sinal muda de um quarteirão para o outro.
- mapa novo pela metade. quem sai de casa hoje e anda {n} m me ajuda a conferir as bordas.

### `sparks` · coletar · static_saint
Conta o evento `spark`, meta de 5 a 12 (cresce com o nível). Recompensa: 150 XP e 1× `item.dust.fire`.

- preciso de {n:fagulha} de {tipo}. pago bem, e não, não vou dizer para quê.
- {n:fagulha} de {tipo} até o fim do dia. o que sobrar eu devolvo.

### `materials` · coletar · candlewick
Conta o evento `material`, meta de 2 a 5 (cresce com o nível). Recompensa: 150 XP e 1× `item.ectoplasm`.

- preciso de {n} de {item}, do tipo que se colhe andando e não do que se compra. alguém?
- quem traz {n} de {item}? é para uma vela, e a vela não pergunta de onde veio.

### `hunt` · cacar · wren_
Conta o evento `capture`, meta de 1 a 3 (cresce com o nível). Recompensa: 180 XP e 1× `item.seal.simple`.

- quero ver {n:sintonia} com um Eco de {tipo} hoje. alguém topa e conta como foi?
- apostei com o meu Familiar que ninguém aqui sela {n:Eco} de {tipo} antes de escurecer.

### `craft_seal` · casa · vesper
Conta o evento `craft`, meta de 1 a 2 (cresce com o nível). Recompensa: 150 XP e 1× `item.chalk`, 1× `item.ectoplasm`.

- se estiver chovendo: fabriquem {n:selo simples|selos simples} e me digam se o giz risca diferente.
- dia de ficar em casa? então faça {n:selo simples|selos simples}. ninguém precisa sair para isso.

### `craft_tonic` · casa · null_hypothesis
Conta o evento `craft`, meta de 1 a 1 (cresce com o nível). Recompensa: 150 XP e 1× `item.herbs`.

- alguém faz {n:tônico de foco} e me diz se o tempo extra é placebo? eu acho que é só placebo.
- pedido de cético: {n:tônico de foco}, e um relato honesto sobre os 5 segundos a mais.

### `distill` · casa · candlewick
Conta o evento `distill`, meta de 1 a 1 (cresce com o nível). Recompensa: 160 XP e 1× `item.dust.plant`.

- pergunta moral, sem resposta certa: destilar {n:Eco} que não está no Círculo. como foi?
- destilem {n:Eco} e contem o que sentiram. eu sei o que penso, quero saber o que vocês pensam.
