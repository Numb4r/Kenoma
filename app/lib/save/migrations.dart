/// Migrações do save: cada `schema_version` tem uma função pura para a seguinte (docs/fase0-spec.md, seção 10).
/// Campos desconhecidos passam intactos.
library;

import '../player/game_state.dart' show kVisitedCellsKey, saveSchemaVersion;

typedef _Step = Map<String, dynamic> Function(Map<String, dynamic>);

final Map<int, _Step> _steps = {1: _v1ToV2, 2: _v2ToV3, 3: _v3ToV4, 4: _v4ToV5, 5: _v5ToV6, 6: _v6ToV7, 7: _v7ToV8};

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

/// v2 não tinha o bloco `story` (eventos de jogo, chat com o mentor e diárias do fórum): entra vazio, e o tutorial do
/// mentor começa na próxima sessão. Todo o resto do save passa intacto.
Map<String, dynamic> _v2ToV3(Map<String, dynamic> j) {
  final out = {...j};
  out['story'] ??= <String, dynamic>{
    'events': <String, dynamic>{},
    'chat': <String, dynamic>{'delivered': <dynamic>[], 'read': 0, 'wait_s': 0},
    'daily': <String, dynamic>{'day': null, 'rerolls': 0, 'quests': <dynamic>[]},
  };
  return out;
}

/// v3 não tinha a névoa de guerra nem o Radar, e as criaturas não tinham variante: entram vazios (o mapa começa
/// encoberto e o Radar pronto). As criaturas capturadas antes seguem sem variante. Todo o resto passa intacto.
Map<String, dynamic> _v3ToV4(Map<String, dynamic> j) {
  final out = {...j};
  out['fog'] ??= <String, dynamic>{'cells': <String, dynamic>{}, 'debug': <String, dynamic>{}};
  out['radar'] ??= <String, dynamic>{'last_utc': 0, 'revealed': <String, dynamic>{}};
  return out;
}

/// v4 não tinha o bloco `conjurer`: a escola entra vazia (quem já passou do nível 3 recebe os testes na próxima abertura) e os
/// pontos de talento ganhos saem do nível atual, um por nível já subido. Todo o resto passa intacto.
Map<String, dynamic> _v4ToV5(Map<String, dynamic> j) {
  final out = {...j};
  final level = ((out['player'] as Map<String, dynamic>?)?['level'] as int?) ?? 1;
  out['conjurer'] ??= <String, dynamic>{
    'tests_offered': false,
    'test_scores': <String, dynamic>{},
    'talent_earned': level - 1,
    'talent_spent': 0,
    'ritual_research': <String, dynamic>{},
    'days_played': <dynamic>[],
    'fusions': 0,
  };
  return out;
}

/// v5 tinha a névoa de guerra (`fog`), que saiu do jogo. Antes de apagá-la, as células por onde o jogador passou viram
/// `celulas_visitadas`, uma lista de pares z17: cada chave `"x,y"` de `fog.cells` já é o tile z17 (um bloco de 8 × 8
/// células z20), e só os blocos com alguma célula marcada contam. O conjunto `fog.debug` (o caminho do simulador) não
/// entra. Todo o resto passa intacto.
Map<String, dynamic> _v5ToV6(Map<String, dynamic> j) {
  final out = {...j};
  final fog = out.remove('fog') as Map<String, dynamic>?;
  if (out[kVisitedCellsKey] != null) return out;
  final cells = <List<int>>[];
  for (final e in ((fog?['cells'] as Map<String, dynamic>?) ?? const {}).entries) {
    final parts = e.key.split(',');
    final x = parts.length == 2 ? int.tryParse(parts[0]) : null, y = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (x == null || y == null || (e.value as num).toInt() == 0) continue;
    cells.add([x, y]);
  }
  cells.sort((a, b) => a[0] != b[0] ? a[0] - b[0] : a[1] - b[1]);
  out[kVisitedCellsKey] = cells;
  return out;
}

/// v6 guardava no bestiário só `seen` e `captured`. A pesquisa (0.20.0) conta as capturas: cada espécie já capturada entra
/// com as que estão na coleção agora (pelo menos uma; as que viraram Essência ou Espírito não dá para recontar). A hora,
/// o clima e os biomas dos encontros antigos não foram guardados: essas tarefas começam do zero. As Fagulhas que estão na
/// Bolsa entram como coletadas. O resto passa intacto.
Map<String, dynamic> _v6ToV7(Map<String, dynamic> j) {
  final out = {...j};
  final owned = <String, int>{};
  for (final c in (out['collection'] as List<dynamic>?) ?? const []) {
    final m = c as Map<String, dynamic>;
    if (m['debug'] == true) continue;
    final id = m['species'] as String;
    for (final k in [id, if (m['variant'] != null) '$id@${m['variant']}', if (m['shiny'] == true) '$id@shiny']) {
      owned[k] = (owned[k] ?? 0) + 1;
    }
  }
  // As Fagulhas também entram no Bestiário: as que estão na Bolsa contam como coletadas.
  final dust = {
    for (final e in ((out['inventory'] as Map<String, dynamic>?) ?? const {}).entries)
      if (e.key.startsWith('item.dust.') && (e.value as int) > 0) e.key: <String, dynamic>{'seen': true, 'captured': true, 'captures': e.value},
  };
  out['bestiary'] = {
    ...dust,
    for (final e in ((out['bestiary'] as Map<String, dynamic>?) ?? const {}).entries)
      e.key: (e.value as Map<String, dynamic>)['captured'] == true && (e.value as Map<String, dynamic>)['captures'] == null
          ? {...e.value as Map<String, dynamic>, 'captures': (owned[e.key] ?? 0) < 1 ? 1 : owned[e.key]}
          : e.value,
  };
  return out;
}

/// v7 guardava uma forma marcada no Bestiário (`bestiary_pin`). A 0.20.1 marca até 3 (`bestiary_pins`). As builds da camada
/// pessoal e a origem dos spawns são campos novos, opcionais: ficam vazios. O resto passa intacto.
Map<String, dynamic> _v7ToV8(Map<String, dynamic> j) {
  final out = {...j};
  final pin = out.remove('bestiary_pin');
  if (pin is String) out['bestiary_pins'] = [pin];
  return out;
}
