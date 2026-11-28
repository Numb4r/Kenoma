/// A camada de uma espécie pelo id estável (`soot.eco`, `soot.spirit`, `soot.ritual`): o sufixo é parte do contrato dos ids
/// (CLAUDE.md, regra 9). Dart puro, para o mundo e a lógica decidirem sem carregar os dados de espécie.
library;

/// Eco, Espírito (`.spirit` e o Espírito de ritual, `.ritual`), Entidade Maior (`.major`) e Arquétipo (`.archetype`).
/// 0.27.0: a Entidade sai da fusão de 3 Espíritos ou aparece solta (`world/high_tiers.dart`); o Arquétipo só se vê.
enum SpeciesTier { eco, spirit, major, archetype }

SpeciesTier tierOfId(String id) => switch (id.split('.').last) {
      'eco' => SpeciesTier.eco,
      'major' => SpeciesTier.major,
      'archetype' => SpeciesTier.archetype,
      _ => SpeciesTier.spirit,
    };

/// Se a espécie tem sprite provisório no mapa comum: Eco e Espírito. A Entidade Maior solta e o Arquétipo do auge dos
/// eventos (0.27.0) aparecem só com a arte do Aseprite, então o mapa não monta sprite nem variante para eles.
bool appearsOnMap(String id) => switch (tierOfId(id)) {
      SpeciesTier.eco || SpeciesTier.spirit => true,
      SpeciesTier.major || SpeciesTier.archetype => false,
    };

/// Espécies que só respondem ao ritual, não à sintonia.
bool isRitualOnlyId(String id) => id.endsWith('.ritual');

/// 0.27.0: o que no mapa só se prende por ritual: a criatura de ritual e a Entidade Maior solta.
bool capturedByRitualOnly(String id) => isRitualOnlyId(id) || tierOfId(id) == SpeciesTier.major;

/// A família (`soot`) de um id.
String familyOfId(String id) => id.split('.').first;
