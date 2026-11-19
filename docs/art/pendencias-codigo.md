# Pendências de código da arte das criaturas

O que a arte das criaturas (branch `arte-criaturas`, `docs/art/estilo-criaturas.md`) precisa de código para entrar no jogo. A sessão de arte não edita Dart; a sessão de código implementa e marca **feito** aqui, com a versão.

## Família Hum

1. **Etapas altas sem espécie.** **Feito (0.26.0), na forma mínima:** `SpeciesTier` ganhou `major` e `archetype` (sufixos `.major` e `.archetype`), `mapPxOf` dá 48 e 64, e `hum.major`, `hum.archetype`, `soot.major` e `soot.archetype` estão no `creatures.json`; o sync mapeia `<familia>_entidade` e `<familia>_arquetipo` para elas, e o `creature_art_test` confere os quadros de 48 e 64 e o retrato de 128. Nenhum caminho do jogo as chama ainda (spawn só sorteia `.eco` e `.spirit`, a fusão só sobe Eco, o Bestiário lista Eco, Espírito e Ritual). **Falta, quando a fase chegar:** os nomes (hoje provisórios, "Entidade Maior de Humoth"), Poder, teto de nível e de traços no `balance.json` (o GDD só fixa os traços, 3 e 4), a fusão de 3 Espíritos, o Bestiário e de onde cada uma nasce. Cada família nova acrescenta as duas espécies dela.
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
10. **Textos do Bestiário do Shade:** **feito:** o criativo reescreveu em `docs/textos-bestiario.md` (o morcego pendurado e o morcego de pé com o braço de laje) e o texto foi copiado para o `creatures.json` (`shade.eco`, `shade.spirit` e o `spark.about` da família). Ainda descrevem a forma antiga: Sootling, Wisplet e Wyrmlet.

## Famílias Wisp e Wyrm

11. **Etapas altas do Wisp e do Wyrm:** **feito**, como no item 1 (`wisp.major`, `wisp.archetype`, `wyrm.major`, `wyrm.archetype`). O Arquétipo do Wisp tem `idle` e `drift` de 8 quadros e `body_dy` positivo (desce 1 px): o leitor já usa `frames` e `fps` do json.
12. **Gatilho de nascer do Wyrm:** **feito:** decisão do dono, `crater_crack`: a cratera na chuva de meteoros (`climates.crater` do `index.json`, `meteor_shower`), senão o asfalto rachado com brasa.
13. **`leds` vazio:** o `wyrm_arquetipo_*_leds.png` sai sem pixel de propósito (o Arquétipo do Wyrm não tem olho).
14. **Mapa sem as camadas altas:** **feito (0.26.0):** `appearsOnMap` (`core/species_ids.dart`, com teste) faz o mapa montar sprite e variante só de Eco e Espírito; antes ele gerava os provisórios das 14 espécies de 48 e 64 px a cada abertura do mapa.

