# Pendências de código da arte das criaturas

O que a arte das criaturas (branch `arte-criaturas`, `docs/art/estilo-criaturas.md`) precisa de código para entrar no jogo. A sessão de arte não edita Dart; a sessão de código implementa e marca **feito** aqui, com a versão.

## Família Hum

1. **Etapas altas sem espécie.** A Entidade Maior e o Arquétipo do Hum têm arte final em `tools/art/creatures/hum_entidade/` (quadro 48, retrato 96) e `tools/art/creatures/hum_arquetipo/` (quadro 64, retrato 128), mas `app/assets/data/creatures.json` não tem espécie para elas, então o `scripts/sync_creature_art.py` as deixa de fora. Falta: as espécies (ids e sufixo de camada, nome provisório), o `SpeciesTier` com as duas camadas (`core/species_ids.dart` só conhece `eco` e `spirit`) e o tamanho do quadro por camada no lugar de `mapEcoPx`/`mapSpiritPx`. Quando existirem, rodar o sync de novo traz as pastas. O Arquétipo só aparece em evento e Incursão, nunca no mapa comum.
2. **Retrato de 128.** O retrato do Arquétipo tem 128 px; o Bestiário hoje supõe 96.
3. **Teste da régua no `flutter test`.** `python3 tools/art/creatures/regua.py` mede a arte final contra os pisos e sai com erro abaixo do piso. Falta levá-lo para o `flutter test` (portar a medida para `test/ui/creature_art_test.dart` ou chamar o script), junto com os quadros de 48 e 64 e o retrato de 128, que o teste ainda não cobre.
