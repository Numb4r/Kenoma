import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart' show kVisitedCellsKey, saveSchemaVersion;
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// `test/fixtures/save_v3_0130.json` foi gravado pelo código da própria 0.13.0 (commit 9da1631), jogando de verdade:
/// criaturas capturadas, Círculo, marcação, XP, chat, diárias e interruptores. É o save que os amigos têm hoje.
void main() {
  final real = jsonDecode(File('test/fixtures/save_v3_0130.json').readAsStringSync()) as Map<String, dynamic>;

  test('o fixture é mesmo um save da 0.13.0: schema 3, sem névoa, Radar nem variantes', () {
    expect((real['schema_version'], real['app_version']), (3, '0.13.0+20'));
    expect(real.containsKey('fog'), isFalse);
    expect(real.containsKey('radar'), isFalse);
    expect((real['collection'] as List).length, 4);
  });

  test('v3 vira o schema atual: Radar vazio, a névoa da v4 sai na v6 sem células visitadas, e todo o resto passa intacto', () {
    final out = migrateSave(real);
    expect(out['schema_version'], saveSchemaVersion);
    expect(out.containsKey('fog'), isFalse);
    expect(out[kVisitedCellsKey], isEmpty);
    expect(out['radar'], {'last_utc': 0, 'revealed': <String, dynamic>{}});
    for (final k in real.keys.where((k) => k != 'schema_version')) {
      expect(out[k], real[k], reason: 'o campo $k passa sem mudar');
    }
  });

  test('um save v4 que já tem névoa leva as células para a v6, e migrar duas vezes dá o mesmo', () {
    final once = migrateSave(real);
    final v4 = {...real, 'schema_version': 4, 'fog': {'cells': {'1,2': 5}, 'debug': <String, dynamic>{}}};
    expect(migrateSave(v4)[kVisitedCellsKey], [[1, 2]]);
    expect(migrateSave(once), once);
  });

  test('abrir o save real da 0.13.0: o jogo continua o mesmo, a névoa começa coberta e grava no schema atual', () async {
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1792083600, nextInt: (n) => 0, appVersion: '0.14.0+21');
    await session.flush();
    final s = session.state;
    final before = real;
    expect(s.groupCode, before['group_code']);
    expect((s.progress.level, s.progress.xp), ((before['player'] as Map)['level'], (before['player'] as Map)['xp']));
    expect(s.collection.length, 4);
    expect(s.collection.every((c) => c.variant == null && !c.shiny), isTrue, reason: 'as de antes seguem comuns');
    expect(s.circle, before['circle']);
    expect(s.markOf(88), isNotNull, reason: 'a marcação sobrevive');
    expect(s.count('item.chalk'), (before['inventory'] as Map)['item.chalk']);
    expect(s.story.count('capture'), 4);
    expect(s.story.chat.delivered.length, 6);
    expect(s.setting('street_names'), isTrue);
    expect(s.founder!.playerId, (before['founder'] as Map)['player_id']);
    expect(s.founder!.chainValid, isTrue);
    expect(s.founder!.versionsSeen.map((e) => e.version), ['0.13.0+20', '0.14.0+21'], reason: 'a versão nova entra no log');
    expect(s.visitedCells, isEmpty);
    expect(s.radarLastUtc, 0);
    expect(store.json!['schema_version'], saveSchemaVersion);
    expect(store.json!.containsKey('fog'), isFalse);
  });

  test('ida e volta: as células visitadas gravadas abrem iguais', () async {
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    final a = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1792083600, nextInt: (n) => 0, appVersion: '0.14.0+21');
    a.state.markVisited(48401, 74107);
    await a.flush();
    final b = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1792083700, nextInt: (n) => 0, appVersion: '0.14.0+21');
    expect(b.state.visitedCells, {(48401, 74107)});
  });
}
