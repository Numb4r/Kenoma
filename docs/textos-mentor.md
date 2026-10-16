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
| 10 | `m10` | 40 s | - | Escolha até três criaturas para o seu Círculo. Cada uma melhora o seu mapa: Aura maior, coleta mais longe, rastreador mais fundo. E um tipo forte facilita a sintonia contra o tipo que ele vence. Fogo vence quem mesmo? |
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
| 4 | `fusion_f01` | fusion ≥ 1 | *O Familiar encosta a testa na tela quando as costuras se fecham e fica assim, parado, até o Espírito respirar. Depois dá uma volta devagar em torno dele. Parece dizer: agora são um só.* |

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

## Fórum Limen: pedidos diários

Três pedidos por dia, sorteados por `hash(seed, época, data, slot)`. O texto tem `{n}` (a meta), `{tipo}` (Fogo, Planta, Água ou qualquer tipo) e `{item}` (giz, ervas, água pura). Usuários: `vesper`, `static_saint`, `mapmaker`, `null_hypothesis`, `candlewick`, `wren_`.

### `walk` · explorar · mapmaker
Conta o evento `walk_m`, meta de 500 a 1500 (cresce com o nível). Recompensa: 150 XP e 1× `item.chalk`.

- alguém consegue andar uns {n} m por aí hoje? preciso saber se o sinal muda de um quarteirão para o outro.
- mapa novo pela metade. quem sai de casa hoje e anda {n} m me ajuda a conferir as bordas.

### `sparks` · coletar · static_saint
Conta o evento `spark`, meta de 5 a 12 (cresce com o nível). Recompensa: 150 XP e 1× `item.dust.fire`.

- preciso de {n} fagulhas de {tipo}. pago bem, e não, não vou dizer para quê.
- {n} fagulhas de {tipo} até o fim do dia. o que sobrar eu devolvo.

### `materials` · coletar · candlewick
Conta o evento `material`, meta de 2 a 5 (cresce com o nível). Recompensa: 150 XP e 1× `item.ectoplasm`.

- preciso de {n} de {item}, do tipo que se colhe andando e não do que se compra. alguém?
- quem traz {n} de {item}? é para uma vela, e a vela não pergunta de onde veio.

### `hunt` · cacar · wren_
Conta o evento `capture`, meta de 1 a 3 (cresce com o nível). Recompensa: 180 XP e 1× `item.seal.simple`.

- quero ver {n} sintonia(s) com um Eco de {tipo} hoje. alguém topa e conta como foi?
- apostei com o meu Familiar que ninguém aqui sela {n} Eco(s) de {tipo} antes de escurecer.

### `craft_seal` · casa · vesper
Conta o evento `craft`, meta de 1 a 2 (cresce com o nível). Recompensa: 150 XP e 1× `item.chalk`, 1× `item.ectoplasm`.

- se estiver chovendo: fabriquem {n} selo(s) simples e me digam se o giz risca diferente.
- dia de ficar em casa? então faça {n} selo(s) simples. ninguém precisa sair para isso.

### `craft_tonic` · casa · null_hypothesis
Conta o evento `craft`, meta de 1 a 1 (cresce com o nível). Recompensa: 150 XP e 1× `item.herbs`.

- alguém faz {n} tônico de foco e me diz se o tempo extra é placebo? eu acho que é só placebo.
- pedido de cético: {n} tônico de foco, e um relato honesto sobre os 5 segundos a mais.

### `distill` · casa · candlewick
Conta o evento `distill`, meta de 1 a 1 (cresce com o nível). Recompensa: 160 XP e 1× `item.dust.plant`.

- pergunta moral, sem resposta certa: destilar {n} Eco que não está no Círculo. como foi?
- destilem {n} Eco(s) e contem o que sentiram. eu sei o que penso, quero saber o que vocês pensam.
