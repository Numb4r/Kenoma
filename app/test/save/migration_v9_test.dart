import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// O save que os amigos têm quando a 0.21.0 chega é o schema 8 (0.20.1 a 0.20.4). Ele sai do fixture real da 0.20.0
/// (`test/fixtures/save_v7_0200.json`) levado ao 8 pelas migrações de antes, com marcas de clima no Bestiário como o
/// código da 0.20.4 grava (`climate:<id>`), inclusive as dos dois climas que viraram evento na época 12.
void main() {
  final v7 = jsonDecode(File('test/fixtures/save_v7_0200.json').readAsStringSync()) as Map<String, dynamic>;
  Map<String, dynamic> v8() {
    var out = {...v7};
    out = {...out, 'bestiary_pins': [v7['bestiary_pin']]}..remove('bestiary_pin');
    final b = {...out['bestiary'] as Map<String, dynamic>};
    b['wyrm.eco'] = {'seen': true, 'when': ['climate:crimson_rain', 'night']};
    b['shade.eco'] = {...b['shade.eco'] as Map<String, dynamic>? ?? {'seen': true}, 'when': ['climate:prismatic_drizzle', 'climate:fog', 'day']};
    b['hum.eco'] = {'seen': true, 'when': ['climate:storm', 'night']};
    return {...out, 'bestiary': b, 'schema_version': 8};
  }

  test('v8 vira v9: a Chuva Carmim e a Garoa Prismática do Bestiário viram o evento e o clima embaixo', () {
    final old = v8();
    final out = migrateSave(old);
    expect(out['schema_version'], 9);
    final b = out['bestiary'] as Map<String, dynamic>;
    expect((b['wyrm.eco'] as Map)['when'], ['climate:crimson_moon', 'climate:rain', 'night']);
    expect((b['shade.eco'] as Map)['when'], ['climate:drizzle', 'climate:fog', 'climate:veil_prism', 'day']);
    expect(b['hum.eco'], (old['bestiary'] as Map)['hum.eco'], reason: 'quem não tem marca antiga passa igual');
    for (final k in old.keys.where((k) => k != 'schema_version' && k != 'bestiary')) {
      expect(out[k], old[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save v8 na 0.21.0: a pesquisa do Wyrmlet que viu a Chuva Carmim conta pela Lua Carmim', () async {
    final data = loadGameData();
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v8())) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1795000000, nextInt: (n) => 0, appVersion: '0.21.0+37');
    await session.flush();
    expect(store.json!['schema_version'], saveSchemaVersion);
    final when = session.state.bestiary['wyrm.eco']!.when;
    expect(when.contains('climate:crimson_moon'), isTrue);
    expect(File('assets/data/creatures.json').readAsStringSync(), contains('climate:black_sun|crimson_moon|meteor_shower'), reason: 'a pesquisa pede a Lua Carmim');
    expect(data.schedule.epochs.length, greaterThan(12));
  });
}
