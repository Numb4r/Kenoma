/// Migrações do save: cada `schema_version` tem uma função pura para a seguinte (docs/fase0-spec.md, seção 10).
/// Campos desconhecidos passam intactos.
library;

import '../player/game_state.dart' show saveSchemaVersion;

typedef _Step = Map<String, dynamic> Function(Map<String, dynamic>);

final Map<int, _Step> _steps = {1: _v1ToV2};

/// Leva [json] ao schema atual. Um save de versão futura passa sem mudar.
Map<String, dynamic> migrateSave(Map<String, dynamic> json) {
  var out = {...json};
  var version = (out['schema_version'] as int?) ?? 1;
  while (version < saveSchemaVersion) {
    out = _steps[version]!(out);
    version++;
    out['schema_version'] = version;
  }
  return out;
}

/// v1 tinha só `player_level` (o nível do debug, porque ainda não havia progressão). Na v2 o nível real vem
/// de `player` (começa no 1) e o do debug vira `level_override`; criaturas já capturadas entram no bestiário.
Map<String, dynamic> _v1ToV2(Map<String, dynamic> j) {
  final out = {...j};
  final old = out.remove('player_level') as int?;
  if (old != null && old > 1) out['level_override'] = old;
  out['player'] = <String, dynamic>{'level': 1, 'xp': 0, 'banked_xp': 0};
  out['circle'] = <String>[];
  out['marks'] = <Map<String, dynamic>>[];
  final bestiary = <String, dynamic>{};
  for (final c in (out['collection'] as List<dynamic>?) ?? const []) {
    bestiary[(c as Map<String, dynamic>)['species'] as String] = {'seen': true, 'captured': true};
  }
  out['bestiary'] = bestiary;
  return out;
}
