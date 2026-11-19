# Pendências de código da arte das criaturas

O que a arte das criaturas (branch `arte-criaturas`, `docs/art/estilo-criaturas.md`) precisa de código para entrar no jogo. A sessão de arte não edita Dart; a sessão de código implementa e marca **feito** aqui, com a versão.

## Família Hum

1. **Etapas altas sem espécie.** A Entidade Maior e o Arquétipo do Hum têm arte final em `tools/art/creatures/hum_entidade/` (quadro 48, retrato 96) e `tools/art/creatures/hum_arquetipo/` (quadro 64, retrato 128), mas `app/assets/data/creatures.json` não tem espécie para elas, então o `scripts/sync_creature_art.py` as deixa de fora. Falta: as espécies (ids e sufixo de camada, nome provisório), o `SpeciesTier` com as duas camadas (`core/species_ids.dart` só conhece `eco` e `spirit`) e o tamanho do quadro por camada no lugar de `mapEcoPx`/`mapSpiritPx`. Quando existirem, rodar o sync de novo traz as pastas. O Arquétipo só aparece em evento e Incursão, nunca no mapa comum.
2. **Retrato de 128.** **Feito (0.26.0, sem código):** o `CreaturePortrait` já lê o lado do quadro pela altura da tira, então o retrato de 128 do Arquétipo entra como está.
3. **Teste da régua no `flutter test`.** **Feito (0.26.0):** `test/ui/creature_ruler_test.dart` roda `tools/art/creatures/regua.py` (a medida e os pisos num lugar só) e falha com o que ficou abaixo do piso. Os quadros de 48 e 64 entram no `creature_art_test.dart` junto com o item 1, quando as espécies existirem.

## Família Shade

4. **Sombra no chão desligada no Shade.** O traço do Shade é a sombra que não acompanha o corpo, desenhada no sprite; a sombra no chão que o código põe embaixo de toda criatura não pode aparecer nas espécies do Shade. Entra com a arte final da família.
