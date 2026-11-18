import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// 0.25.2 (modo de desenvolvimento, GDD rev 368): o save do celular na 0.25.1 é o schema 13, com a época em teste ligada e
/// a seção Desenvolvedor aberta nos Ajustes (`test/fixtures/save_v13_0251.json`). Os dois campos saem; o resto fica.
void main() {
  final v13 = jsonDecode(File('test/fixtures/save_v13_0251.json').readAsStringSync()) as Map<String, dynamic>;

  test('v13 vira v14: saem a época em teste e a seção Desenvolvedor, o resto passa igual', () {
    expect((v13['schema_version'], v13['settings']['dev_test_epoch'], v13['settings']['dev_options']), (13, 12, true));
    final out = migrateSave(v13);
    expect(out['schema_version'], saveSchemaVersion);
    final settings = out['settings'] as Map<String, dynamic>;
    expect(settings.containsKey('dev_test_epoch'), isFalse);
    expect(settings.containsKey('dev_options'), isFalse);
    for (final e in (v13['settings'] as Map<String, dynamic>).entries.where((e) => !e.key.startsWith('dev_'))) {
      expect(settings[e.key], e.value, reason: 'o Ajuste ${e.key} fica');
    }
    for (final k in v13.keys.where((k) => k != 'schema_version' && k != 'settings')) {
      expect(out[k], v13[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save v13 na 0.25.2: o jogo continua e o save gravado já sai sem os campos', () async {
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v13)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1795800000, nextInt: (n) => 0, appVersion: '0.25.2+52');
    expect(session.state.setting('street_names'), isTrue);
    expect(session.state.settings.containsKey('dev_test_epoch'), isFalse);
    await session.flush();
    expect(store.json!['schema_version'], saveSchemaVersion);
    expect((store.json!['settings'] as Map).containsKey('dev_test_epoch'), isFalse);
  });
}
