# Kenoma: Veilbreakers · GDD

Sep 25, 2026 · @Yuri

## Visão geral

RPG mobile de exploração no mundo real via GPS, em pixel art 2D, onde a cidade do jogador vira um cenário de fantasia urbana invadido por entidades que vazam de Fendas na realidade. O título é Kenoma: Veilbreakers.

O jogador é um Conjurador, um jovem entusiasta de ocultismo cujo celular foi tocado pela magia quando as Fendas se abriram. Ele caminha pela cidade, coleta materiais conforme o ambiente real, fabrica o próprio arsenal, captura e funde criaturas, e evolui como personagem próprio.

### Pilares

- O mundo real define o jogo. Bioma, horário, fase da lua e clima reais mudam o que aparece.
- Nada se compra com dinheiro. Tudo se fabrica ou se troca com o Mercador Errante.
- O Conjurador importa tanto quanto as criaturas.
- Atmosfera de mistério e ocultismo, sombria mas acessível.

### Restrições de projeto

- Quase 100% offline. Rede só para atualização do app, clima e eventos opcionais.
- Sem servidor pago. Toda geração é procedural e determinística no aparelho.
- Público inicial é o autor e amigos. Anti-cheat e segurança física não são foco agora.
- Stack prevista em Flutter, com Flame para mapa e minigames.

## Lore

Este GDD trata só de mecânica. Todo o lore, incluindo cosmologia, linhagem, personagens, os Trinta, Soberanos e o arco narrativo dos quatro atos, está em Kenoma · Bíblia da franquia.

## Core loop

O ciclo alterna rua e casa. Na rua o jogador explora, coleta e captura. Em casa, à noite, ele destila, fabrica, funde e se prepara. Um alimenta o outro, e o que circula entre os dois é Essência.

1. Caminhar pela cidade revelando o mapa e seguindo rastros.
2. Coletar materiais conforme o bioma, horário e clima.
3. Sintonizar e capturar criaturas usando selos fabricados.
4. À noite, em casa, destilar o excedente em Essência, fabricar, fundir, ajustar o Círculo e a build e montar lures.
5. Entrar em Incursões (dungeons e núcleos de Fenda) e selar Fendas para obter grimórios, artefatos e materiais raros.
6. Evoluir Conjurador e criaturas, liberando novas áreas de conteúdo.

Sessões de rua devem ser curtas (sintonias de 5 a 20 segundos). A profundidade estratégica fica em casa, o que também mantém o jogo interessante em dias em que o jogador não sai.

## Ritmos e longo prazo

O jogo precisa sustentar cinco anos ou mais. A progressão vertical, o nível do Conjurador, termina em poucos meses. Dali em diante o crescimento é horizontal, no estilo do Guild Wars 1 e 2: maestrias, coleções, cosméticos, sazonais e conteúdo novo de panteões. Nenhuma atualização obriga a refazer o que já foi conquistado. A regra da casa é jogar de dia e organizar à noite.

| Ritmo | O que acontece |
| --- | --- |
| Sessão, minutos | andar, coletar, sintonizar, marcar |
| Dia | diárias do fórum na rua; à noite em casa destilar, fabricar, organizar Bolsa e Armazém, ajustar a build, montar lures e expedições |
| Semana | semanal do mentor, rumor, tributo do pacto, vínculos, ciclo de uma Fenda |
| Mês | ciclo lunar completo e suas receitas, Lua Carmim, Lendas Urbanas amadurecendo |
| 3 meses | estação do ano com amuletos e cosméticos exclusivos, primeiras temporadas de panteão, nível 40 para quem joga todo dia |
| 6 meses | especialização avançada, primeiras grandes obras, Soberanos em dificuldade alta, pactos de favor alto |
| 1 ano | ciclo completo de estações e do calendário de eventos, primeiro Avatar, maestrias intermediárias |
| 2 anos | coleções de variantes e Brilhantes, várias Divindades, amuletos sazonais de segundo ciclo |
| 5 anos | maestrias máximas, cidade inteira purificada, amuletos de quinto ciclo, títulos lendários |

Amuletos sazonais evoluem por ciclo. O amuleto de verão do primeiro ano, com materiais do verão seguinte, vira a versão de segundo ciclo, e assim até o quinto, com visual novo a cada ciclo. O calendário real vira o eixo do longo prazo, e as temporadas de panteões externos continuam acrescentando conteúdo.

## Tutorial e primeiros níveis

O tutorial é a história da primeira noite, contada pelo próprio celular. Não há telas de tutorial genéricas: tudo chega como fala do Familiar, mensagem no chat ou post no fórum. Três vozes dividem o ensino. O Familiar ensina o mapa e a captura, o mentor misterioso ensina crafting, escolas e a história, e o fórum ensina a rotina.

| Nível | Momento | Quem ensina | O que libera |
| --- | --- | --- | --- |
| 1 | a noite das Fendas, o celular glitcha e o Familiar desperta | Familiar | Visão espectral, Aura, coleta de Fagulhas |
| 1 | primeira sintonia, com um Eco sem resistência e um selo de presente | Familiar | sintonia, bestiário |
| 2 | um número desconhecido manda a primeira mensagem | mentor | bancada, selo simples, destilação |
| 2 | primeiro post pedindo ajuda no fórum | fórum | diárias do fórum |
| 3 | o mentor propõe três testes, um de cada escola | mentor e Familiar | escolha da escola, o Familiar muda de forma |
| 4 | primeira criatura com resistência e primeira marcação | Familiar | leitura de tipos, marcação |
| 5 | o mentor pede um lugar seguro | mentor | definição da casa |
| 6 a 10 | primeiro ritual, Círculo completo, primeira Constelação | mentor e fórum | ritual básico, Círculo, Constelações |

Os três testes do nível 3 são curtos e feitos no mapa. No do Tecnomante o jogador estabiliza um sinal com um gadget improvisado, no do Xamã acalma uma criatura arisca até ela se aproximar, e no do Selador desenha um sigilo para prender um Eco. O Familiar comenta em qual teste o jogador foi melhor, mas a escolha é livre. Os testes são cenas roteirizadas e não dependem dos sistemas completos de gadget e sigilo.

## Fundação: o ciclo da Essência

Tudo no jogo é Essência que atravessou o Véu, e cada sistema só muda o estado dela. Esse é o eixo que amarra os demais sistemas.

| Estado | O que é | Como chega aqui |
| --- | --- | --- |
| Solta | criaturas e Fagulhas no mapa, Fendas | spawn |
| Selada | criatura capturada, no Círculo ou guardada | sintonia, ritual, vínculo |
| Destilada | Essência pura, material de crafting | destilação na bancada |
| Vinculada | poder emprestado de uma entidade que não é do jogador | pacto |

Toda captura vira uma decisão. A criatura pode ficar no Círculo como ferramenta, ser fundida para subir de camada, ser destilada em material ou servir de oferenda num ritual ou pacto.

### Três recursos

| Recurso | Vem de | Serve para | Pode ser perdido |
| --- | --- | --- | --- |
| Essência | Fagulhas, destilação, Fendas, Soberanos | fusão, estabilidade, crafting, rituais, tributos | sim, é gasto |
| Conhecimento | bestiário, páginas de grimório, reputação | métodos, espaços de ritual, receitas, dimensões | não, é permanente |
| Exposição ao Véu | magia, pactos, Fendas, noite | poder e percepção maiores | é um risco, sobe e desce |

Cada sistema é uma troca entre esses três. Crafting troca Essência por ferramentas, ritual troca Essência e Conhecimento por criaturas, pacto troca Exposição e tributos por poder, Fendas trocam risco por Essência rara e Conhecimento. Uma ideia nova só entra no jogo se responder qual desses recursos ela gera, gasta ou converte.

### Destilação

Na bancada ou em campo, como improviso, uma criatura vira Essência. Quanto mais alta a camada, mais rara a saída, e graus de estabilidade multiplicam a quantidade.

| Origem | Rende |
| --- | --- |
| Fagulha | Pó de Essência do tipo, direto na coleta, sem bancada |
| Eco | Essência do tipo, 3 a 5 conforme o nível |
| Espírito | Essência da família, 5 a 10, e chance de Fragmento de traço |
| Entidade Maior | Essência concentrada e o Núcleo da espécie, peça única para grandes obras |
| Arquétipo | Relíquia de mito |
| Variante de bioma | Essência com o traço do bioma |
| Brilhante | Essência prismática |
| Carmesim | Essência carmesim |
| Corrompida | Essência instável, forte e arriscada no crafting |

Avatar, Familiar, Herói, Artificial e Singular não podem ser destilados.

### Divindades

Até Arquétipo a captura é real. Acima disso um deus nunca é do jogador por inteiro, e existem três relações possíveis com ele.

- Avatar, por fusão final. Uma fração do deus reconstruída a partir da própria linha de família. Entra no Círculo com a marca Divino, limite de um.
- Patrono, por pacto, só com deuses vivos dos panteões de expansão. O deus verdadeiro não entra no Círculo, ele empresta poder. No jogo base os Trinta estão mortos, e o pacto é com Entidades Maiores e Soberanos.
- Essência Divina, da contenção de Soberanos e do selamento de grandes Fendas. Material de crafting ousado, como selos de dimensão, artefatos, grimórios de panteão, rituais de mundo em escala de bairro e melhorias permanentes de Aura e scanner.

## Mundo e mapa

O mapa é desenhado proceduralmente em pixel art a partir de uma grade de biomas derivada do OpenStreetMap. Não há tiles de mapa real nem servidor de mapas.

### Biomas

Biomas comuns garantem farm em qualquer lugar da cidade. Biomas raros dão spawns especiais mas nunca são obrigatórios. Toda espécie comum pode aparecer em qualquer bioma: o bioma só aumenta o peso das espécies e materiais dele, e células sem dado no OSM usam o sorteio geral. Assim o jogo funciona em qualquer cidade, mesmo com o OSM pobre, e quem não tem acesso a um parque ou lago ainda encontra tudo, só que com menos frequência. Exclusividade por bioma fica para variantes e itens raros, nunca para espécies.

| Bioma | Origem OSM | Materiais | Tipos de criatura |
| --- | --- | --- | --- |
| Urbano | ruas, prédios | sucata, fios, vidro, giz | Metal, Elétrico, Fogo com calor real |
| Verde | parques, matas | ervas, seiva, madeira | Planta, Terra, Feérico no crepúsculo |
| Água | lagos, rios, chuva | água pura, lodo | Água |
| Iluminado | comércio, avenidas | fragmentos de luz, poeira | Luz, Fogo |
| Residencial | bairros | tecidos, restos domésticos | Sombra |
| Sagrado (raro) | igrejas, cemitérios | sal, cera, osso | Espectral |
| Fendas e cicatrizes | Fendas no mapa | escamas, brasas antigas | Dracônico |

Células com pouca informação no OSM recebem um piso mínimo de spawns genéricos.

O mapa tem duas camadas. A camada lógica é a grade de biomas em z21, que decide spawns, coleta e tudo que o determinismo cobre. A camada visual é desenhada por cima a partir da geometria real: ruas como linhas finas na largura certa, água e parques com contorno suave por autotiling, e prédios a partir da fase 1. Com a câmera perto do jogador, a grade lógica desenhada direto viraria blocos de 18 m, e as ruas são o que faz o jogador reconhecer o próprio bairro. A camada visual não muda o mundo, então pode melhorar sem quebrar o determinismo.

No jogo a câmera segue o Conjurador pela posição real, com movimento suave. A câmera nunca sai do avatar: arrastar com um dedo gira o mapa em torno dele, como no Pokémon GO, e a pinça só dá zoom numa faixa de 70 a 120 m de largura. Uma bússola volta o norte para cima, e o modo "seguir direção" gira o mapa com a bússola do celular. Câmera livre só existe no menu de debug.

### Geração determinística

Tudo que existe no mundo sai de `hash(seed_global, época, célula, janela_de_tempo)`. Spawns usam células z20, com cerca de 35 m de lado na latitude de Campinas, compatível com o erro de 5 a 15 m do GPS. Biomas usam z21 e Fendas e dungeons usam z15, com cerca de 1,1 km. Como a seed é compartilhada, amigos veem os mesmos spawns no mesmo lugar e hora sem servidor.

Spawns são individuais. Cada jogador tem a própria instância de cada criatura, então capturar não remove nada para os amigos e nenhuma recompensa é disputada, como no loot pessoal do Guild Wars 2.

Cada janela dura 20 minutos, mas cada célula tem um deslocamento próprio tirado do hash dela, com `janela = floor((t_utc + deslocamento(célula)) / 1200)`. Assim o entorno se renova aos poucos, uma célula por vez, em vez de tudo sumir no mesmo minuto, e continua idêntico para todos os amigos. A posição do spawn dentro da célula também sai do hash, para as criaturas não aparecerem alinhadas numa grade. O z20, a janela de 20 minutos e a fórmula do deslocamento são fixos. As densidades ficam na tabela da época, porque mudam o mundo.

| Parâmetro | Valor inicial | Resultado esperado |
| --- | --- | --- |
| Aura | raio de 10 m para coleta; Ecos tocáveis até 30 m e visíveis até 120 m | uma faixa de 20 m ao longo do caminho, menor que a largura de uma avenida |
| Chance de Eco por célula e janela | 10% | 6 a 10 Ecos ao alcance em 10 min andando |
| Chance de Fagulha por célula e janela | calibrada por simulação de caminhada, com Fagulhas e materiais posicionados sobre ruas, calçadas e caminhos | 20 a 30 Fagulhas e 5 a 8 materiais coletados em 10 min |
| Parado em casa | alcance de toque cobre umas 3 células | cerca de 2 Ecos por hora |
| Fendas | célula z15, sorteio diário | detalhado na fase 3 |

### Tempo, astronomia e clima

Fase da lua, nascer e pôr do sol e eclipses são calculados offline a partir de latitude, longitude e data. A noite do jogo segue o pôr do sol real.

- Lua cheia real aumenta spawns noturnos. Eclipse real abre evento raro de Fenda.
- Hora do rush traz Ecos de multidão em áreas comerciais.
- Três da manhã é a hora morta, com spawns muito raros.
- Meio-dia de sol forte enfraquece criaturas noturnas.
- À noite a Aura encolhe, criaturas noturnas ficam mais fortes e capturar exige selos melhores, mas os spawns são mais raros.

Clima vem do Open-Meteo quando há internet. Sem rede, o jogo usa clima determinístico gerado pela seed. Chuva real aumenta aquáticos e melhora a qualidade de materiais de água.

### Eventos

- Lua Carmim, com céu vermelho e criaturas noturnas raras durante o dia inteiro. Principal fonte de variantes Carmesim.
- Sol da Meia-Noite, que inverte dia e noite no mapa para quem não pode jogar à noite.
- Calendário brasileiro com eventos temáticos (Finados, Festa Junina, Carnaval, Sexta-feira 13).
- Temporadas de panteão, quando Fendas de um panteão externo ficam mais frequentes por algumas semanas.

Eventos forçados vêm de duas fontes. Um calendário embarcado no app e um JSON estático no GitHub Pages consultado quando houver internet.

### Névoa de guerra

O mapa começa encoberto e é revelado conforme o jogador anda, salvo localmente. Bairros totalmente revelados viram purificados e dão bônus permanente pequeno. Áreas reveladas também liberam expedições.

### Ley Lines

Existem Leys fixas geradas pela seed, e jogadores experientes podem criar as próprias. A Ley do jogador nasce de uma rota gravada e percorrida algumas vezes para se consolidar. A composição de biomas ao longo dela define quais criaturas atrai e quais bônus rende. Há limite de Leys por jogador, e elas enfraquecem se não forem percorridas.

### Modo trânsito

Acima de uma velocidade limite o jogo muda de regra em vez de bloquear. Coleta passivamente materiais de viagem e permite marcar criaturas para sintonizar depois.

## Criaturas

As criaturas se dividem em oito camadas que seguem o lore da fragmentação. Quanto mais baixa a camada, mais a entidade se partiu ao atravessar o Véu. São 12 tipos. A maioria deriva dos biomas, e Dracônico, Feérico e Digital vêm de condições especiais do mundo.

| Camada | Como obter | Captura | Fusão para subir | Papel |
| --- | --- | --- | --- | --- |
| Fagulhas | coletadas no mapa, sem sintonia | coletadas como recurso | não sobe, vira Pó de Essência | Pó de Essência, recurso de fusão |
| Ecos | spawn em qualquer célula | sintonia | 5 da mesma família | farm, base do time inicial |
| Espíritos | fusão ou spawn raro | sintonia ou ritual | 3 da mesma família | núcleo do time |
| Entidades Maiores | spawn raro, rumores, dungeons | ritual ou contrato | 3 mais item de grimório | habilidades únicas, pactos |
| Arquétipos | fusão, incursões em Aethyrs | vínculo ou contrato | fusão final com relíquia | figuras centrais do panteão próprio; mitos como Minotauro ou Kitsune só chegam com panteões externos |
| Divindades | Avatar por fusão final, patrono por pacto | não, só obtidas | não sobe | deuses menores, marca Divino |
| Soberanos | só dentro de Fendas | só contidos em grande ritual | não | bosses, artefatos, Essência Divina |
| Primordiais | eventos únicos, futuro | a definir | não | restos deixados por Os Que Escutam, endgame de expansão |

Cada camada define limite de nível, Poder base e teto de Traços (ver Atributos), o que torna a subida de camada sempre perceptível. A linha Dracônica é a mais longa, começando em Fagulhas que parecem só uma brasa e terminando no Avatar de Vovina, enquanto dragões inteiros só existem nas Eras Antigas e em Telocvovim.

### Atributos

Toda criatura tem os mesmos três atributos, em qualquer camada ou marca.

| Atributo | O que faz | Cresce com |
| --- | --- | --- |
| Poder | força em contenção, ritual, invasões e expedições | nível, estabilidade e camada |
| Habilidade | a habilidade de mapa da espécie, como Aura maior, revelar ocultas, coletar de outro bioma ou resistir à Exposição | nível, em faixas que mudam o efeito |
| Traços | passivos vindos de variante, bioma de captura e graus de estabilidade | estabilidade e variante |

A camada define o teto: Ecos têm até 1 traço, Espíritos 2, Entidades Maiores 3 e Arquétipos 4, e cada camada tem limite de nível próprio. As marcas modificam os atributos. Artificiais trocam Traços por módulos, Heróis, em expansão, têm Poder muito alto com Fraqueza Fatal, Avatares têm Habilidade dupla e o Familiar escala Poder pelo nível do Conjurador.

### Estabilidade

Dentro de cada camada a criatura tem três graus de estabilidade, pagos com Essência obtida destilando duplicatas, do tipo nos Ecos e da família a partir dos Espíritos. Cada grau aumenta o Poder e o terceiro libera um Traço acima do teto normal da camada. Isso dá uso a duplicatas sem obrigar fusão e cria uma decisão entre estabilizar uma criatura favorita ou juntar cópias para subir de camada.

### Famílias

Família é a linha de fusão de uma criatura, com uma forma por camada. Todas as formas são pedaços da mesma entidade original, por isso a fusão exige criaturas da mesma família. Cada família tem um tipo, e nem toda família percorre todas as camadas.

| Camada | Exemplo, família elétrica |
| --- | --- |
| Fagulha | faísca solta perto de poste |
| Eco | mariposa de luz que ronda lâmpadas |
| Espírito | criatura feita de fios desencapados |
| Entidade Maior | guardião da rede elétrica do bairro |
| Arquétipo | figura mítica do relâmpago urbano |

Meta de longo prazo é toda família chegar às camadas finais, podendo pular camadas intermediárias. Uma família pode ir de Espírito direto a Arquétipo, por exemplo. Por enquanto todas as famílias planejadas entram no jogo, mas a maioria com linha curta. Só algumas terão linha longa desde o início, o que permite testar a progressão completa cedo sem multiplicar a arte. As linhas curtas ganham camadas superiores em atualizações futuras. Variantes de bioma, Brilhante e Carmesim saem de troca de paleta sem sprite novo.

### Famílias do MVP

Três famílias com Fagulha e Eco, em triângulo de Fogo, Planta e Água. Todo bioma sorteia as três famílias, com peso 6 para a família nativa e 1 para as outras (75% contra 12,5% cada). Residencial e Vazio usam pesos iguais com densidade um pouco menor. A família de Sombra chega na fase 1. Os nomes em inglês são provisórios.

| Família | Bioma | Tipo | Fagulha | Eco | Habilidade de mapa |
| --- | --- | --- | --- | --- | --- |
| Soot | Urbano | Fogo | Ember Mote, brasa de bituca e asfalto quente | Sootling, bicho de fuligem com brasa no peito que vive em bueiros | Aura maior, +3, +5 e +8 m por faixa de nível |
| Frond | Verde | Planta | Seed Mote | Frondling, fronde fractal inspirada na Charnia que anda sobre raízes | coleta Fagulhas de mais longe, +10, +15 e +20 m |
| Rill | Água | Água | Drip Mote | Rillet, gota que reflete o céu e faz um som de pingo | rastreador vê Ecos além da visão, 150, 170 e 200 m |

Na fase 0 o Eco vai até o nível 20. O Poder é derivado da espécie e do nível e só ganha uso com o ritual na fase 1. A destilação segue a tabela da fundação.

### Tipos

Feérico e Dracônico não pertencem a um bioma. Fadas aparecem em áreas verdes no crepúsculo real (nascer e pôr do sol) e com mais frequência na lua cheia. Dragões são as entidades mais antigas e as que mais se fragmentaram ao atravessar o Véu, então seus Ecos quase não parecem dragões (uma escama viva, uma brasa que respira). Aparecem raramente perto de cicatrizes de Fenda e em eclipses. Reconstituir um dragão por fusão é a linha de progressão mais longa do jogo. Panteões externos reforçam os dois tipos (dragões nórdicos e chineses, fadas celtas).

### Vantagens e desvantagens

A tabela define contenção. No ritual, uma criatura do Círculo forte contra o tipo do alvo conta 1,5x e uma resistida conta 0,66x. Na sintonia, ter no Círculo um tipo forte contra o alvo amplia a tolerância do dial. Criaturas com dois tipos multiplicam os fatores. No plano B de batalha, os mesmos fatores valem como dano.

| Tipo | Forte contra | Fraco contra |
| --- | --- | --- |
| Fogo | Planta, Metal | Água, Terra |
| Água | Fogo, Terra, Digital | Planta, Elétrico |
| Planta | Água, Terra | Fogo |
| Terra | Fogo, Elétrico, Metal | Água, Planta |
| Elétrico | Água, Metal, Digital | Terra |
| Metal | Feérico, Luz | Fogo, Terra, Elétrico, Digital |
| Luz | Sombra, Espectral | Metal, Sombra |
| Sombra | Luz, Feérico | Luz, Espectral |
| Espectral | Sombra, Espectral | Luz, Espectral, Feérico, Digital |
| Dracônico | Dracônico | Dracônico, Feérico |
| Feérico | Dracônico, Espectral | Metal, Sombra |
| Digital | Espectral, Metal | Elétrico, Água |

Digital é informação, não energia, o que o separa de Elétrico. Aparece perto de antenas, torres de telecom e áreas comerciais densas, marcadas no OSM. Na sintonia cria sinais falsos e glitches no dial.

Resistências seguem duas regras. Cada tipo resiste ao próprio tipo, exceto Espectral e Dracônico. Dracônico resiste a Fogo, Água, Planta e Elétrico, compensando a fraqueza a Feérico. Metal contra Feérico vem do folclore do ferro frio.

### Modificadores do mundo

O ambiente real altera a força das criaturas na sintonia, no ritual e na contenção, o que diferencia o sistema de uma tabela estática.

| Condição real | Efeito |
| --- | --- |
| Criatura atuando no próprio bioma | +10% de força |
| Chuva | Água e Planta fortalecidos, Fogo enfraquecido |
| Calor alto | Fogo fortalecido |
| Noite | Sombra e Espectral fortalecidos, Luz enfraquecida |
| Crepúsculo | Feérico fortalecido |
| Lua cheia | Feérico e Espectral fortalecidos |
| Eclipse | Dracônico fortalecido |

### Variantes

- Variante de bioma, com paleta e traço passivo definidos pelo bioma onde foi capturada. Custo de arte quase zero via troca de paleta.
- Brilhante, raridade pura em qualquer lugar.
- Carmesim, só na Lua Carmim ou com Exposição ao Véu alta.
- Corrompida, criatura do Círculo exposta a Exposição muito alta ou a um colapso de Fenda. Mais forte no mapa e em rituais, mas instável, às vezes sabota uma sintonia ou tenta fugir. Um ritual de purificação devolve ao normal e rende Conhecimento.

### Quimeras

Criaturas de duas famílias diferentes só existem como Quimeras, e só o Selador consegue criá-las. Não há híbridos naturais no mapa. Jogadores de outras escolas obtêm Quimeras por troca, o que dá valor ao social quando ele entrar. Visualmente usam o sprite base de uma criatura com paleta, partículas e um acessório do tipo da outra, evitando sprites modulares.

### Fusão

Vários fragmentos da mesma família se fundem na entidade de camada superior, consumindo também Essência, do tipo na fusão de Ecos e da família a partir dos Espíritos. Fusão entre famílias diferentes não existe, esse papel é das Quimeras do Selador.

### Companheiro

O companheiro é a criatura na frente do Círculo. Ela anda ao lado do jogador e dá um bônus de caminhada, como coletar Fagulhas num raio maior. Não tem progressão própria.

### Bestiário

App do celular, sem uso de câmera. Cada espécie tem níveis de pesquisa (capturar, sintonizar em biomas diferentes, ver de dia e de noite, encontrar variantes). Cada nível libera lore, atributos reais (Poder, Habilidade e Traços) e bônus de captura, e revela quais métodos a espécie aceita e os espaços do ritual dela.

## Marcas

Toda criatura tem duas entradas, tipo e marca. O tipo define vantagens e desvantagens na tabela. A marca é opcional, não entra na tabela e muda regras de obtenção, evolução ou comportamento. Um autômato pode ser Metal e Artificial, um deus pode ser Fogo e Divino.

| Marca | Quem recebe | Regra principal |
| --- | --- | --- |
| Familiar | a primeira criatura do Conjurador | cresce com o nível do Conjurador, forma definida pela escola |
| Divino | deuses, titãs, topos de fusão | fraqueza elemental cai para 1,25x, não responde à sintonia comum |
| Singular | espíritos de propósito único de eventos e rumores | um por jogador, sem fusão nem troca |
| Artificial | autômatos e golens construídos | fabricados na bancada, evoluem por módulos |
| Lenda Urbana | entidades nascidas da crença coletiva da cidade | ganham força com a Crença, que cresce sozinha com o tempo, e parte dos rumores sobre elas é falsa |
| Herói | heróis míticos ligados a monumentos reais, em expansão | obtido por Jornada, cresce por Glória, tem Fraqueza Fatal |

### Divino

Marca deuses, titãs e os topos das linhas de fusão. A fraqueza elemental cai de 1,5x para 1,25x, a criatura não responde à sintonia comum e só entra no Círculo como Avatar, por fusão final. Deuses verdadeiros só se relacionam com o jogador como patronos, por pacto. Cada panteão pode dar um nome próprio à marca (Olímpico, Aesir, Neter) sem mudar a regra.

### Singular

Marca espíritos de propósito único, ligados a um evento ou rumor específico. Só existe um por jogador, não pode ser fundido nem trocado, e tem uma habilidade que funciona apenas no contexto de origem, como um espírito de Finados que fica mais forte em cemitérios em novembro.

### Artificial

Criaturas construídas, não capturadas. Autômatos e golens tecnomágicos montados na bancada de casa com gadgets, sucata e Fagulhas como núcleo. Não sobem por fusão nem por estabilidade, sobem trocando e melhorando módulos. Limite de uma Artificial no time. Exclusiva da escola Tecnomante.

### Lenda Urbana

Nem tudo vem das Fendas. Lendas Urbanas nascem de rumores do fórum, gerados pela seed e iguais para amigos. Cada rumor tem Crença, que cresce sozinha com o tempo, mesmo sem o jogador interagir, e parte dos rumores é falsa. Só existem em Kenoma, sem Aethyr de origem.

| Estágio | Crença | Duração típica | O que acontece |
| --- | --- | --- | --- |
| Boato | 0 a 30 | 1 a 2 semanas | só posts no fórum, pode ser falsa |
| Crendice | 30 a 60 | 2 a 4 semanas | sinais e rastros fracos no mapa |
| Lenda | 60 a 90 | 1 a 2 meses | manifesta e pode ser capturada, ainda fraca |
| Mito Urbano | 90 a 100 | 2 a 4 semanas | forma plena, com camada e Poder maiores |
| Esquecimento | cai | algumas semanas | a criatura some e o rumor fecha |

Cerca de um terço dos rumores é falso: a Crença sobe até algum ponto do Boato ou da Crendice e cai, sem manifestar. O jogador escolhe quando agir. Capturar cedo garante a criatura numa versão fraca, esperar o Mito dá a versão forte mas arrisca o Esquecimento, e investigar com rumores, bestiário e reputação dá pistas de quais são falsos. Postar relatos acelera a Crença até 1,5x, mas também revela antes se ela é falsa. A Crença cresce mais rápido em células densas e em eventos como Sexta-feira 13 e Finados.

### Familiar

A primeira criatura do jogo, que desperta junto com o celular na noite em que as Fendas se abrem. Não é capturada nem fabricada, ela escolhe o Conjurador. Existe só uma por jogador e não sobe por fusão nem por estabilidade. Sobe de camada em marcos de nível do Conjurador, e a forma que assume depende da escola escolhida.

- Familiar de Tecnomante ganha traços Digitais e mecânicos.
- Familiar de Xamã Urbano acelera a afinidade no vínculo.
- Familiar de Selador acelera a dissolução do Véu na sintonia.

É o companheiro de caminhada padrão no início do jogo. Não ocupa espaço no Círculo: anda sempre ao lado do Conjurador, e a habilidade dele soma às do Círculo.

### Herói

Marca de expansão, que chega com um panteão posterior como mecânica nova. Heróis míticos como Aquiles e Hércules, mortais que viraram lenda pelos próprios feitos. Tudo na marca gira em torno de provar valor. Limite de um Herói no time.

- Obtenção por Jornada. Os ecos de heróis ficam presos a monumentos, estátuas e memoriais reais (tags OSM de memorial e monumento). O herói propõe uma sequência de feitos inspirada no mito, distribuída ao longo de semanas, e só se junta ao Conjurador ao final.
- Evolução por Glória, não por XP, fusão ou estabilidade. Glória vem de feitos difíceis, como capturar criatura muito acima do nível, completar ritual sem errar sigilo, selar uma Fenda ou conter um Soberano. Captura fácil não rende Glória.
- Fraqueza Fatal. No Círculo, o herói vale muito mais que criaturas da mesma camada na contenção e nas habilidades de mapa, mas carrega uma fraqueza tirada do mito que o derruba de uma vez. Aquiles cai com um único sigilo errado na fase de pressão, o calcanhar do ritual. Hércules cai quando a Exposição ao Véu passa de um limite, a loucura enviada por Hera.
- Destino. Herói que cai sai do Círculo e descansa um ou dois dias reais antes de voltar.

## Captura

Não existe batalha. O jogador dissolve o Véu das criaturas por três métodos, sintonia, ritual e vínculo, e as criaturas que já tem servem como ferramentas no mapa e como força de contenção. O sistema de batalha anterior está guardado como plano B em Plano B · batalha v2, caso os testes da sintonia não sejam satisfatórios.

| Camada | Método principal | Liberado por |
| --- | --- | --- |
| Fagulhas | coleta automática | início |
| Ecos | sintonia | início |
| Espíritos | sintonia com resistência ou ritual | nível do Conjurador |
| Entidades Maiores | ritual | pesquisa no bestiário e rumores do fórum |
| Arquétipos e Guardiões | vínculo com ritual final | nível alto e afinidade |
| Divindades | Avatar por fusão final, patrono por pacto | progresso na história |

Cada espécie aceita um ou mais métodos, e o bestiário mostra quais conforme a pesquisa avança.

### Início do encontro

| Comportamento | Como inicia | Efeito |
| --- | --- | --- |
| Passivo | toque com o Eco a até 30 m | sinal normal |
| Arisco | foge se o jogador se aproximar rápido demais | sinal instável |
| Agressivo | inicia a sintonia sozinho ao entrar no raio, o celular vibra | resistência mais forte |
| Oculto | só aparece após seguir rastros ou usar o scanner | sinal mais estável |

### Sintonia

O celular funciona como um rádio do Véu. Ao tocar numa criatura aparece o sinal dela como uma onda, e o jogador arrasta um dial até alinhar a frequência. O selo é consumido ao iniciar, e selos melhores ampliam a tolerância do dial. Enquanto o sinal fica alinhado o Véu se dissolve e, ao terminar, a criatura é selada. Se o tempo acabar, o selo se perde e a criatura pode fugir. Dura de 5 a 20 segundos, ou até 25 com tônico, e não depende de como o jogador se move, então funciona no ônibus, de bicicleta parada ou sentado.

Toda sintonia concluída deixa ectoplasma, o resíduo do Véu dissolvido e ingrediente básico dos selos, então capturar alimenta o próximo selo.

Marcação resolve quem passa rápido. Um toque numa criatura em movimento prende o sinal dela no celular por alguns minutos, e a sintonia pode ser feita depois, de qualquer lugar.

A criatura resiste, e cada tipo resiste de um jeito que o jogador aprende a ler. O tipo se lê pela criatura na tela, e o som e a vibração marcam os momentos do padrão, como o aviso antes de um pico do Fogo.

| Tipo | Resistência no dial | Como ler |
| --- | --- | --- |
| Fogo | a onda queima num ponto e se parte em duas; a da esquerda fica na frequência antiga como isca e a da direita, a verdadeira, desliza suave para outra frequência | uma brasa avisa onde vai queimar; seguir sempre a onda da direita e ignorar a isca |
| Água | duas ondas somadas que nunca se repetem, com uma maré que muda a amplitude | ler a tendência e o aviso de virada, sem corrigir demais |
| Planta | o sinal cresce num sentido e dá brotos, e cada broto finca uma raiz numa faixa fixa do dial; com o dial sobre uma raiz a sintonia é interrompida | decidir quando atravessar uma raiz e quando esperar o sinal sair dela |
| Terra | o dial fica pesado em certas faixas de frequência | antecipar o movimento antes de entrar na faixa |
| Elétrico | o sinal salta entre duas ou três frequências em ritmo fixo | decorar o ritmo e chegar antes |
| Metal | em intervalos o sinal fica blindado e alinhar não dissolve o Véu | manter alinhado mesmo assim para não perder progresso |
| Luz | clarões deixam a onda invisível por instantes | memorizar a posição e segurar o dial |
| Sombra | some do sinal e reaparece em outra frequência | seguir o som, que continua |
| Espectral | uma onda fantasma imita a real com atraso | a real é ciano, a fantasma é cinza |
| Digital | ondas falsas idênticas à real | as falsas piscam em pixels quebrados |
| Feérico | inverte o sentido do dial e troca de padrão no meio | perceber a troca pelo som |
| Dracônico | começa calmo e fica mais agressivo a cada terço, somando padrões de outros tipos | sintonia longa, só aparece no meio do jogo em diante |

Criaturas de dois tipos misturam os dois padrões. No início do jogo não há resistência, depois ela surge fraca e um padrão por vez, e fica mais intensa conforme a curva de dificuldade.

A vibração é alerta e ritmo, nunca o único jeito de identificar algo. Ela avisa que há um Eco perto com o celular no bolso, marca os momentos da resistência durante a sintonia, faz a mordida da pescaria e a proximidade do detector de escavação. No teste da Fase 0, reconhecer o tipo só pela vibração se mostrou difícil demais, então o tipo sempre aparece na tela e no som.

A onda é temática. A mecânica de cada tipo continua a da tabela de resistência, e o visual conta o que está acontecendo, com o aviso embutido na própria imagem. Tudo escala com a intensidade da resistência.

| Tipo | Como a onda se comporta | O que sobe com a intensidade |
| --- | --- | --- |
| Fogo | uma brasa acende num ponto da onda viva (o aviso) e a chama queima ali; a parte da esquerda vira cinza na hora e sai da tela na frequência antiga, enquanto a nova onda entra pela direita e desliza para a nova frequência; a certa é sempre a da direita | deslize mais rápido, salto maior, isca que dura mais e se move, brasa com menos antecedência |
| Água | a crista quebra em espuma de alta frequência e depois assenta, por cima da maré de base | ressaca mais longa e mais alta |
| Planta | a onda solta folhas, cada broto é um nó que salta e finca uma raiz visível no dial, que fica parada naquela faixa | crescimento mais rápido, mais raízes e mais largas |
| Terra | faixas pesadas aparecem como estratos de rocha no fundo do eixo | mais faixas, e mais largas |
| Elétrico | a onda vira arco elétrico nos saltos entre dois ou três pontos | mais pontos, ritmo mais rápido |
| Metal | placas de blindagem cobrem trechos e alinhar sobre elas só solta faísca | placas mais longas |
| Luz | um clarão apaga a onda e deixa uma imagem residual de onde ela estava | a imagem residual some mais rápido |
| Sombra | a onda afunda em tinta preta enquanto o som continua | mais tempo no escuro |
| Espectral | uma cópia cinza imita a onda com atraso | atraso menor, cópia mais parecida |
| Digital | cópias com glitch de pixels | mais cópias, glitch mais sutil |
| Feérico | a onda espelha e solta pó de fada quando o dial inverte | trocas mais frequentes |
| Dracônico | a onda ganha escamas e a cada terço assume o visual de outro tipo | mais padrões somados |

A onda do sinal continua sempre ciano. O dial é violeta, a cor do Véu. Enquanto o sinal está alinhado ele assume a cor do tipo do Eco e solta partículas, como se o Véu se dissolvesse na criatura. A mudança nunca depende só de cor: o dial também brilha e engrossa, para quem tem daltonismo.

### Lua, astros e sintonia

A lua e os astros mudam a dificuldade da sintonia, sempre calculados offline pela data, então todo o grupo vê o mesmo céu. Toda dificuldade extra vem com recompensa extra (Essência, experiência e chance de variante), para que as noites difíceis sejam as noites dos bons jogadores e não noites para evitar. Esse eixo é separado das receitas de lua do crafting.

Os 12 tipos se dividem em quatro grupos, e cada fase principal da lua aperta um deles. As fases de transição são neutras.

| Fase | Grupo mais difícil e mais recompensado |
| --- | --- |
| Crescente | Vivos (Fogo, Água, Planta) |
| Quarto crescente | Matéria (Terra, Metal, Elétrico) |
| Cheia | Espírito (Luz, Sombra, Espectral) |
| Quarto minguante | Estranhos (Dracônico, Feérico, Digital) |
| Nova | todos, com chance maior de variante Brilhante |

Na Lua Carmim as ondas se misturam entre os tipos. Um Eco de Fogo aparece na tela, mas a resistência vem com o padrão de Água ou de Terra, sorteado pelo hash do encontro e igual para amigos. Nos primeiros instantes a onda pisca na cor do tipo emprestado, e quem presta atenção lê a troca. Em intensidade alta o padrão pode trocar de novo no meio da sintonia. Uma lua cheia por estação é Carmim, marcada no calendário das Épocas. Ela é a principal fonte de variantes Carmesim e de luz carmim engarrafada.

A estação do signo solar puxa o elemento dela. Na estação de Fogo (Áries, Leão, Sagitário) aparecem mais Ecos de Fogo e eles resistem um pouco mais, e o mesmo vale para Água, Terra e Ar, que corresponde ao Elétrico. Nos períodos reais de Mercúrio retrógrado o dial às vezes gira ao contrário por um instante, como um erro nas leis da realidade.

A onda temática e a cor do dial podem entrar na fase 0 ou 1. Lua por grupo e astrologia entram na fase 1, com a astronomia offline, e a Lua Carmim com os eventos de calendário.

### Ritual

Para criaturas que não respondem à sintonia. Abre um círculo com espaços para materiais, uma condição do mundo (horário, bioma, lua, clima) e criaturas do Círculo. Espaços ainda não descobertos aparecem como ???. Com a combinação certa, o ritual entra na fase de pressão: sigilos surgem na tela e precisam ser desenhados antes do tempo acabar, em maior número, mais rápidos e com sigilos falsos conforme a força da criatura. O último sigilo sela a criatura.

Falhar tem custo. A criatura escapa, a Exposição sobe e rituais grandes podem liberar uma onda de Ecos corrompidos.

### Vínculo

Para criaturas que moram num lugar. O jogador volta em dias diferentes deixando oferendas feitas na bancada, às vezes atendendo pedidos específicos, até a afinidade encher e a criatura se juntar a ele sem selo. De vez em quando a criatura fica em perigo, com uma Fenda crescendo perto ou uma invasão, e ajudar rende um salto grande de afinidade. Os Guardiões de Lugar do Xamã são o exemplo mais forte.

Por contrato, algumas entidades não aceitam selo e só negociam um item, uma oferenda ou uma condição.

### Círculo

O time ativo é o Círculo. Cada criatura nele dá uma habilidade no mapa (Aura maior, revelar ocultas, coletar de outro bioma, resistir à Exposição), mais forte conforme o nível. O Círculo também é peça de ritual: conter uma entidade exige tipos fortes contra ela e força mínima. Selar Fendas e enfrentar Soberanos são grandes rituais que somam tipos e força do Círculo com sintonia e sigilos sob pressão. Invasões e expedições usam a força das criaturas de forma passiva. Sem batalha, criaturas ganham experiência estando no Círculo durante sintonias, rituais, contenções e expedições, e o Conjurador ganha experiência com cada captura e ritual concluído.

### Constelações

Três criaturas do Círculo em certas combinações ativam um bônus de conjunto, registrado no grimório quando descoberto. Três da mesma família reforçam a habilidade de mapa dela. O triângulo Fogo, Água e Planta estabiliza a sintonia contra qualquer elemental. Luz com Sombra permite sintonizar Espectrais sem resistência. É a profundidade de montagem que substitui a tática de batalha.

### Curva de dificuldade

O início é tranquilo e quase contemplativo. A dificuldade cresce em três eixos ao mesmo tempo.

| Fase | Material | Conhecimento | Mecânica |
| --- | --- | --- | --- |
| Início | selos baratos, materiais comuns | tudo revelado, rituais de 2 espaços | sinais estáveis, tolerância larga, sem resistência |
| Meio | selos de tipo, materiais por condição real | espaços ocultos, pistas no fórum e bestiário | um padrão de resistência por tipo, fase de pressão curta |
| Avançado | materiais raros de Fendas e eventos | rituais com condições combinadas | sinais com dois harmônicos, interferência da Exposição, sigilos falsos |
| Endgame | recursos de Soberano | conhecimento dos Aethyrs | grande ritual com sintonia, sigilos e poder do Círculo |

Criaturas muito acima do nível do Conjurador devem ser quase impossíveis, e não só difíceis. O teto é de habilidade e não de números: uma pessoa que já dominou o jogo consegue, numa conta nova, capturar algo bem acima do próprio nível, e quem está aprendendo não consegue. Para isso a diferença de nível age em dois eixos. Até cerca de 5 níveis ela só aumenta a intensidade do padrão do tipo. Acima disso entra o sobrenível, que estreita a tolerância e acelera a perda de progresso a cada nível a mais, sem teto de intensidade. Como o selo é gasto ao começar e a criatura pode fugir, cada tentativa custa, e insistir sem habilidade não compensa.

### Minigames futuros

O dial é o único minigame de sintonia no MVP. Depois entram outros, variando por espécie, como sequência e encontre a esfera. Pescaria e escavação são atividades próprias, com equipamento e progressão, descritas em Ofícios, sítios e equipamento.

### Escopo

O MVP tem sintonia por dial com resistência por tipo e marcação. O ritual básico de 2 espaços entra na fase 1, junto com os Espíritos, e vínculo e fase de pressão depois. O protótipo isolado da sintonia é o primeiro teste de diversão do projeto.

## Conjurador

O Conjurador tem progressão própria, separada das criaturas. Ganha experiência, escolhe talentos, coleciona grimórios, conjura magias e arrisca a própria sanidade.

### Celular mágico

A interface do jogo é o celular do personagem. Novas funções chegam como apps que o aparelho ganha com a exposição às Fendas, e cada desbloqueio funciona como tutorial da mecânica.

| App | Função |
| --- | --- |
| Visão espectral | enxerga o Véu no mapa, sem usar a câmera real, app inicial |
| Radar e scanner | rastros e informação de criaturas |
| Bestiário | catálogo e pesquisa de espécies |
| Grimório | receitas, rituais, lore |
| Leitor de Ley | Ley Lines fixas e próprias |
| Chat | história, mentor, contatos misteriosos |
| Fórum ocultista | rumores e reputação |
| Bolsa | materiais, itens e condições engarrafadas |
| Círculo | time ativo, Constelações e criaturas guardadas |
| Bancada | crafting, destilação e grandes obras em andamento |

### Rastros e scanner

Criaturas raras deixam rastros que apontam direção aproximada. O scanner tem níveis. No primeiro mostra só pegada e direção, depois tipo elemental, depois Poder e variante, e no topo localização exata e traços passivos antes da sintonia. Encantamentos amplificam temporariamente e gadgets aumentam permanentemente.

### Escolas de Conjuração

A escola é escolhida cedo, no nível 3 do tutorial, e define o estilo de jogo desde o começo. Os primeiros níveis dela dão só o bônus de captura, e as mecânicas exclusivas liberam pela árvore da escola ao longo dos níveis. Os talentos de cada escola estão em Árvores das escolas. Cada escola tem o mesmo peso, com quatro mecânicas exclusivas, uma em cada eixo.

| Escola | Criaturas | Modificação | Captura | Mapa |
| --- | --- | --- | --- | --- |
| Tecnomante | fabrica Artificiais (autômatos e golens) | Implantes, módulos tecnomágicos instaláveis em qualquer criatura | tolerância maior na sintonia, gadgets que estabilizam o sinal | Sentinelas, balizas fixas em células que revelam névoa e detectam rastros à distância |
| Xamã Urbano | Guardiões de Lugar, espíritos de lugares reais frequentados | Vínculo ampliado, vincula criaturas que para os outros só aceitam selo, inclusive agressivas | afinidade em dobro no vínculo, Incorporação amplia a sintonia | conversa com criaturas, ariscas não fogem e a Aura é maior |
| Selador | Quimeras, duas criaturas de famílias diferentes num mesmo selo | Relicários, sela uma criatura num objeto e cria equipamento com a habilidade dela | mais tempo e sigilos avançados na fase de pressão do ritual | armadilhas de selo que capturam Ecos sozinhas na ausência |

Guardiões de Lugar crescem conforme o Xamã visita o lugar e ficam muito mais fortes em rituais e contenção perto dele, com limite de três ativos. Implantes e Relicários funcionam como contrapartes, um adiciona tecnologia a criaturas vivas, o outro transforma criaturas em equipamento. Sentinelas e armadilhas são as duas formas de agir no mapa à distância.

Cada escola nasce de uma das três forças do jogo e usa a cor dela. O Selador trabalha com o Véu, em violeta: costura, prende e sela, e é a escola que o Familiar reconhece como parente. O Tecnomante trabalha com o sinal, em ciano: usa a mesma língua de Os Que Escutam, por isso é a escola mais forte com tecnologia e a mais exposta a eles. O Xamã Urbano trabalha com a vida e a Essência de Kenoma, em laranja: conversa com os lugares e com o que vive neles. O mentor ensina as três sem preferência declarada, o que por si só já é suspeito.

### Troca de escola

No nível 30 o mentor revela o Rito de Reconsagração, que troca a escola. Ele custa Essência concentrada e materiais raros e tem espera longa entre trocas, na ordem de semanas reais.

- Talentos da escola anterior ficam guardados e voltam se o jogador retornar a ela.
- Criaturas exclusivas da escola anterior (Artificiais, Quimeras, Guardiões de Lugar) ficam adormecidas, guardadas mas fora do Círculo.
- O Familiar muda de forma aos poucos, ao longo de alguns dias.

Para misturar escolas sem trocar, continuam valendo as especializações avançadas liberadas por grimórios completos.

### Níveis e maestrias

O Conjurador vai do nível 1 ao 40. Cada nível dá um ponto de talento, que desbloqueia traços nas linhas de especialização, e alguns níveis liberam sistemas.

| Nível | Libera |
| --- | --- |
| 1 | Aura base, sintonia, magia de estabilização |
| 3 | escola e primeira linha de especialização |
| 5 | casa, Armazém, troca de build em casa |
| 8 | ritual básico, primeira magia utilitária |
| 12 | vínculo, segunda linha de especialização |
| 15 | segunda magia utilitária, Bolsa maior |
| 20 | terceira linha, universal, e Incursões (dungeons e núcleos de Fenda) |
| 25 | espaço de magia elite, pactos |
| 30 | especialização avançada por grimório, Rito de Reconsagração |
| 40 | teto de nível, início das maestrias, o Rasgo |

A Aura cresce um pouco nos níveis 1, 10, 20, 30 e 40, e depois só por maestria, gadgets e Essência Divina. Bônus de Círculo, escola e talentos somam por cima enquanto estão ativos.

### Curva de experiência e maestrias

O teto fica no nível 40. A experiência para ir do nível n ao n+1 é 60 × n^1,25, arredondada para dezenas: 60 para chegar ao 2, cerca de 940 para chegar ao 10, 2.380 ao 20, 4.040 ao 30 e 5.850 ao 40, somando por volta de 104 mil do 1 ao 40. A curva é suave de propósito, porque o jogo cresce na horizontal depois dos primeiros meses.

A experiência vem do conteúdo e escala com o nível dele, não com o do jogador. Uma sintonia comum rende de 20 a 60 conforme camada e nível da criatura, um ritual de 80 a 250, a primeira captura de uma espécie dá um bônus de 100, cada diária do fórum cerca de 150, a semanal do mentor 1.000, uma Incursão de 300 a 800 e selar uma Fenda 1.500. Criaturas muito abaixo do nível do Conjurador rendem quase nada, o que empurra o jogador para conteúdo novo em vez de farm.

Um dia típico de 30 a 40 minutos rende cerca de 700 de experiência no começo e 1.400 perto do 40. Nesse ritmo o jogador chega ao nível 5 no segundo dia, ao 12 na segunda semana, ao 20 em três semanas e meia, ao 30 em cerca de 50 dias e ao 40 em cerca de 90, o que bate com os 3 meses do quadro de ritmos.

A primeira parte da experiência de cada dia, por volta de metade de um dia típico, vale em dobro, e esse bônus acumula até o equivalente a três dias. Assim quem joga menos não fica muito atrás dos amigos e ninguém é punido por pular dias.

Depois do 40, a experiência alimenta maestrias, progressão horizontal que não aumenta poder bruto. A experiência de cada atividade vai para a maestria correspondente. Cada maestria tem 30 níveis e o nível k custa 1.000 × k, cerca de 465 mil por maestria. Jogando todo dia, as primeiras maestrias chegam ao meio em alguns meses e todas chegam ao máximo por volta do quinto ano.

| Maestria | Progresso vem de | Libera |
| --- | --- | --- |
| Sintonia | capturas | tolerância, novos minigames, padrões raros |
| Criação | crafting | qualidade, receitas raras, grandes obras e Núcleo mais baratos |
| Cidade | névoa, bairros purificados, Ley Lines | Aura, Leys próprias, pontos de interesse |
| Véu | Fendas, incursões, dimensões | resistência à Exposição, acesso a dimensões |
| Ciclos | eventos, sazonais, lua | receitas de janela raras, coleções anuais |

### Build

A build é montada em casa e fica travada na rua, como nos postos avançados do Guild Wars 1. O jogador equipa antes de sair, adquire técnicas no trajeto e volta para casa para reorganizar.

| Parte | Espaços |
| --- | --- |
| Círculo | 3 criaturas |
| Linhas de especialização | 3, sendo 2 da escola e 1 universal, cada uma com 3 escolhas de traço |
| Magias | 1 estabilização, 2 utilitárias, 1 elite |
| Equipamento | amuleto, anel, 2 gadgets |
| Cosméticos | livres, trocáveis em qualquer lugar |

A magia elite carrega por ações, como sintonias bem-sucedidas, e não por tempo de espera, no estilo do que foi mostrado do Guild Wars 3.

Técnicas são aprendidas no trajeto por transcrição, inspirada no Signet of Capture do Guild Wars 1. Algumas criaturas carregam uma técnica, marcada no scanner. Com um Selo de Transcrição, o jogador pode, no fim da sintonia, capturar a técnica em vez da criatura. Ela vira uma magia ou traço pendente, que só pode ser equipado em casa. Magias elite vêm de Entidades Maiores e Soberanos. No lategame, nexos de Ley consolidados funcionam como postos avançados, onde a build pode ser trocada fora de casa.

### Árvores das escolas (rascunho)

Cada linha segue a estrutura das especializações do Guild Wars 2: três traços menores automáticos e três níveis de traço maior, com escolha entre três opções em cada nível. Pontos de talento desbloqueiam traços, e a escolha entre os desbloqueados é livre em casa.

| Escola | Linha | Foco | Exemplo de traço maior |
| --- | --- | --- | --- |
| Tecnomante | Circuitos | sintonia e estabilização | o primeiro pico de resistência de cada sintonia é anulado |
| Tecnomante | Autômatos | Artificiais e módulos | Artificiais no Círculo contam como dois tipos na contenção |
| Tecnomante | Rede | Sentinelas, scanner, mapa | Sentinelas revelam rastros de Entidades Maiores |
| Xamã Urbano | Raízes | vínculo e Guardiões | oferendas valem o dobro durante chuva real |
| Xamã Urbano | Passos | caminhada, companheiro, Aura | cada quilômetro andado estende a Aura por uma hora |
| Xamã Urbano | Incorporação | Círculo e Constelações | uma Constelação extra pode ficar ativa |
| Selador | Sigilos | ritual e fase de pressão | um sigilo errado por ritual é perdoado |
| Selador | Relicários | Relicários e Quimeras | Relicários herdam um traço da criatura |
| Selador | Contenção | armadilhas, Fendas, Soberanos | armadilhas também prendem Espíritos |
| Universal | Criação | crafting e qualidade | chance de qualidade superior no refino |
| Universal | Véu | Exposição e magias | magias custam menos Exposição à noite |
| Universal | Cidade | exploração e coleta | Fagulhas coletadas de mais longe |

Especializações avançadas, liberadas por grimório a partir do nível 30, misturam a escola com outra. Cada uma substitui uma linha da escola e muda uma mecânica, como as especializações de elite do Guild Wars 2.

| Escola | Avançada | Mistura com | Mecânica |
| --- | --- | --- | --- |
| Tecnomante | Oráculo | Xamã | lê a Crença das Lendas Urbanas e aponta quais são falsas |
| Tecnomante | Engenheiro de Selos | Selador | selos mecânicos sintonizam Ecos marcados sozinhos |
| Xamã Urbano | Médium | Selador | incorpora Espectrais e lê sinais fantasmas |
| Xamã Urbano | Antena Viva | Tecnomante | Guardiões de Lugar funcionam como Sentinelas |
| Selador | Arquivista | Tecnomante | condições engarrafadas não perecem |
| Selador | Exorcista | Xamã | purifica Corrompidas no campo, sem ritual |

Novos panteões podem trazer novas especializações avançadas sem mudar a estrutura.

### Magias

Quatro espaços de magia na build (estabilização, duas utilitárias e elite), usados na captura e no mapa, como estabilizar o sinal por alguns segundos, congelar a resistência da criatura ou revelar um espaço oculto do ritual. Cada uso aumenta a Exposição ao Véu, ligando poder a risco.

### Exposição ao Véu

Medidor tipo sanidade que sobe com tempo em Fendas, jogo noturno, magias e proximidade de entidades fortes. Exposição alta aumenta percepção (mais rastros, raros visíveis, Carmesim possível), mas o celular começa a glitchar com UI distorcida, radar mentindo, sussurros enganosos e sinais fantasmas no dial da sintonia. Descansar em casa ou usar itens reduz.

### Grimórios

Coleção principal do personagem. Cada grimório é um livro com páginas espalhadas por Fendas, dungeons, rumores e invasões. Páginas soltas ensinam receitas ou fragmentos de lore, e o livro completo libera um ritual, uma magia ou uma especialização avançada. Há grimórios temáticos por panteão.

### Rituais de mundo

Diferentes do ritual de captura, são ações com preparação e materiais (giz, velas, sal) que alteram o mundo localmente por um tempo. Exemplos incluem invocar uma espécie, banir Ecos corrompidos após colapso de Fenda, inverter dia e noite num raio pequeno e acalmar uma Fenda para ela não crescer.

### Pactos

O pacto é o sistema de alto risco. Só um fica ativo por vez. No jogo base o patrono é uma Entidade Maior ou um Soberano contido, pedaços com vontade própria, e o pacto é oferecido depois de uma contenção, de um rumor ou dentro de uma Fenda. Pactos com deuses vivos chegam com os panteões de expansão, já que os Trinta estão mortos. A escola define como o Conjurador age, o patrono define de onde vem o poder.

| O patrono dá | O patrono cobra |
| --- | --- |
| dádiva passiva forte, como picos de Fogo que se alinham sozinhos na sintonia | tributo semanal em Essência e materiais |
| ritual exclusivo, conhecido só por quem tem esse patrono | tabu tirado do mito, como não capturar um tipo rival ou Exposição base maior |
| influência no mundo, com mais spawns do tipo dele na Aura | pedidos enviados pelo chat, com a voz dele |

O favor cresce cumprindo tributos e pedidos e libera dádivas maiores. Favor zerado ou pacto rompido gera maldição temporária, com Exposição alta e o tipo do patrono resistindo mais. Patronos têm rivais pela tabela de tipos: um pacto com um patrono de Fogo deixa as criaturas de Água mais ariscas, e vice-versa. A rivalidade entre pactos celestes e infernais chega com as expansões, e os infernais darão as dádivas mais fortes e os tabus mais duros.

### Equipamento e gadgets

Amuletos, anéis e gadgets, com efeito e visual no sprite. Roupas não têm efeito, são só cosméticos. Gadgets seguem a escala mundano, encantado e arcano, todos craftáveis.

- Fone que capta sussurros, pista sonora dos rastros.
- Powerbank que armazena ectoplasma para fabricar selos em campo.
- Lanterna UV que revela Ecos escondidos à noite.
- Smartwatch que converte passos em Pó de Essência.

### Cosméticos

Roupas e acessórios visuais para o personagem, sem nenhum modificador. Servem como registro do que o jogador viveu e como motivo para voltar em datas específicas.

- Eventos do calendário e Lua Carmim dão peças exclusivas daquele evento.
- Cada estação do ano tem uma coleção fabricável só nela, como os amuletos sazonais.
- Peças fabricadas na bancada usam materiais comuns e condições engarrafadas, com cores ligadas ao material usado.
- Metas longas do Diário do Conjurador e marcos de reputação no fórum rendem peças raras.

Cosméticos aparecem no sprite do personagem no mapa e no retrato do HUD.

### Rumores

O fórum ocultista traz relatos de usuários fictícios gerados pela seed, com pistas espalhadas em três a cinco células próximas. O jogador coleta evidências com os apps e deduz qual entidade está por trás. Acertando, a entidade aparece com bônus de captura e o jogador ganha reputação. Errando, ela foge. A reputação libera threads mais raras, subfóruns fechados e contatos misteriosos.

### História

A narrativa chega por mensagens no chat e posts no fórum, disparadas por nível, eventos e Fendas seladas. A história principal vai do nível 1 ao 40 em quatro atos, descritos em Kenoma · Bíblia da franquia.

## Crafting

Não existem lojas fixas nem moeda. Tudo sai do crafting, e o único comércio é o escambo com o Mercador Errante. Coisas simples têm receitas simples, e grandes coisas são obras em etapas, no estilo das árvores de crafting do Terraria. O mundo real define o que dá para fabricar agora, mas nunca bloqueia quem não tem acesso a um lugar específico.

| Nível | Onde | Etapas | Exemplos |
| --- | --- | --- | --- |
| Improviso | em qualquer lugar | uma, com 2 ingredientes | selo simples, tônico, garrafa |
| Estação | numa estação, no mundo ou em casa | 2 a 3, com intermediários | selos de tipo, gadgets, lures |
| Grande obra | várias estações, condições e dias | árvore de 4 ou mais etapas | selos de dimensão, artefatos, Avatar |

### Degraus de material

Materiais sobem em quatro degraus, e é isso que forma a árvore sem receitas gigantes.

| Degrau | O que é | Exemplos |
| --- | --- | --- |
| Bruto | coletado no mapa ou destilado | vidro, giz, ervas, Essência |
| Refinado | bruto processado ou capturado numa condição | água de chuva, giz consagrado, luz de lua |
| Componente | refinados montados com Essência | tinta sigílica, núcleo de selo, filamento etéreo |
| Peça | item final | selo, gadget, artefato |

### Coletores

Condições do mundo são capturadas com recipientes fabricados antes, o que torna o mundo real ingrediente. Uma garrafa feita de vidro coleta água de chuva durante chuva real, um frasco escuro guarda luz de lua à noite, um pote de vela guarda fumaça de Fenda perto de uma. Condições engarrafadas viajam no inventário e podem ser usadas depois em casa. Algumas são perecíveis, como a luz da Lua Carmim, que se apaga em poucos dias.

### Condições, não lugares

Etapas situadas pedem condições que existem em qualquer cidade (noite, chuva, lua, água de qualquer tipo, qualquer área verde) e não lugares raros. Lugares raros, como cemitério ou igreja, dão qualidade maior ou bônus, nunca são obrigatórios. Regra fixa: toda receita tem um caminho comum. Quando uma etapa pede algo de um lugar raro, existe um substituto mais caro, vindo de um altar efêmero, do Mercador, de uma Fenda do tipo certo ou de um coletor.

### Altares efêmeros

Todo lugar especial tem um altar que o imita. O altar efêmero é fabricado com uma receita cara, montado em qualquer lugar e se dissolve depois de um único craft. No lategame o jogador pode fixar um altar permanente de cada tipo em casa.

| Altar | Imita | Libera |
| --- | --- | --- |
| Sagrado | igreja, templo | itens sagrados, selos de Luz, purificação |
| Sombrio | cemitério | itens sombrios, tintas de Sombra e Espectral |
| Poço | lago, rio | refino aquático sem água real por perto |
| Canteiro | parque, mata | refino vegetal e feérico |
| Fornalha | área industrial | refino de metal e fogo |
| Antena | torres de telecom | componentes Digitais e Elétricos |

O lugar real continua sendo o melhor caminho: usar a condição de verdade não gasta altar e dá qualidade maior.

### Lua e estações do ano

Fases da lua e estações do ano são calculadas offline pela data e latitude, com as estações invertidas no hemisfério sul.

- Cada fase da lua libera receitas próprias. Lua nova para itens de Sombra e ocultamento, cheia para Feérico e Espectral, crescente e minguante para itens de crescimento e dissolução.
- Cada estação do ano tem uma linha de amuletos exclusiva, que só pode ser fabricada nela. Um amuleto de verão fica disponível de novo só no verão seguinte, o que dá motivo para voltar ao jogo depois de um tempo.
- Amuletos sazonais já fabricados continuam funcionando o ano inteiro, e alguns ficam mais fortes na própria estação.

### Receitas de janela

Algumas receitas só ficam disponíveis em certas situações, o que dá motivo para jogar em momentos diferentes.

- Lua Carmim e eventos do calendário.
- Temporadas e convergências de dimensão.
- Proximidade de uma Fenda, com receitas que mudam conforme o estado dela.
- Composição do Círculo, como receitas que exigem uma Constelação ativa.
- Exposição ao Véu alta e pactos ativos.

A receita continua registrada no grimório depois da janela, mas só pode ser fabricada de novo quando a situação voltar ou com o ingrediente engarrafado.

### Estações

Estações ficam espalhadas pelo mundo como pontos gerados pela seed, com a aparência ligada ao bioma, e qualquer jogador usa a mais próxima. No lategame o jogador pode cravar uma estação na casa, usando o Núcleo dela, obtido depois de usá-la várias vezes. A bancada básica fica em casa depois que ela é definida, no nível 5.

| Estação | Faz | Melhora com |
| --- | --- | --- |
| Bancada | componentes simples | Essência comum |
| Alambique | destilação e refino | Essência de família |
| Forja de sigilos | selos avançados e tintas | Núcleos de espécie |
| Oficina tecnomágica | gadgets e módulos | sucata rara, Essência Digital ou Elétrica |
| Santuário | itens de ritual e pacto | Relíquias e Essência Divina |

### Grandes obras

Ficam salvas como projeto em andamento, com a árvore visível e as etapas marcadas conforme são concluídas. Exemplo:

```
Selo de Aethyr (abre a Fenda de um Aethyr escolhido)
├─ Chave do Aethyr
│  ├─ Essência da família ×20 (destilar Espíritos da família do deus daquele Aethyr)
│  ├─ Luz de lua cheia (frasco escuro, à noite na lua cheia)
│  └─ Núcleo de Entidade Maior da mesma família (destilar uma Entidade Maior)
├─ Tinta sigílica prismática
│  ├─ Giz consagrado (giz + sal, no Alambique)
│  └─ Essência prismática (destilar uma Brilhante)
└─ Etapa final: Forja de sigilos, perto de uma cicatriz de Fenda
```

### Combinação de equipamentos

Gadgets e equipamentos se combinam, somando efeitos num só espaço. Fone de sussurros com lanterna UV vira Lanterna ecoante, e com o scanner avançado vira Olho do Véu. O Conjurador tem poucos espaços de equipamento, então combinar é a forma de crescer no endgame.

### Qualidade e descoberta

A qualidade se propaga pela árvore. Ingredientes melhores geram intermediários melhores, e uma peça perfeita exige tudo perfeito, o que liga o crafting às condições reais (água de chuva forte, erva de lua cheia).

Receitas são descobertas experimentando combinações e por páginas de grimório. O grimório funciona como o Guia do Terraria: ao selecionar um material, mostra as receitas conhecidas que o usam e silhuetas das desconhecidas com uma pista.

### Escopo

MVP com improviso, bancada básica e destilação de Ecos, com selos de tipo simplificados como improviso. Fase 1 com coletores, refino, receitas de condição e receitas de lua e estação. Fase 2 com estações no mundo e combinação de equipamentos. Fase 3 com grandes obras, receitas de janela, altares efêmeros e cravar estações e altares em casa.

### Mercador Errante

Um espírito comerciante que atravessa o Véu por conta própria e aparece em células aleatórias do mapa, definidas pela seed, por algumas horas. Não aceita moeda, só escambo. O jogador troca materiais comuns em quantidade por materiais raros, páginas de grimório, gadgets ou equipamentos.

- O estoque é determinístico por aparição, então amigos veem o mesmo mercador com as mesmas ofertas.
- Cada aparição tem poucas ofertas e limite de trocas, para não substituir o crafting.
- As ofertas refletem o bioma onde ele surgiu e a temporada ativa.
- Troca sempre com perda. Nunca é o caminho mais eficiente, só o mais rápido para algo específico.
- Reputação no fórum ocultista ou pesquisa de bestiário podem liberar ofertas melhores e rumores sobre a próxima aparição.

## Casa

O jogador define a localização da casa uma vez, com cooldown longo para trocar. A casa fica sobre uma célula real, e o bioma dela define quais lures funcionam melhor.

### Base, Bolsa e Armazém

A casa é a base do jogador. Na rua ele coleta e captura, e à noite, em casa, organiza. É o único lugar onde a build muda, onde fica o Armazém e onde as grandes obras avançam.

- A Bolsa é limitada e cresce com bolsas fabricadas e marcos de nível. Condições engarrafadas ocupam espaço.
- O Armazém fica em casa, também limitado, e cresce com móveis fabricados (estantes, baús, câmaras frias para perecíveis), que contam como decoração.
- Criaturas guardadas fora do Círculo ocupam espaço no santuário de selos do Armazém, que também se expande.

Bolsa cheia não impede capturar, mas o excedente precisa ser destilado ou descartado no campo, o que alimenta o ciclo da Essência.

### Bancada e decoração

A bancada básica fica em casa a partir do nível 5, quando a casa é definida, e no lategame as estações cravadas também. Antes disso ela funciona dentro do app, em qualquer lugar. A decoração influencia o que os lures atraem. Itens aquáticos puxam Ecos de água, sucata puxa urbanos, e o jogador monta a casa como um ecossistema. Decorações também servem de defesa nas invasões.

### Lures

Consomem materiais e rodam em tempo real. Ao abrir o app, o jogo calcula o que chegou durante a ausência de forma determinística a partir do tempo decorrido. Lures atraem só Ecos e Espíritos, nunca Entidades Maiores, para caminhar continuar necessário. Lures de vigília atraem criaturas noturnas enquanto o jogador dorme.

### Invasões

De tempos em tempos, de forma determinística, uma Fenda pequena abre na casa durante a ausência. Ao voltar, o jogador precisa conter a invasão com uma sintonia antes de acessar a bancada, e o Círculo e a decoração ampliam a tolerância.

### Expedições

Criaturas são enviadas a células que o jogador já revelou na névoa de guerra e voltam depois de algumas horas reais com materiais daquele bioma. Só funciona em lugares já visitados.

### Fenda Profunda

Incursão de origem Casa, sem fim, com andares gerados pela seed do dia e Exposição acumulando sem descanso entre andares. Conteúdo infinito e totalmente offline.

## Ofícios, sítios e equipamento

Proposta em avaliação, fora da Fase 0. Pescaria e escavação são as duas atividades de campo que se somam à sintonia, cada uma com equipamento próprio que sobe por faixas de material, no estilo do Terraria. Nelas a vibração é só alerta, como a mordida e a proximidade, nunca identificação de padrão.

### Pescaria

Pesca-se em qualquer lugar. Numa célula de Água a linha desce na água e traz criaturas aquáticas, Água Pura e materiais de margem. Em qualquer outra célula a linha desce no Véu, e o que vem é material de Véu, Ecos Espectrais e restos de outros Aethyrs.

O lance é um gesto. A espera pode ser feita andando, com o celular no bolso, e a mordida chega como vibração. A puxada é um jogo de tensão em que segurar puxa e sobe a tensão, soltar alivia, e a linha arrebenta no máximo. Peixes grandes alternam corrida e cansaço, então o ritmo não repete o dial da sintonia.

| Peça | Efeito |
| --- | --- |
| Vara | força de pesca, que decide o peso máximo e a profundidade no Véu |
| Isca | muda o que morde e a raridade, consumida a cada mordida |
| Isca de chamado | feita com materiais raros, chama um miniboss com sintonia em fases |
| Linha e boia | acessórios que se combinam, como linha que não arrebenta e boia que avisa antes |

O que morde sai de `hash(seed, época, célula, janela, lance)`, então amigos no mesmo lugar e hora pescam na mesma lagoa, cada um com os próprios peixes. Uma figura do fórum Limen pede um peixe por dia e paga com iscas, varas e cosméticos.

### Escavação

Pontos de escavação saem da seed por célula e janela, como os spawns, e não aparecem no mapa. O detector acha pela proximidade, com a vibração acelerando conforme o jogador anda na direção certa, e funciona com o celular no bolso. Achado o ponto, abre uma grade de escavação em camadas, no espírito do subsolo de Pokémon Diamond e Pearl. Cada golpe gasta a firmeza da parede. A picareta abre rápido e pode rachar o achado, o pincel é lento e seguro, e a força da ferramenta decide as camadas alcançadas.

O que sai é minério, gema, fóssil ou material do bioma. Urbano favorece metal, Verde favorece fósseis e âmbar, Água favorece gemas roladas.

No jogo base os fósseis são ediacaranos, como Dickinsonia, Charnia e Tribrachidium, lidos na lore como as primeiras emanações dos Trinta impressas na pedra de Kenoma. Um fóssil completo, montado na mesa de fósseis, revive um Eco antigo como variante rara. Um panteão de expansão centrado em dinossauros amplia a mecânica com ossos maiores, sítios paleontológicos e esqueletos montados.

### Linha de minérios

Os níveis são o caminho. Até o 40, cada faixa aparece quando o jogador chega perto do nível dela e exige a ferramenta da faixa anterior, como a força de picareta do Terraria. Os metais de Kenoma são os do mundo real, e as faixas 2 a 5 têm um par. A seed do grupo escolhe qual dos dois existe naquele mundo, e o outro só vem pelo Mercador Errante.

| Faixa | Níveis | Minério | Onde aparece | Exige |
| --- | --- | --- | --- | --- |
| 1 | 1 a 5 | sucata e osso | coleta comum | nada |
| 2 | 6 a 10 | cobre ou estanho | escavação rasa em qualquer bioma | pá de sucata |
| 3 | 11 a 17 | ferro ou chumbo | escavação em Urbano e minas | ferramenta de cobre ou estanho |
| 4 | 18 a 24 | prata ou tungstênio | escavação funda e pesca no Véu | ferro ou chumbo |
| 5 | 25 a 31 | ouro ou platina | minas maduras e minibosses de isca | prata ou tungstênio |
| 6 | 32 a 36 | aerólito | cai no lugar de uma Fenda selada | ouro ou platina |
| 7 | 37 a 40 | ferro de ZAX | fundo das Incursões de Fenda, forjado só com Essência de Fogo | aerólito |

### O Rasgo

O nível 40 funciona como o hardmode do Terraria. Depois da revelação do mentor o Véu rasga para aquele jogador. As Fendas sobem de camada, manchas de Aethyr se espalham devagar pelas células já visitadas e o jogo deixa de guiar por nível. A progressão passa a ser horizontal, por maestrias, e o jogador escolhe o que perseguir, como num sandbox.

O Rasgo é individual. As manchas crescem de forma determinística a partir da data em que o jogador chegou ao 40, então amigos que chegaram juntos veem o mesmo mapa.

Os metais depois do Rasgo não são deste mundo. São sedimentos dos Aethyrs, com nomes enoquianos. Pedras de Fenda aparecem pelo mapa, e conter cada uma semeia no mundo do jogador uma leva de minério da faixa seguinte, como os altares do Terraria.

| Faixa | Minério | Como surge |
| --- | --- | --- |
| A1 | laiadita ou ethamzita | primeiras Pedras de Fenda contidas |
| A2 | vaoanita ou ozongonita | segunda leva de Pedras |
| A3 | madriaxita ou oxiayalita | terceira leva de Pedras |
| A4 | aeonita | minério vivo, cresce sozinho nas células de Verde manchadas |
| A5 | azoth | Essência cristalizada, deixada por Soberanos contidos |
| Além | véu forjado | fragmentos de Choronzon, trabalhados numa grande obra |

Ethamz e Madriax ainda precisam de conferência no dicionário enoquiano (ver Banco de nomes).

### Gemas

Gemas saem da escavação e da pesca e vão nos engastes de amuletos e gadgets. Cada gema puxa para um tipo, e a combinação de equipamentos soma gemas num só espaço.

| Gema | Liga a |
| --- | --- |
| rubi | Fogo |
| safira | Água |
| esmeralda | Planta |
| topázio | Elétrico |
| ônix | Sombra |
| diamante | Luz |
| ametista | Espectral e Exposição |
| âmbar | Terra e fósseis |

### Equipamento de campo

A vara, a pá e o detector sobem pelas mesmas faixas, então cada metal novo melhora as três atividades. A mobilidade do Terraria vira alcance e percepção, porque num jogo de GPS ninguém anda mais rápido.

| Inspiração | No Kenoma | Efeito |
| --- | --- | --- |
| gancho | âncora do Véu | puxa para a Aura um item a até 40 m |
| carrinho de mina | trilhos | andando ao longo de ruas e linhas de ônibus, a coleta automática pega uma faixa maior |
| montaria | criatura montável | aceita coleta até 25 km/h, o que recompensa bicicleta sem liberar carro |
| asas | visão alta | vê Ecos e pontos de escavação de mais longe |
| espelho mágico | espelho de casa | abre a bancada da casa de qualquer lugar, sem recolher o que ela produziu |

### Sítios

A casa continua única. Com o nível, o jogador ancora sítios anexos em outras células reais que frequenta, cada um com função própria, tudo individual e offline.

| Sítio | Função |
| --- | --- |
| mina | produz minério e gemas da faixa dela |
| ossuário | Ecos Espectrais repousam e liberam Ectoplasma, como um pedaço do Véu domesticado |
| viveiro e aquário | criaturas de Planta e Água produzem materiais e guardam o que foi pescado |
| mesa de fósseis | monta esqueletos e expõe coleções, com recompensa por coleção completa |

Criaturas fora do Círculo trabalham nos sítios, como no Palworld. Cada família tem uma ou duas aptidões, como minerar, regar, acender, carregar, assombrar e pescar, o que dá uso a criaturas repetidas além da destilação. A produção acumula com o tempo, calculada ao abrir o app como os lures, e só é recolhida indo ao sítio.

Figuras do fórum Limen passam a visitar a casa quando o jogador cumpre certas condições, como os NPCs do Terraria que se mudam quando há casa para eles. Cada uma traz ofertas e pedidos ligados a um ofício.

### Mecânicas de outros jogos

Só entram as que servem a um jogo de andar na rua sem batalha.

| Jogo | Mecânica | No Kenoma |
| --- | --- | --- |
| Terraria | força de ferramenta, par de minério por mundo, hardmode, altares que semeiam minério, NPCs que se mudam | linha de minérios, O Rasgo, Pedras de Fenda, visitas do Limen |
| Palworld | aptidões de trabalho na base | criaturas trabalhando nos sítios |
| Pokémon | subsolo de Diamond e Pearl, ovos que chocam andando no GO | grade de escavação, casulos do Véu que abrem com quilômetros andados |
| Stardew Valley | qualidade em estrelas, pacotes do Centro Comunitário, museu, profissões nos níveis 5 e 10 | estrelas em peixes e minérios, pedidos em pacote do Limen, mesa de fósseis, escolha de profissão nos ofícios |
| Guild Wars 2 | maestrias, mirantes, coleções que levam a um lendário | maestrias, mirantes em pontos altos reais, relíquias feitas de coleções completas |
| RuneScape | habilidades que sobem com o uso | ofícios de pesca e escavação, de 1 a 10, que depois do 40 alimentam as maestrias |

### Fases propostas

Escavação, detector, faixas 1 a 3 e mesa de fósseis na fase 2, junto com a casa. Pescaria, sítios anexos, gemas, faixas 4 a 7, ofícios e minibosses de isca na fase 3. O Rasgo e os metais dos Aethyrs no Futuro, junto com as maestrias. Dinossauros como panteão de expansão.

## Mapa vivo

O mapa ganha vida com tráfego simulado, viagens com destino e dados reais gratuitos. Tudo é ligável e desligável nos Ajustes do mapa, e o jogo funciona inteiro sem internet.

### Modo Viagem

O jogador escolhe um destino, pela busca ou tocando no mapa, e o veículo. A rota é calculada no próprio celular sobre o grafo de ruas do OSM, só por ruas e caminhos de pedestre, nunca por áreas privadas ou fechadas. Com a rota definida, o jogo entra no Modo Viagem. Acima da velocidade de caminhada nada exige tocar na tela: tudo acontece sozinho e é resolvido na chegada.

| Veículo | Velocidade aceita | O que acontece na viagem |
| --- | --- | --- |
| A pé | até 7 km/h | jogo normal, com a rota desenhada |
| Bicicleta, patinete | até 25 km/h | coleta automática de Fagulhas numa faixa larga ao longo da rota |
| Moto, carro | qualquer | totalmente passivo; Ecos no caminho ficam marcados e a tela vira o Rádio do Véu |
| Ônibus | qualquer | como o carro, com bônus ao passar pelas linhas do Ônibus Espectral |

No carro e no ônibus o jogo vira áudio, o Rádio do Véu, com sons do Véu e falas do mentor e do Familiar. Na chegada abre um baú com o que foi coletado e marcado, proporcional à distância e com teto diário. Os Ecos marcados na viagem ficam guardados por algumas horas para sintonizar depois. Carro, moto e bicicleta têm skins cosméticas, inclusive de temporadas de panteão.

O jogo nunca recompensa dirigir. Em carro ou moto ele pergunta uma vez se o jogador é passageiro, e quem está dirigindo só tem a viagem gravada, com tudo entregue na chegada.

### Tráfego do Véu

Veículos e passantes fantasmas circulam pelas ruas reais, gerados pela seed, pela rua e pela janela de tempo, então o grupo vê o mesmo tráfego na mesma hora. O fluxo segue a hora real: cheio no rush, vazio de madrugada, mais estranho à noite.

| Camada | Fonte | O que acrescenta |
| --- | --- | --- |
| Carros fantasmas | ruas e mão de direção do OSM | param nos semáforos reais |
| Pedestres e ciclistas fantasmas | calçadas e ciclovias do OSM | dão vida às praças e parques |
| Ônibus Espectral | linhas e pontos reais | para nos pontos de verdade, solta Fagulhas; à noite pode aparecer uma linha que não existe |
| Van do Mercador Errante | rota gerada pela seed | o Mercador circula e pode ser alcançado para trocar |
| Carroça de Essência | rota gerada pela seed | interceptada com um toque quando passa dentro da Aura |
| Carro funerário | só à noite | Ecos Espectrais seguem atrás dele |
| Procissão | rota fantasma rara | quem acompanha a pé até o fim ganha uma recompensa |
| Trem fantasma | ferrovias desativadas do OSM | à noite percorre os trilhos mortos de Campinas, com Ecos Espectrais atrás |
| Carro fugitivo | rota gerada pela seed | leva uma criatura rara; o jogador precisa chegar a pé a um cruzamento antes dele |
| Engarrafamento do Véu | Fendas | perto de uma Fenda o tráfego para e se deforma |

Avenidas cheias favorecem tipos urbanos e ruas calmas favorecem espíritos.

### Fontes offline

| Fonte | O que dá | Uso |
| --- | --- | --- |
| OSM, nomes de rua | nomes | rótulos ligáveis no mapa |
| OSM, grafo de ruas | conexões | rota do Modo Viagem |
| OSM, pontos de interesse | igrejas, cemitérios, praças, monumentos, hospitais, pontos de ônibus | altares efêmeros, Ecos Espectrais em cemitérios, rumores citando lugares reais, Tráfego do Véu |
| Wikipedia e Wikidata | marcos históricos com texto | lugares de memória com lore e missões |
| IBGE, setores censitários | densidade de população | mais spawns onde o OSM é pobre |
| Google Open Buildings 2.5D e Overture | contorno e altura dos prédios | prédios com altura da fase 1 |
| Cálculo de sol e lua | dia, noite e fases | iluminação do mapa e fases da lua |
| SRTM | relevo | morros e baixadas |
| Linhas de ônibus (OSM ou extração aberta da EMDEC) | linhas, pontos e frequência | Ônibus Espectral |

### Fontes online

| Fonte | O que dá | Uso |
| --- | --- | --- |
| Nominatim ou Photon | busca de lugar pelo nome | destino do Modo Viagem |
| Open-Meteo | clima, vento, qualidade do ar | chuva no visual e nos spawns, poluição favorecendo Ecos de fuligem |
| NOAA, clima espacial | tempestade geomagnética | tempestade no Véu, evento raro |
| OpenSky Network | aviões reais no céu | sombras do Véu passando no mapa |
| Passagens da ISS | estação espacial visível | estrela cadente do Véu |
| NASA FIRMS | focos de queimada | Ecos de Fogo mais fortes perto de queimadas reais |
| BrasilAPI | feriados | eventos de calendário |
| Wikipedia por proximidade | artigos sobre lugares próximos | lugares de memória em qualquer cidade |
| Overpass API | OSM sob demanda | jogar fora das regiões com pacote |

Algumas fontes pedem chave gratuita ou têm limite para uso não comercial, e precisam ser revistas antes de um lançamento aberto.

Três regras valem para o online. O jogo funciona inteiro sem internet, e o online só acrescenta eventos e visual. A localização enviada a qualquer serviço vai arredondada para cerca de 1 km. O que vem de fora é arredondado por janela de tempo, para amigos no mesmo lugar e hora receberem o mesmo.

### Fontes online opcionais

Online só dá bônus, nunca é obrigação. Bônus pequenos, nunca uma espécie exclusiva de uma fonte, no máximo uma variante ou mais frequência por um tempo. Sem internet, sem permissão ou com o serviço fora do ar, o efeito simplesmente não acontece, sem aviso de erro.

| Fonte | O que dá | Efeito |
| --- | --- | --- |
| iNaturalist | observações reais de fauna e flora | Ecos do tipo correspondente mais comuns por alguns dias perto da observação |
| eBird | aves observadas recentemente | Ecos de Ar e Feéricos mais comuns; aves raras dão variante rara |
| Paleobiology Database e GBIF | locais reais de fósseis | sítios de escavação com bônus de fósseis |
| Blitzortung | raios em tempo real | Ecos Elétricos mais fortes perto de raio real por algumas horas |
| ANA (Hidroweb) | nível dos rios | rio cheio fortalece a Água ao longo dele |
| INPE BDQueimadas | focos de queimada no Brasil | Ecos de Fogo mais fortes perto de focos reais |
| Cemaden | pluviômetros e alertas de chuva forte | Fendas de enxurrada temporárias perto de rios e córregos |
| INMET | estações meteorológicas | calor extremo favorece Fogo, frio favorece Espectral |
| Open-Meteo, vento e UV | vento e índice UV | vento favorece Feéricos, UV alto favorece Luz |
| USGS, terremotos | terremotos no mundo | tremor no Véu, evento global com Ecos de Terra |
| NASA EONET | eventos naturais no mundo | eventos globais do Véu |
| N2YO ou CelesTrak | satélites passando | na lore, olhos dos Que Escutam; passagem visível aumenta a Exposição e traz um sussurro |
| NOAA, aurora | tempestades solares | céu de aurora no mapa |
| NASA APOD | foto astronômica do dia | post diário no fórum Limen |
| Wikipedia, mais lidos | artigos mais lidos do dia | rumores no fórum, como Lendas Urbanas |
| Resultados de futebol | jogos de Ponte Preta e Guarani | dia de Dérbi Campineiro vira evento local |
| CityBikes | estações de bicicleta compartilhada | ponto de troca de veículo no Modo Viagem fora de Campinas |
| Dados abertos de Campinas | conjuntos da prefeitura | a garimpar: árvores, praças e patrimônio tombado como altares e lugares de memória |

Entram também, offline, o mapa de poluição luminosa (VIIRS), em que espíritos e Sombra preferem o escuro e Luz prefere o iluminado, e o calendário de chuvas de meteoros, em que as noites de chuva soltam Fagulhas raras.

Não se usam dados de criminalidade, localização de pessoas em tempo real, nada que leve a lugares perigosos ou privados, nem contas pessoais do jogador em outros serviços.

### Sensores e recursos do celular

| Recurso | O que lê | Uso |
| --- | --- | --- |
| Contador de passos | passos reais | bônus pequeno, como chocar casulos; funciona sem GPS |
| Barômetro | andares subidos | bônus de subir prédios; só onde o sensor existir |
| Sensor de luz | escuro real | espíritos noturnos mais frequentes |
| Inclinação | ângulo do celular | jeito alternativo de girar o dial |
| Magnetômetro | variações magnéticas | detector de metal real na escavação e Ecos de Metal perto de metal |
| Microfone, volume | ruído, sem gravação | barulho favorece Urbano e Elétrico, silêncio favorece espíritos |
| Microfone, altura do som | assobio ou cantarolar | sintonia por voz, também como acessibilidade |
| Câmera com reconhecimento no aparelho | árvore, água, fogo na foto | Fagulha do tipo correspondente, sem enviar a foto |
| Câmera do Véu | imagem ao vivo | ver o Eco sobre a rua antes de sintonizar |
| Sensor de proximidade | celular no bolso | modo bolso, com tela apagada, som e vibração |
| Fone de ouvido | fone conectado | som 3D apontando o Eco mais próximo |
| Relógio Wear OS | pulso | vibra quando um Eco entra na Aura; sintonia simples no relógio |
| Bateria e carregador | carregando em casa | vigília: lures rendem mais durante a carga noturna |
| Widget | nada novo | Familiar com a lua do dia e Ecos próximos na tela inicial |

### Conexão entre aparelhos e internet sem servidor

| Recurso | Como funciona | Uso |
| --- | --- | --- |
| Bluetooth e Nearby Connections | celulares próximos se falam direto | troca de criaturas, ritual em dupla, bônus de grupo, Fenda que só abre com três amigos |
| NFC | encostar aparelhos ou etiquetas | troca rápida; etiquetas NFC viram relíquias físicas escondidas pela cidade |
| Contagem de redes Wi-Fi e Bluetooth | só a quantidade | multidão real traz os Ecos de multidão |
| Arquivos estáticos assinados (GitHub Pages) | JSON assinado publicado de graça | épocas, eventos, Lua Carmim, códigos e as falas do mentor sem atualizar o app |
| Google Drive do jogador | pasta oculta do app na conta dele | backup automático na nuvem, sem servidor próprio |
| Trocas por código assinado | par de chaves por jogador, QR ou link por qualquer mensageiro | trocar criatura com amigo distante |
| Cartões compartilháveis | imagem com QR | mostrar capturas nos stories; o QR abre o bestiário |
| Deep links | links que abrem o app | convite de grupo e oferta de troca em um toque |

Permissões são pedidas só quando o recurso é ligado, nunca na instalação. Microfone e câmera são analisados no aparelho, sem gravação nem envio, e Wi-Fi e Bluetooth viram só contagem. Nada desta lista é obrigatório para jogar.

Fases sugeridas: arquivos estáticos assinados, backup no Drive, contador de passos e modo bolso na fase 1; Bluetooth, NFC, trocas por código, cartões e as fontes de clima na fase 2; o resto na fase 3 ou como expansão.

### Fases

Nomes de rua, sol e lua e Tráfego do Véu ambiente na fase 1. Modo Viagem com rota, veículos especiais do tráfego, pontos de interesse e clima na fase 2. Demais fontes online, trem fantasma, carro fugitivo e prédios com altura junto com a fase 3 ou como expansão.

## Fendas e dungeons

Fendas são o coração do jogo. Aparecem pelo mapa em células grandes, alteram o cenário ao redor e abrigam Soberanos, artefatos e páginas de grimório. Selar uma Fenda é um grande ritual feito na borda dela, e o Soberano lá dentro só é contido com o Círculo certo.

### Ciclo de vida da Fenda

| Estado | Duração | Comportamento |
| --- | --- | --- |
| Nascente | curta | recém-aberta, nível base |
| Estável | alguns dias | nível base |
| Crescendo | até o teto | sobe um nível por dia, até cerca de três acima do base |
| Instável | alguns dias | no teto, loot máximo |
| Colapso | pontual | libera onda de Ecos corrompidos por algumas horas |
| Cicatriz | um dia | materiais residuais, depois a célula fica livre |

Tudo é calculável a partir da data de nascimento e da seed. O aparelho só guarda quais Fendas o jogador já selou. Rituais podem acalmar uma Fenda e impedir o crescimento.

### Dungeons fixas

Pontos onde dá para ficar parado (praças, parques, mirantes) vêm do OSM, e a seed escolhe alguns como dungeons. Cada dungeon é uma Incursão de origem Dungeon, com tema pelo bioma e recompensa exclusiva do local.

### Pontos sugeridos

Futuramente jogadores submetem sugestões de pontos de interesse via formulário ou issue no GitHub. Pontos aprovados entram no próximo pacote de região e podem virar dungeons.

## Incursões

Um único sistema para dungeons, núcleos de Fenda e a Fenda Profunda. A base é simples, e cada origem acrescenta as próprias regras.

Uma incursão é uma sequência de salas numa pequena rota ramificada, em que o jogador escolhe o caminho. Cada sala é um encontro de um tipo: sintonia, ritual, escolha com risco, descanso, tesouro ou guardião. A Exposição ao Véu acumula ao longo da incursão e só baixa nas salas de descanso. No fim há um guardião e a recompensa. Dungeon e Fenda exigem estar no lugar para entrar, e depois podem ser continuadas de qualquer lugar.

| Origem | Onde | Duração | Regra própria |
| --- | --- | --- | --- |
| Dungeon | lugar fixo do mapa | 10 a 20 min | tema pelo bioma, recompensa exclusiva do local, repetível por semana |
| Fenda | núcleo de uma Fenda aberta | 15 a 30 min | regras do Aethyr, Soberano como guardião, some quando a Fenda colapsa |
| Casa | Fenda Profunda | sem fim | andares pela seed do dia, Exposição sem descanso, recorde pessoal |

Novas origens, como eventos, panteões ou pactos, entram acrescentando tipos de sala e regras sem mudar o sistema.

## Quests

Quests têm dono. O fórum entrega pedidos rápidos e rotineiros, o mentor entrega desafios que fazem o Conjurador crescer. Isso separa o ritmo pelo personagem que fala, e cada fonte rende uma recompensa diferente.

| Fonte | Frequência | Formato | Recompensa principal |
| --- | --- | --- | --- |
| Fórum ocultista | 3 por dia | pedidos curtos de usuários fictícios | materiais, reputação |
| Fórum ocultista | 1 por semana | rumor completo com dedução | Entidade com bônus de captura, reputação |
| Mentor | 1 por semana | desafio de progressão | páginas de grimório, itens de ritual |
| Mentor | por nível | quests de história | desbloqueio de apps, escolas e Aethyrs |
| Diário do Conjurador | contínuo | metas longas de coleção | títulos, cosméticos |

### Diárias do fórum

Três pedidos por dia, somando algo como 15 a 20 minutos de caminhada. Cada pedido sai de uma categoria diferente, e pelo menos um pode ser feito em casa para dias de chuva ou sem sair.

- Explorar, como revelar células novas ou visitar um bioma específico.
- Coletar, como materiais de qualidade alta ou de uma condição real.
- Caçar, como capturar criaturas de um tipo ou por um método específico.
- Fabricar, como produzir um item ou descobrir uma receita nova.
- Casa, como montar um lure ou enviar uma expedição.

Um reroll por dia. O texto é escrito como post de fórum ("alguém consegue orvalho de lua cheia? pago bem"), o que mantém a fantasia.

### Semanal do mentor

Um desafio maior ligado à progressão atual, como selar uma Fenda de certo nível, completar um ritual pela primeira vez ou fundir um Espírito. O mentor comenta o resultado no chat, e essas quests carregam a história entre os marcos de nível.

### Geração

Quests saem de templates preenchidos por `hash(seed_global, época, data, slot)`, com parâmetros escalados pelo nível do jogador. Amigos recebem os mesmos pedidos no mesmo dia, o que cria comparação natural sem servidor.

Duas regras evitam quests impossíveis. Pedidos de bioma só escolhem biomas existentes num raio caminhável da casa ou em células já reveladas. Pedidos de condição real consultam as condições do dia, então num dia de chuva real aparece "colete água de chuva" e numa lua cheia aparece caça a Feéricos.

### Constância sem punição

Em vez de sequência de dias consecutivos que zera ao falhar, a recompensa semanal conta dias jogados na semana. Jogar 4 de 7 dias libera o bônus completo. Isso incentiva voltar sem transformar o jogo em obrigação.

## Aethyrs e dimensões

Cada Fenda leva a um lugar do outro lado do Véu, e esse lugar aparece sobre a própria cidade, como o Mundo Invertido de Stranger Things. Ao entrar numa Fenda, o mapa real num raio em volta dela vira a versão daquele lugar por tempo limitado: as mesmas ruas e prédios, com cores, criaturas, materiais e regras de lá. O jogador continua andando pela cidade real, e o núcleo da Fenda é uma Incursão. No jogo base os destinos são ZAX e os Aethyrs dos Trinta. Dimensões de outros panteões chegam com as expansões.

| Lugar | Quando | Regra especial |
| --- | --- | --- |
| Kenoma | sempre | a cidade real, regras normais |
| ZAX, o Abismo | Fendas comuns e Fenda Profunda | visão curta, Exposição sobe rápido, estática na tela, melhor loot |
| Aethyr de uma família | Fendas de nível médio, Ato III em diante | paleta e regra do deus daquela família, criaturas da família mais fortes |
| Aethyrs superiores (Eras Antigas) | fim do Ato IV | lar dos dragões inteiros e das memórias dos Trinta, acesso tardio |

### Dimensões de expansão

Cada expansão traz a dimensão do seu panteão, com mecânica própria.

| Dimensão | Panteão | Tipo associado | Regra especial |
| --- | --- | --- | --- |
| Dimensão Feérica | fadas celtas | Feérico | tempo distorcido, ilusões, trocas enganosas |
| Duat | egípcio | Espectral | viagem noturna da barca do sol em rotas reais, pesagem do coração |
| Kur | sumério | Sombra | descida em andares, perdendo algo a cada portão |
| Inferno | a definir | Fogo | a tolerância do dial cai com o tempo, pactos infernais |
| Plano Celeste | a definir | Luz | alvos Divinos, criaturas de Luz do Círculo contam em dobro |

### Dimensão Feérica

Candidata à primeira expansão, por ter a identidade mais forte. O tempo corre diferente, então uma incursão pode render como horas de lure ou de expedição. As trocas lá dentro são com fadas, parecidas com o Mercador Errante, mas com cláusulas ocultas que só se revelam depois. Ilusões fazem criaturas parecerem de outro tipo até o scanner de nível alto revelar. A entrada é por Fendas em áreas verdes no crepúsculo.

### Convergência

Quando uma dimensão está forte, ela vaza para o mapa real. Em convergência Feérica os parques brilham no crepúsculo, em convergência Infernal ondas de calor reais aumentam spawns de Fogo e o céu escurece. As temporadas de panteão passam a ser convergências de dimensão.

## Direção de arte

O estilo se chama Véu e tem uma regra central de contraste. A cidade é comum, fria e dessaturada, e só o que é mágico tem cor saturada e brilho. Os prompts completos para gerar referências estão na aba Prompts de arte.

### Regras de estilo

- Pixel art híbrido. Mapa, prédios, criaturas e personagem são pixel art em escala fixa, sem misturar tamanhos de pixel no mesmo elemento. Luz, brilho da magia, costuras do Véu, partículas e interface podem ser suaves, com glow e transparência. Referências: Octopath Traveler, Sea of Stars, Hyper Light Drifter.
- Tiles de 16 px e sprites de criatura de 48 px, contorno de 1 px em ameixa escuro #1a1424, nunca preto puro, e paleta limitada nos sprites.
- Cidade em tons frios dessaturados, sem placas, texto, carros ou pessoas, e sem nada mágico fora de Fendas e eventos.
- Magia é a única cor forte do jogo, em violeta #9b7bff, ciano #5fd3c6 e laranja brasa #ff7a45, com brilho suave permitido.

### Costura do Véu

Toda criatura tem costuras violeta brilhantes onde partes se perderam ao atravessar o Véu. Camadas baixas têm várias costuras e camadas altas têm menos. É a assinatura visual do jogo e mostra a progressão sem precisar de texto.

### Cores com significado

As três cores da magia têm sentido fixo, para o jogador ler a cena sem texto. Violeta é o Véu e os Trinta, em costuras, Fendas e sigilos. Ciano é o sinal, o celular e Os Que Escutam, e cresce na tela com a Exposição, então muito ciano quer dizer que alguém está olhando. Laranja brasa é Essência e vida, em Fagulhas, destilação e crafting.

### Formas por camada

A estranheza cresce com a camada, na linguagem dos Errata, erros nas leis da realidade no espírito das Ultra Beasts, e dos Ediacaranos, a vida de 570 milhões de anos atrás anterior à simetria bilateral, como Dickinsonia, Charnia e Tribrachidium. Fagulhas e Ecos são legíveis e simpáticos, com formas simples de bicho ou objeto. Espíritos começam a ter partes em número errado. Entidades Maiores e Arquétipos usam simetria radial ou tripla, rosto ausente ou fora do lugar e geometria impossível, e cada um quebra uma regra física e uma regra do jogo. Divindades e Soberanos são quase abstratos. Assim o começo é acolhedor e o fim é realmente de outro mundo.

### Os Que Escutam e o Aklo

Os Que Escutam nunca aparecem por inteiro. Surgem só como estática, falhas de interface e formas no ruído da tela, sem sprite próprio. A fala deles é o Aklo, com glifos desenhados a partir das formas de onda do dial, como traços de osciloscópio, o que liga a escrita das entidades à mecânica de captura. Divindades e Aethyrs têm nomes enoquianos, e famílias comuns têm nomes simples e descritivos.

### Aethyrs e expansões

Cada Aethyr é uma troca de paleta sobre a cidade, e ZAX é preto violeta com estática. Cada expansão traz uma cor de destaque e sua skin de interface sem mexer na base, o que casa com as skins de temporada.

### Interface

UI limpa no estilo do Pokémon GO. O mapa mostra só três elementos, o botão central em forma de celular rachado, o retrato do jogador com nível no canto esquerdo e o rastreador de criaturas próximas no direito. Não há cartão de encontro, o jogador toca direto na criatura.

Todos os menus vivem dentro do celular do Conjurador. Tocar no botão central é o personagem tirando o celular do bolso, e cada sistema é um app (Bolsa, Círculo, Bestiário, Bancada, depois Grimório, Fórum e Chat). Apps ainda não desbloqueados aparecem como rachaduras. O botão também é a central de avisos, pulsando quando chega algo novo.

### Câmera

A câmera tem ângulo 3/4 fixo e só gira em torno do eixo vertical. O jogador gira o mapa arrastando um dedo, sem controle de inclinação nem de perspectiva, porque inclinar não tem função de jogo. Um toque na bússola volta o norte para cima.

- Personagem, criaturas e efeitos são sprites 2D sempre em pé e virados para a tela, em qualquer rotação. O tamanho é em metros do mundo, numa escala que exagera tudo um pouco mas mantém as proporções entre si: Conjurador e Familiar com 6 m de altura, sempre menores que a largura da rua, pedestres fantasmas com 4,5 m, carros fantasmas com 6 m de comprimento, Ecos com 7 m (Espíritos e camadas acima maiores) e Fagulhas com 3 m. A área de toque de qualquer coisa tocável tem no mínimo 48 dp, mesmo quando o sprite é menor.
- Prédios são desenhados em 2D a partir dos contornos do OSM, projetando telhado e paredes conforme o ângulo atual. Com inclinação fixa essa projeção é simples e roda no Flame, sem motor 3D.
- A cena é renderizada numa resolução baixa, com o pixel de arte valendo 2 dp na tela, e ampliada por vizinho mais próximo, mantendo os pixels nítidos e sem tremor durante o giro.
- Girar a câmera também é a forma principal de ver atrás de um prédio. O esmaecimento continua para quando o jogador não girar.
- A interface nunca gira. A bússola aparece só enquanto o mapa estiver fora do norte.

### Prédios

- Os contornos vêm do OSM, então a planta bate com a cidade real. Imagens geradas por IA servem só de referência de estilo.
- Altura visual máxima de dois tiles, independente da altura real, para manter a leitura e reduzir oclusão.
- Prédio que tampa o jogador fica semitransparente, com o contorno do personagem visível por cima.
- Prédios são comuns por padrão. Perto de Fendas ganham costuras violeta, janelas ciano e pedaços flutuando, com o efeito diminuindo pela distância. Eventos têm variações próprias, como janelas vermelhas na Lua Carmim.
- Na Fase 0 o mapa fica em visão de cima sem prédios em pé. Prédios com altura entram na Fase 1, o que exige o pipeline guardar contornos além da grade de biomas.

## Arquitetura técnica

Tudo roda no aparelho. Rede é opcional e só para dados estáticos gratuitos.

### Pipeline de mapa

1. Baixar o extrato OSM da região (Geofabrik, por região, como sudeste).
2. Pré-processar no PC, classificando cada célula da grade num bioma a partir das tags OSM.
3. Exportar como binário compacto por região, alguns MB.
4. Embarcar no app ou distribuir como pacote de região atualizável.
5. Desenhar o pixel art proceduralmente a partir da grade.

Só as regiões onde alguém joga precisam de pacote, no início Campinas e São Paulo. O script roda uma vez por região e pode ser automatizado com GitHub Actions, publicando os pacotes no GitHub Releases para o app baixar quando tiver internet.

### Fallback sob demanda

Em lugares sem pacote, o app consulta a Overpass API só para a área ao redor do jogador, classifica os biomas no aparelho e guarda em cache por blocos de 1 km. Depois do primeiro acesso a área fica disponível offline.

O determinismo entre jogadores se mantém fixando a data da consulta: toda consulta usa o parâmetro de data da Overpass com o instante de início da época vigente, então dois aparelhos que consultam a mesma área em dias diferentes recebem os mesmos dados do OSM. A classificação no aparelho precisa usar exatamente as mesmas regras do pipeline, e o pacote gerado em Python serve de oráculo nos testes. Se isso se mostrar confiável, o fallback pode virar o caminho principal e os pacotes embutidos deixam de ser necessários. Fica para depois da Fase 0, que usa só o pacote de Campinas.

### Dados e conteúdo

Panteões são pacotes de dados (JSON de criaturas, fusões, loot, receitas, sprites). O panteão próprio é o pacote zero, e panteões externos se plugam no sistema de Fendas sem mudar código.

### Serviços externos gratuitos

| Uso | Fonte | Sem internet |
| --- | --- | --- |
| Clima | Open-Meteo, sem chave | clima determinístico pela seed |
| Eventos forçados | JSON estático no GitHub Pages | calendário embarcado |
| Astronomia | cálculo local | não depende de rede |
| Sugestão de pontos | formulário ou GitHub issues | não disponível |

### Salvaguardas

Sem servidor não há anti-cheat real. As proteções visam só o grupo de amigos.

- Tempo do GNSS em vez do relógio do sistema, e checagem de que o tempo nunca retrocede. Evita rolar spawns mudando a hora.
- Checagem de velocidade entre leituras de GPS.
- Detecção de mock location no Android.

### Save, segundo plano e tempo

- Save local com backup por arquivo e Google Drive desde a fase 0 (ver Formato do save).
- GPS só com o app aberto. A distância com o app fechado vem do contador de passos do sistema, usado nas recompensas de caminhada (companheiro, smartwatch, Ley Lines).
- Notificações locais para lures, invasões, pedidos do patrono, Fendas crescendo e Lendas chegando ao Mito.
- Janelas de spawn, eventos e ciclos são calculadas em UTC. Só a exibição usa o horário local.

### Formato do save

JSON comprimido com `schema_version`, `app_version`, `epoch`, `seed_global`, UTC de criação e do último save e o último horário visto (last\_seen\_utc), seguido de Conjurador, criaturas, Círculo, inventário, bestiário e registro de coletas.

1. Espécies e itens usam IDs estáveis em texto, como `soot.eco`, nunca índices, para as tabelas poderem mudar entre Épocas sem corromper saves antigos.
2. O ID de cada spawn sai do hash de seed, época, célula, janela e índice do item. O mesmo spawn não pode ser capturado duas vezes mesmo depois que o registro de coletas, que guarda só as últimas 48 horas, for limpo.
3. Cada versão do formato tem uma migração pura para a seguinte, testada com saves de exemplo. Campos desconhecidos são preservados.
4. A escrita é atômica, num arquivo temporário renomeado depois, com os 3 últimos saves em rodízio e checksum para detectar corrupção.
5. O backup é por arquivo e Google Drive. Um save com dezenas de criaturas passa dos cerca de 2,9 KB que cabem num QR code, então o QR fica só para compartilhar a seed do grupo entre amigos.

### Épocas

Sem servidor, amigos com versões diferentes do app gerariam mundos diferentes a partir da mesma seed. Por isso toda mudança de conteúdo que afeta o mundo (tabelas de spawn, coleta e materiais, biomas, pacote de região, Fendas) só entra em vigor numa data UTC fixa, o início de uma Época, que coincide com o início de uma estação do ano. Cada versão do app já vem com as tabelas da Época atual e da seguinte, e o número da Época entra no hash. Quem demorou a atualizar continua sincronizado com os amigos até a virada.

Se o app não tiver as tabelas da Época vigente, ele mostra o aviso de mundo desatualizado e segue gerando pela última Época conhecida, deixando claro que os spawns podem diferir dos amigos. Correções que não mudam o mundo, como interface, bugs e balanceamento de crafting, saem a qualquer momento.

### Assinaturas, fundadores e controles

Sem servidor, a confiança vem de assinatura digital. O desenvolvedor tem um par de chaves Ed25519: a chave privada fica só com ele, fora do repositório, e o app leva só a chave pública. O app consegue verificar o que foi assinado, mas não consegue assinar nada, nem desmontado. Hash embutido no app não serve para isso, porque qualquer segredo dentro do APK pode ser extraído.

O save registra a história do jogador desde a primeira abertura: um `player_id` aleatório de 128 bits, a primeira versão instalada, a data UTC e um log das versões abertas, encadeado por hash. O log não prova nada sozinho, mas detecta edição casual e serve de evidência para o desenvolvedor.

| Item assinado | Para quê |
| --- | --- |
| Certificado de fundador | prova que o jogador esteve no beta; vale só para o `player_id` dele e libera recompensas cosméticas por faixa de versão de entrada |
| Épocas | garante que um `epochs.json` vindo de fora do app foi publicado pelo desenvolvedor |
| Códigos de evento | recompensas de temporada, de encontros presenciais ou de presente, pelo mesmo mecanismo do certificado |
| Lista de revogação | cancela certificados ou códigos abusados; viaja dentro das épocas assinadas |
| Certificado de desenvolvedor | libera o menu de debug numa build de release |

O certificado de fundador é emitido sem servidor. O jogador mostra no Ajustes um QR com o `player_id` e o log de versões, o desenvolvedor lê com um script no PC, decide a faixa e devolve o certificado como QR ou código. Quem entrou nas versões 0.x ganha a recompensa mais rara. As recompensas são só cosméticas: forma do Familiar, título no fórum Limen, moldura no bestiário. Quem entrega é o mentor.

O menu de debug fica sempre acessível nas builds de teste e mostra tudo isso: `player_id`, log de versões, certificados presentes, assinatura e validade da época, lista de revogação e códigos resgatados. Na versão pública ele só abre com o certificado de desenvolvedor.

### Produção com IA

Código, arte e conteúdo serão gerados por IA. Pixel art gerado por IA costuma sair fora da grade de pixels, com paleta inconsistente e identidade variando entre imagens, então todo sprite passa por um pipeline fixo.

1. Definir uma paleta única do jogo (por volta de 32 cores) e uma resolução de sprite (48 px).
2. Gerar em alta resolução com um modelo ou LoRA de pixel art.
3. Reduzir com nearest neighbor para a grade e quantizar para a paleta do jogo por script.
4. Limpar pixels soltos manualmente ou com um passo automático simples.
5. Gerar formas da mesma família com img2img a partir da camada anterior, para manter a identidade.
6. Aplicar variantes por troca de paleta em código, nunca gerando de novo.

Animação é o ponto mais fraco da geração por IA. Sprites com 2 a 4 quadros de idle e efeitos de partícula em código contorna isso. Tilesets do mapa precisam emendar sem costura, então valem ser gerados em blocos pequenos e ajustados à mão, ou partir de tilesets CC0 recoloridos na paleta. Trilha e efeitos sonoros gerados por IA devem ter os termos de uso da ferramenta conferidos caso o jogo saia do círculo de amigos.

### Áudio

Trilha adaptativa em camadas (stems) que entram e saem conforme bioma, horário, Exposição e proximidade de Fenda. Chegar perto de uma Fenda adiciona uma camada dissonante antes de ela aparecer na tela.

## Roadmap

Este GDD é a visão de longo prazo, não o escopo de implementação. Cada sistema tem uma prioridade, e só o Núcleo precisa existir para o jogo ser jogável. Se o Núcleo não for divertido depois de duas semanas jogando na rua, nenhum sistema de expansão resolve.

### Prioridades

- Núcleo é o mínimo que precisa ser divertido sozinho.
- Expansão são sistemas que entram em cima de um Núcleo validado, em fases.
- Futuro é visão. Fica documentado, mas não é planejado nem estimado até as expansões estarem prontas.

### Fases

| Fase | Prioridade | Sistemas | Critério para avançar |
| --- | --- | --- | --- |
| 0 | Núcleo | pipeline OSM da região, mapa pixel art procedural, spawns determinísticos, Fagulhas e Ecos de 3 famílias curtas, tipos dos biomas do MVP, sintonia por dial com resistência por tipo, marcação, Essência e destilação de Ecos, Círculo com habilidades de mapa, crafting de selos e tônicos, nível do Conjurador até 15, seed do grupo por QR, bestiário básico, save local com backup, janelas em UTC | jogar duas semanas andando e ainda querer abrir o app |
| 1 | Expansão | horários e astronomia offline, prédios com altura e rotação da câmera, clima, névoa de guerra, rastros e scanner, comportamento das criaturas, variantes de bioma e Brilhante, qualidade de material, descoberta de receitas, coletores, refino, receitas de lua e estação do ano, Espíritos e fusão, ritual básico, atributos e níveis do Conjurador até 20, notificações locais, Familiar, tutorial com mentor e fórum no chat, escolha de escola com bônus de captura, diárias do fórum | loop de rua completo e variado |
| 2 | Expansão | casa, estações no mundo, gadgets, combinação de equipamentos, Constelações, lures, decoração, expedições, estabilidade, companheiro, vínculo | jogo se sustenta em dias sem sair |
| 3 | Expansão | Fendas com ciclo de vida, Incursões de dungeon e de Fenda, Soberanos, tipos Dracônico, Feérico e Digital, Artificiais e Quimeras das escolas, Entidades Maiores, Exposição ao Véu, mecânicas exclusivas das escolas, linhas de especialização, build com magias e transcrição, níveis até 40, troca de escola, magias, grimórios, fase de pressão do ritual, rituais de mundo, grandes obras, receitas de janela, altares efêmeros, Corrompidas, história completa do mentor, semanal do mentor, Mercador Errante | progressão do Conjurador completa |
| Futuro | Futuro | dimensões e panteões de expansão, Arquétipos, Divindades e Primordiais, marcas Singular, Lenda Urbana, Divino e Herói, rumores com dedução, Fenda Profunda, invasões, maestrias, especializações avançadas, amuletos de ciclo, Ley Lines próprias, pactos, Divindades e Avatares, modo trânsito, trilha adaptativa, eventos de calendário e Lua Carmim, convergências e panteões externos, social, sugestão de pontos, anti-cheat robusto, minigames extras de sintonia, cosméticos | revisado quando a fase 3 estiver pronta |

A progressão de criaturas está unificada. Fusão e estabilidade são pagas com Essência, o Familiar cresce com o nível do Conjurador, e módulos são dos Artificiais, e os Implantes do Tecnomante são a única forma de instalá-los em outras criaturas.

As tabelas de níveis e do tutorial descrevem o jogo completo. Enquanto a fase de um sistema não chega, o nível correspondente só libera o que já existe. No MVP, por exemplo, não há casa e a bancada roda dentro do app.

### Questões em aberto

- [x] Título do jogo: Kenoma: Veilbreakers (ver Apêndice).
- [x] Nome e identidade do panteão próprio: Shloshim, conhecido como The Thirty, com 29 famílias e o Familiar (ver Lore e Direção de arte).
- [x] Tamanho exato das células e duração das janelas de spawn: z20 com janelas de 20 minutos deslocadas por célula (ver Geração determinística).
- [x] Curva de experiência e nível máximo do Conjurador: nível 40 em cerca de 3 meses, maestrias de 30 níveis até o quinto ano (ver Curva de experiência e maestrias).

## Apêndice · Nomes e panteões (rascunho)

Material de referência. O título, o nome do panteão e a identidade central já estão nas seções Lore, História, Aethyrs e dimensões e Direção de arte. O resto está em avaliação.

### Título

Decidido: Kenoma: Veilbreakers. Kenoma é o termo gnóstico para o vazio, o mundo material imperfeito. A leitura do jogo é que o mundo real é o vazio e as Fendas vazam a plenitude que existe do outro lado. Outros subtítulos que foram considerados: Veil Riders, Beyond the Veil, The Listening Dark, Where the Veil Is Thin, Sparks in the Hollow, Static Saints.

Outros candidatos a título: Laiad, Aklo, Thin Places, Veilcaller, Afterglow. Isfet e Zax são fortes, mas já aparecem em outras obras. Veilbreakers não tem jogo grande com o mesmo nome, mas existem uma série de livros, um webtoon e uma banda; conferir marca antes de qualquer publicação.

### Banco de nomes

Termos enoquianos conferidos no dicionário de Dee e Kelley editado por Laycock. Os marcados com asterisco vieram de memória e precisam ser conferidos.

| Nome | Origem | Significado | Uso possível |
| --- | --- | --- | --- |
| Laiad | enoquiano | segredos | título |
| Teloch | enoquiano | morte | deus de ZOM, Espectral |
| Vovina | enoquiano | o dragão | deus de ARN, Dracônico |
| Telocvovim\* | enoquiano | dragão da morte, aquele que caiu | Soberano de ARN |
| Ialprg | enoquiano | chamas ardentes | deus de BAG, família Soot |
| Vonpho | enoquiano | ira | deus de ZID, Fogo |
| Iaida | enoquiano | o altíssimo | deus de LIL, Luz |
| Oxiayal | enoquiano | trono poderoso | deus de OXO, Metal |
| Vaoan | enoquiano | verdade | deus de ICH, Metal |
| Zumvi | enoquiano | mares | deus de RII, família Rill |
| Ozongon | enoquiano | ventos | deus de MAZ, Elétrico |
| Ors\* | enoquiano | escuridão | tipo Sombra |
| Ethamz\* | enoquiano | coberto, oculto | nome do Véu |
| Madriax\* | enoquiano | céus | Plano Celeste |
| Zax\* | enoquiano | 10º Aethyr, o Abismo | Véu ou Fenda Profunda |
| Choronzon\* | tradição enoquiana e Crowley | demônio da dispersão | Soberano final |
| Aklo | Arthur Machen, 1904, domínio público | língua proibida das fadas antigas | língua das entidades |
| Kenoma | gnóstico | o vazio, o mundo material | título |
| Pleroma | gnóstico | a plenitude divina | o que vaza pelas Fendas |
| Archon | gnóstico | carcereiros do mundo material | classe de Soberanos |
| Aeon | gnóstico | emanações divinas | classe de Divindades |
| Qliphoth | cabala | cascas que prendem centelhas | panteão de expansão |
| Sitra Achra | aramaico cabalístico | o outro lado | nome das dimensões |
| Tohu | hebraico | caos informe antes da criação | Primordiais |
| Isfet | egípcio antigo | caos, oposto da ordem | tipo ou panteão |
| Duat | egípcio antigo | submundo | Submundo |
| Heka | egípcio antigo | magia como força | nome alternativo da Essência |
| Nun | egípcio antigo | águas primordiais | Primordial aquático |
| Kur | sumério | montanha e submundo sem retorno | dimensão |
| Namtar | acadiano | destino, demônio mensageiro | arauto de Soberano |
| Gallu | acadiano | demônios que arrastam ao submundo | família de Ecos |
| Vanth | etrusco | guia alada dos mortos | forma do Familiar |
| Ginnungagap | nórdico antigo | abismo antes do mundo | Fenda Profunda |
| Nigredo | latim alquímico | putrefação, primeira etapa da obra | camada ou tipo |
| Azoth | alquímico | solvente universal | Essência Divina |
| Limen | latim | limiar | Aura ou Fendas |

### Panteões para expansões

Cada panteão externo traz a própria identidade quando é introduzido, sem mudar a história principal. Ele entra pelas Fendas ou por convergência, com criaturas, grimório, dimensão e cosméticos próprios.

| Panteão | Ideia | Identidade |
| --- | --- | --- |
| As Cascas (Qliphoth) | um vaso divino se partiu e as centelhas ficaram presas em cascas; cada criatura é uma casca e destilar liberta a luz | casca rachada, luz vazando, ouro sobre preto |
| Os Arcontes | carcereiros que construíram o Véu para manter o mundo fechado; selar Fendas reforça a prisão | geometria rígida, olhos de leão, planetas; pode ser absorvido pela lore central por causa do título |
| Nun e Isfet | antes da criação só havia água escura, e o caos tenta voltar | preto, dourado e lápis-lazúli, chacais desfeitos em água |
| The Hollow Choir | deuses que eram frequências, abafados pelo silêncio do Véu | halos de diapasão, sigilos em onda, vitral rachado |
| The Veilwrights | deuses que teceram o Véu, que agora se desfia | fios dourados, teares |
| The Undercourt | corte divina da cidade embaixo da cidade | ferro art nouveau, laranja de lâmpada de sódio |
| Kur | submundo sumério sem retorno, com Namtar e os gallu | argila, cuneiforme, asas de pedra |

### Temporadas de panteão e skins

Quando uma temporada de panteão está ativa, o jogo aplica skins daquele panteão na interface do celular, nas roupas do Conjurador, nos sons e nos efeitos do mapa. Completar as quests da temporada libera o uso dessas skins fora de época, como recompensa permanente. As skins são só visuais, seguindo a regra dos cosméticos. As datas das temporadas seguem as Épocas, então todos os amigos veem a mesma temporada ao mesmo tempo.
