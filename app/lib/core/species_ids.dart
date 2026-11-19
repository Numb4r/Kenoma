/// A camada de uma espécie pelo id estável (`soot.eco`, `soot.spirit`, `soot.ritual`): o sufixo é parte do contrato dos ids
/// (CLAUDE.md, regra 9). Dart puro, para o mundo e a lógica decidirem sem carregar os dados de espécie.
library;

/// Eco, Espírito (`.spirit` e o Espírito de ritual, `.ritual`), Entidade Maior (`.major`) e Arquétipo (`.archetype`).
/// As duas últimas têm arte e espécie desde já, mas nenhum caminho do jogo (spawn, fusão, Bestiário) as chama ainda.
enum SpeciesTier { eco, spirit, major, archetype }

SpeciesTier tierOfId(String id) => switch (id.split('.').last) {
      'eco' => SpeciesTier.eco,
      'major' => SpeciesTier.major,
      'archetype' => SpeciesTier.archetype,
      _ => SpeciesTier.spirit,
    };

/// Se a espécie aparece no mapa comum: Eco e Espírito. A Entidade Maior e o Arquétipo ainda não (e o Arquétipo nunca: só
/// evento e Incursão), então o mapa não monta sprite nem variante para eles.
bool appearsOnMap(String id) => switch (tierOfId(id)) {
      SpeciesTier.eco || SpeciesTier.spirit => true,
      SpeciesTier.major || SpeciesTier.archetype => false,
    };

/// Espécies que só respondem ao ritual, não à sintonia.
bool isRitualOnlyId(String id) => id.endsWith('.ritual');

/// A família (`soot`) de um id.
String familyOfId(String id) => id.split('.').first;
