/// A camada de uma espécie pelo id estável (`soot.eco`, `soot.spirit`, `soot.ritual`): o sufixo é parte do contrato dos ids
/// (CLAUDE.md, regra 9). Dart puro, para o mundo e a lógica decidirem sem carregar os dados de espécie.
library;

enum SpeciesTier { eco, spirit }

SpeciesTier tierOfId(String id) => id.endsWith('.eco') ? SpeciesTier.eco : SpeciesTier.spirit;

/// Espécies que só respondem ao ritual, não à sintonia.
bool isRitualOnlyId(String id) => id.endsWith('.ritual');

/// A família (`soot`) de um id.
String familyOfId(String id) => id.split('.').first;
