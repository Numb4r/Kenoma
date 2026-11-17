import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/tutorial.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/map_touch.dart';

import '../support/fixtures.dart';

/// O save que os amigos têm quando a 0.24.2 chega é o schema 11, gravado pelo código real da 0.24.1
/// (`test/fixtures/save_v11_0241.json`): a quest da primeira garrafa no último passo, com água de chuva no cinto.
void main() {
  final v11 = jsonDecode(File('test/fixtures/save_v11_0241.json').readAsStringSync()) as Map<String, dynamic>;

  test('v11 vira v12: entra o bloco touches vazio e o resto passa igual', () {
    final out = migrateSave(v11);
    expect(out['schema_version'], saveSchemaVersion);
    expect(out['touches'], {'day': 0, 'counts': <String, dynamic>{}, 'used': <dynamic>[]});
    for (final k in v11.keys.where((k) => k != 'schema_version')) {
      expect(out[k], v11[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save v11 na 0.24.2: a quest segue no último passo, a garrafa e a receita continuam', () async {
    final data = loadGameData();
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v11)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1795800000, nextInt: (n) => 0, appVersion: '0.24.2+46');
    final s = session.state;
    expect(currentStep(s), TutStep.use);
    expect(s.crafting.known, contains('recipe.vessel.glass'));
    expect(data.recipes['recipe.vessel.glass']!.inputs, {'item.glass_shard': 2}, reason: 'a receita nova; quem já tem garrafa não perde nada');
    expect(s.touches.count(TouchKind.flock, 20000), 0);
    await session.flush();
    expect(store.json!['schema_version'], saveSchemaVersion);
    expect(store.json!['touches'], isA<Map<String, dynamic>>());
  });
}
