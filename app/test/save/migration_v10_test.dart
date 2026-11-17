import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/bag.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/crafting/quality.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// O save que os amigos têm quando a 0.24.0 chega é o schema 9, gravado pelo código real da 0.23.2
/// (`test/fixtures/save_v9_0232.json`).
void main() {
  final v9 = jsonDecode(File('test/fixtures/save_v9_0232.json').readAsStringSync()) as Map<String, dynamic>;

  test('v9 vira v10: todo material antigo fica comum e entra o bloco crafting vazio', () {
    final out = migrateSave(v9);
    expect(out['schema_version'], 10);
    expect(out['inventory'], v9['inventory'], reason: 'as chaves antigas já são as pilhas comuns');
    expect((out['crafting'] as Map)['vessels'], isEmpty);
    for (final k in v9.keys.where((k) => k != 'schema_version')) {
      expect(out[k], v9[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save v9 na 0.24.0: o inventário inteiro é comum e as receitas antigas continuam conhecidas', () async {
    final data = loadGameData();
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v9)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1795500000, nextInt: (n) => 0, appVersion: '0.24.0+44');
    final s = session.state;
    final inv = (v9['inventory'] as Map<String, dynamic>).cast<String, int>();
    for (final e in inv.entries) {
      expect((s.countQ(e.key, Quality.common), s.countQ(e.key, Quality.good), s.countQ(e.key, Quality.perfect)), (e.value, 0, 0), reason: e.key);
    }
    expect(s.crafting.equipped, isEmpty);
    expect(slotsUsed(s, data.craft), inv.length, reason: 'uma pilha de até 99 por espaço');
    // As receitas da Bancada antiga (selos, tônico, prisma) são de começo: valem sem estar na lista.
    expect(data.recipes['recipe.seal.simple']!.discovery.name, 'start');
    await session.flush();
    expect(store.json!['schema_version'], saveSchemaVersion);
    expect(CraftingState.fromJson(store.json!['crafting'] as Map<String, dynamic>).vessels, isEmpty);
  });
}
