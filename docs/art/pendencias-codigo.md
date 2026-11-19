# Pendências de código da arte das criaturas

O que a arte das criaturas (branch `arte-criaturas`, `docs/art/estilo-criaturas.md`) precisa de código para entrar no jogo. A sessão de arte não edita Dart; a sessão de código implementa e marca **feito** aqui, com a versão.

## Família Hum

1. **Etapas altas sem espécie.** **Feito (0.26.0), na forma mínima:** `SpeciesTier` ganhou `major` e `archetype` (sufixos `.major` e `.archetype`), `mapPxOf` dá 48 e 64, e `hum.major`, `hum.archetype`, `soot.major` e `soot.archetype` estão no `creatures.json`; o sync mapeia `<familia>_entidade` e `<familia>_arquetipo` para elas, e o `creature_art_test` confere os quadros de 48 e 64 e o retrato de 128. Nenhum caminho do jogo as chama ainda (spawn só sorteia `.eco` e `.spirit`, a fusão só sobe Eco, o Bestiário lista Eco, Espírito e Ritual). **Falta, quando a fase chegar:** os nomes (hoje provisórios, "Entidade Maior de Humoth"), Poder, teto de nível e de traços no `balance.json` (o GDD só fixa os traços, 3 e 4), a fusão de 3 Espíritos, o Bestiário e de onde cada uma nasce. Cada família nova acrescenta as duas espécies dela.
2. **Retrato de 128.** **Feito (0.26.0, sem código):** o `CreaturePortrait` já lê o lado do quadro pela altura da tira, então o retrato de 128 do Arquétipo entra como está.
3. **Teste da régua no `flutter test`.** **Feito (0.26.0):** `test/ui/creature_ruler_test.dart` roda `tools/art/creatures/regua.py` (a medida e os pisos num lugar só) e falha com o que ficou abaixo do piso. Os quadros de 48 e 64 entram no `creature_art_test.dart` junto com o item 1, quando as espécies existirem.

## Família Soot

5. **Etapas altas do Soot:** **feito**, junto com o item 1.
6. **Gatilho de nascer do Soot:** não existe no `index.json` (`SPAWN` do `scripts/sync_creature_art.py`). Sugestão do criativo: sair do bueiro. Decisão do dono.
7. **Essência fixa no Fogo:** **conferido, nada a fazer:** nenhum código do tipo Fogo usa `#FF7A45` fixo; a cor do tipo vem de `typeColor`.

## Família Frond

8. **Etapas altas do Frond:** **feito**, como no item 1 (`frond.major`, `frond.archetype`).
9. **Gatilho de nascer do Frond:** não existe no `index.json`. Sugestão do criativo: `ground` (o do Clod) ou um novo, "rachadura da calçada". Decisão do dono.

## Família Shade

4. **Sombra no chão desligada no Shade.** **Feito (0.26.0):** `castsGroundShadow` em `ui/game/spawn_painter.dart` (testado em `test/ui/ground_shadow_test.dart`) tira a sombra oval das espécies do Shade, no Eco gerado e no animado.
10. **Textos do Bestiário do Shade:** `docs/textos-bestiario.md` pode ainda descrever o Umbrel e o Shadekin antigos (vultos); agora são o morcego pendurado e o morcego de pé com o braço de laje. Fica para o criativo.
