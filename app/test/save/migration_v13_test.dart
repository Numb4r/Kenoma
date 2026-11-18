import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/map_touch.dart';

import '../support/fixtures.dart';

/// O save que o celular tem quando a 0.24.5 chega é o schema 12, gravado pelo código real da 0.24.4
/// (`test/fixtures/save_v12_0244.json`): bolsa equipada, um toque de árvore no dia e uma preferência.
void main() {
  final v12 = jsonDecode(File('test/fixtures/save_v12_0244.json').readAsStringSync()) as Map<String, dynamic>;

  test('v12 vira v13: entra o bloco npcs vazio e o resto passa igual', () {
    expect(v12['schema_version'], 12);
    final out = migrateSave(v12);
    expect(out['schema_version'], saveSchemaVersion);
    expect(out['npcs'], {'day': 0, 'traded': <dynamic>[], 'rel': <String, dynamic>{}});
    for (final k in v12.keys.where((k) => k != 'schema_version')) {
      expect(out[k], v12[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save v12 na 0.24.5: bolsa, toques e Ajustes continuam; os espaços de veículo nascem vazios', () async {
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v12)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1795800000, nextInt: (n) => 0, appVersion: '0.24.5+49');
    final s = session.state;
    expect(s.crafting.equipped[LoadoutSlot.bag], 'item.bag.satchel');
    expect(s.crafting.equipped[LoadoutSlot.vehicleBike], isNull);
    expect(s.touches.count(TouchKind.tree, 20774), 1);
    expect(s.setting('street_names'), isTrue);
    expect(s.npcs.traded, isEmpty);
    await session.flush();
    expect(store.json!['schema_version'], saveSchemaVersion);
    expect(store.json!['npcs'], isA<Map<String, dynamic>>());
  });
}
