import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart' show kVisitedCellsKey;
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// `test/fixtures/save_v5_0150.json` foi gravado pelo código da própria 0.15.0 (commit 6f352cc, build 0.15.0+23): o
/// save real da 0.14.0 aberto num `KsvSaveStore`, com escola, uma captura nova, um passeio real e um pedaço do
/// simulador na névoa, lido de volta do KSV1 gravado (ver `test/fixtures/README.md`).
void main() {
  final real = jsonDecode(File('test/fixtures/save_v5_0150.json').readAsStringSync()) as Map<String, dynamic>;
  final fog = real['fog'] as Map<String, dynamic>;
  final cells = fog['cells'] as Map<String, dynamic>;
  final debug = fog['debug'] as Map<String, dynamic>;
  Set<String> visitedOf(Map<String, dynamic> save) => {for (final c in save[kVisitedCellsKey] as List) (c as List).join(',')};

  test('o fixture é mesmo um save da 0.15.0: schema 5, névoa real e de debug', () {
    expect((real['schema_version'], real['app_version']), (5, '0.15.0+23'));
    expect(cells, isNotEmpty);
    expect(debug, isNotEmpty);
    expect((real['conjurer'] as Map)['school'], 'shaman');
  });

  test('v5 vira v6: a névoa sai, os blocos z17 reais viram celulas_visitadas, o debug não entra e o resto passa intacto', () {
    final out = migrateSave(real);
    expect(out['schema_version'], 6);
    expect(out.containsKey('fog'), isFalse);
    final visited = visitedOf(out);
    expect(visited, cells.keys.toSet());
    final debugOnly = debug.keys.where((k) => !cells.containsKey(k)).toList();
    expect(debugOnly, isNotEmpty, reason: 'o fixture tem blocos só do simulador');
    for (final k in debugOnly) {
      expect(visited.contains(k), isFalse, reason: 'o caminho do simulador ($k) não é célula visitada');
    }
    for (final k in real.keys.where((k) => k != 'schema_version' && k != 'fog')) {
      expect(out[k], real[k], reason: 'o campo $k passa sem mudar');
    }
  });

  test('blocos com máscara zero não contam, e migrar duas vezes dá o mesmo', () {
    final withZero = {...real, 'fog': {'cells': {...cells, '1,2': 0}, 'debug': debug}};
    final out = migrateSave(withZero);
    expect(visitedOf(out).contains('1,2'), isFalse);
    expect(migrateSave(out), out);
  });

  test('abrir o save da 0.15.0: o jogo é o mesmo, as células visitadas vêm da névoa e grava no schema 6', () async {
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1793000000, nextInt: (n) => 0, appVersion: '0.16.0+25');
    await session.flush();
    final s = session.state;
    expect(s.groupCode, real['group_code']);
    expect((s.progress.level, s.progress.xp), ((real['player'] as Map)['level'], (real['player'] as Map)['xp']));
    expect(s.collection.length, (real['collection'] as List).length);
    expect(s.conjurer.school?.id, 'shaman');
    expect(s.visitedCells.length, cells.length);
    expect(s.founder!.chainValid, isTrue);
    expect(s.founder!.versionsSeen.map((e) => e.version).last, '0.16.0+25');
    expect(store.json!['schema_version'], 6);
    expect(store.json!.containsKey('fog'), isFalse);
    expect(visitedOf(store.json!), cells.keys.toSet());
    expect(s.markVisited(1, 2), isTrue);
    expect(s.markVisited(1, 2), isFalse, reason: 'a mesma célula não entra duas vezes');
  });
}
