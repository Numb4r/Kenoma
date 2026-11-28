import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/home.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// 0.28.0: a Casa entra no save (`home`, e a célula em `home_cell`, que nunca sai do aparelho). Um save v15 (o da 0.27.0)
/// abre sem casa, com o Armazém e as estações vazios, e o resto igual.
void main() {
  final v15 = {...migrateSave(jsonDecode(File('test/fixtures/save_v11_0241.json').readAsStringSync()) as Map<String, dynamic>), 'schema_version': 15}
    ..remove('home')
    ..remove(kHomeCellKey);

  Future<GameSession> open(Map<String, dynamic> json) => GameSession.open(
        store: MemorySaveStore()..json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        startInventory: {},
        balance: loadProgressBalance(),
        nowUtc: () => 1796000000,
        nextInt: (n) => 0,
        appVersion: '0.28.0+61',
      );

  test('v15 vira v16 sem casa, e o resto passa igual', () async {
    final out = migrateSave(v15);
    expect(out['schema_version'], saveSchemaVersion);
    expect(saveSchemaVersion, 16);
    for (final k in v15.keys.where((k) => k != 'schema_version')) {
      expect(out[k], v15[k], reason: 'o campo $k passa sem mudar');
    }
    final s = (await open(v15)).state;
    expect(s.home.cell, isNull);
    expect([s.home.storage.isEmpty, s.home.stations.isEmpty, s.home.stored.isEmpty, s.home.furniture.isEmpty], [true, true, true, true]);
    expect(s.collection.length, (v15['collection'] as List).length);
  });

  test('a casa vai e volta pelo save', () async {
    final s = (await open(v15)).state
      ..home.cell = (781234, 563210)
      ..home.setUtc = 1796000000
      ..home.storage['item.chalk'] = 3
      ..home.furniture['item.furniture.shelf'] = 1;
    final back = (await open(s.toJson(1796000000))).state;
    expect((back.home.cell, back.home.setUtc), ((781234, 563210), 1796000000));
    expect(back.home.storage, {'item.chalk': 3});
    expect(back.home.furniture, {'item.furniture.shelf': 1});
  });
}
