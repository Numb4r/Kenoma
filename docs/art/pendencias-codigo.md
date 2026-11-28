# Pendências de código da arte das criaturas

O que a arte das criaturas (branch `arte-criaturas`, `docs/art/estilo-criaturas.md`) precisa de código para entrar no jogo. A sessão de arte não edita Dart; a sessão de código implementa e marca **feito** aqui, com a versão.

## Família Hum

1. **Etapas altas sem espécie.** **Feito (0.26.0), na forma mínima:** `SpeciesTier` ganhou `major` e `archetype` (sufixos `.major` e `.archetype`), `mapPxOf` dá 48 e 64, e `hum.major`, `hum.archetype`, `soot.major` e `soot.archetype` estão no `creatures.json`; o sync mapeia `<familia>_entidade` e `<familia>_arquetipo` para elas, e o `creature_art_test` confere os quadros de 48 e 64 e o retrato de 128. Nenhum caminho do jogo as chama ainda (spawn só sorteia `.eco` e `.spirit`, a fusão só sobe Eco, o Bestiário lista Eco, Espírito e Ritual). **Falta, quando a fase chegar:** os nomes (hoje provisórios, "Entidade Maior de Humoth"), Poder, teto de nível e de traços no `balance.json` (o GDD só fixa os traços, 3 e 4), a fusão de 3 Espíritos, o Bestiário e de onde cada uma nasce. Cada família nova acrescenta as duas espécies dela. **Feito (0.27.0), pelo GDD rev 399 ("Etapas altas antes dos grimórios e das Incursões"):** os 24 nomes de `docs/art/nomes-propostos.md` no `creatures.json` (aprovados; Hingeback, Rubblebrood, Awninghang e Waxhalo trocaram os que repetiam a raiz da criatura de ritual); teto de nível, Poder e traços no `balance.json` (Entidade 40, Poder 100 + 4/nível, 3 traços; Arquétipo 50, 220 + 5/nível, 4 traços); a fusão de 3 Espíritos com a criatura de ritual como oferenda (`crafting/major_fusion.dart`, aba Fusão da Bancada); a Entidade solta, rara e determinística, na condição do ritual da família, com rumor no Fórum e receita de ritual própria (`world/high_tiers.dart`, `high_tiers` na época de desenvolvimento do `epochs.json`, `rituals.json`); o Arquétipo no auge do evento da família, que só se vê e marca visto no Bestiário; verbetes com Lore I, dicas do mentor e o debug.
2. **Retrato de 128.** **Feito (0.26.0, sem código):** o `CreaturePortrait` já lê o lado do quadro pela altura da tira, então o retrato de 128 do Arquétipo entra como está.
3. **Teste da régua no `flutter test`.** **Feito (0.26.0):** `test/ui/creature_ruler_test.dart` roda `tools/art/creatures/regua.py` (a medida e os pisos num lugar só) e falha com o que ficou abaixo do piso. Os quadros de 48 e 64 entram no `creature_art_test.dart` junto com o item 1, quando as espécies existirem.

## Família Soot

5. **Etapas altas do Soot:** **feito**, junto com o item 1.
6. **Gatilho de nascer do Soot:** **feito:** decisão do dono, o bueiro (`manhole` no `SPAWN` do `scripts/sync_creature_art.py`; desenho em `ui/game/spawn_trigger.dart`, teste em `test/ui/spawn_trigger_test.dart`).
7. **Essência fixa no Fogo:** **conferido, nada a fazer:** nenhum código do tipo Fogo usa `#FF7A45` fixo; a cor do tipo vem de `typeColor`.

## Família Frond

8. **Etapas altas do Frond:** **feito**, como no item 1 (`frond.major`, `frond.archetype`).
9. **Gatilho de nascer do Frond:** **feito:** decisão do dono, a rachadura da calçada (`crack`), como no item 6.

## Família Shade

4. **Sombra no chão desligada no Shade.** **Feito (0.26.0):** `castsGroundShadow` em `ui/game/spawn_painter.dart` (testado em `test/ui/ground_shadow_test.dart`) tira a sombra oval das espécies do Shade, no Eco gerado e no animado.
10. **Textos do Bestiário do Shade:** **feito:** o criativo reescreveu em `docs/textos-bestiario.md` (o morcego pendurado e o morcego de pé com o braço de laje) e o texto foi copiado para o `creatures.json` (`shade.eco`, `shade.spirit` e o `spark.about` da família). Sootling, Wisplet e Wyrmlet: **feito** em `bca70ca`, textos pela forma nova (saruê, coruja-buraqueira, teú) em `docs/textos-bestiario.md` e no `creatures.json`.

## Famílias Wisp e Wyrm

11. **Etapas altas do Wisp e do Wyrm:** **feito**, como no item 1 (`wisp.major`, `wisp.archetype`, `wyrm.major`, `wyrm.archetype`). O Arquétipo do Wisp tem `idle` e `drift` de 8 quadros e `body_dy` positivo (desce 1 px): o leitor já usa `frames` e `fps` do json.
12. **Gatilho de nascer do Wyrm:** **feito:** decisão do dono, `crater_crack`: a cratera na chuva de meteoros (`climates.crater` do `index.json`, `meteor_shower`), senão o asfalto rachado com brasa.
13. **`leds` vazio:** o `wyrm_arquetipo_*_leds.png` sai sem pixel de propósito (o Arquétipo do Wyrm não tem olho).
14. **Mapa sem as camadas altas:** **feito (0.26.0):** `appearsOnMap` (`core/species_ids.dart`, com teste) faz o mapa montar sprite e variante só de Eco e Espírito; antes ele gerava os provisórios das 14 espécies de 48 e 64 px a cada abertura do mapa.

## Famílias Glare, Bit, Clod, Rill, Rust e Sprig

15. **Etapas altas das seis:** **feito**, como no item 1 (`<familia>.major` e `<familia>.archetype` no `creatures.json`, com o tipo, o deus e a época do Espírito). Os nomes continuam provisórios ("Entidade Maior de Glimlet").
16. **Fagulhas refeitas:** `spark_light`, `spark_digital`, `spark_earth`, `spark_water`, `spark_metal` e `spark_fae` copiadas para `app/assets/art/sparks/`; o `sparks.json` não mudou.
17. **`spawn` de 7 quadros nos Arquétipos** e `idle`/`drift` de 8 no Sprigglet e no Fairkin: **conferido, nada a fazer:** o leitor usa `frames` e `fps` do json, e o `creature_art_test` passa.
18. **Gatilho de nascer de Glare, Bit, Rust e Sprig:** **feito**, decisão do dono pela coluna "Onde e quando" do GDD: `glint_rainbow`, `static_sign`, `grate` e `whirl` (`ui/game/spawn_trigger.dart`, teste em `test/ui/spawn_trigger_test.dart`; o `SPAWN` do `scripts/sync_creature_art.py`). Só desenho: o lugar, a hora e o clima em que cada família nasce já eram mundo (`eco_v2.conditions` e o `spawn` dos climas, testados em `test/core/spawn_conditions_test.dart`). Clod (`ground`) e Rill (`puddle`) já valem para as etapas altas.

## Criaturas de ritual da fase 1 (Stormlamp, Noonglass, Eaveshroud, Staticroost, Vigilwick, Cairnhollow, Duskwreath, Cratercoil e Gatewarden)

19. **Condições do "Onde e quando" do GDD:** **feito** (`0530362`): `ConditionKind` ganhou `climate` (clima e evento da célula, pela pilha `climate+events`), `twilight` (crepúsculo real, `twilightDeg = 6`) e as combinações `all` e `any` (`crafting/ritual_data.dart`, teste em `test/crafting/ritual_test.dart`); o texto da condição sai de `ui/ritual/ritual_text.dart`.
20. **Placeholder do Espírito de ritual sem matriz:** **feito** (`f3c19d3`): `_ritualStandIn` em `ui/sprites/sprite_image.dart` dá as linhas e a paleta do Espírito da família; `test/ui/sprite_test.dart` confere toda espécie.
21. **Espécie, receita, Eco de ritual e Bestiário:** **feito**, uma por commit: `<familia>.ritual` em `creatures.json` (`ritual_only`, com o deus e o `since_epoch` do Espírito), a receita em `rituals.json` e o Eco de ritual no `epochs.json` da época de desenvolvimento (peso 6 no bioma de casa, 1 nos outros). Os testes do Bestiário contam as formas pelos dados.
22. **Dicas do mentor e verbetes das três do MVP:** **feito** (`479cab8`): `ritual_hint_<familia>` para as nove (o evento `ritual_seen_<familia>` já saía para toda família) e o verbete com as cinco pesquisas de Kilnshade, Rootseer e Wellmirror. O "Ver" da pesquisa só aceita dia, noite, crepúsculo ou clima: Kilnshade e Wellmirror ficaram em "Ver de noite", Rootseer em "Ver de dia".
23. **Receita no detalhe da espécie com verbete:** **feito** (`479cab8`): o detalhe do Espírito de ritual mostra as pesquisas do verbete e, abaixo, a receita que a pesquisa do ritual revelou (`ui/menu/bestiary/species_detail.dart`; `test/ui/ritual_screen_test.dart`).
