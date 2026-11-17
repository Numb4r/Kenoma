import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/crafting/grimoire.dart';
import 'package:kenoma/crafting/tutorial.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// O save que os amigos têm quando a 0.24.1 chega é o schema 10, gravado pelo código real da 0.24.0
/// (`test/fixtures/save_v10_0240.json`): garrafas feitas, uma no cinto e outra plantada.
void main() {
  final v10 = jsonDecode(File('test/fixtures/save_v10_0240.json').readAsStringSync()) as Map<String, dynamic>;

  test('v10 vira v11: as receitas antigas da Bancada continuam conhecidas e a quest entra desligada', () {
    final out = migrateSave(v10);
    expect(out['schema_version'], saveSchemaVersion);
    final c = out['crafting'] as Map<String, dynamic>;
    expect(c['known'], containsAll([...kRecipesKnownBefore0241, 'recipe.vessel.glass']));
    expect((c['tutorial'], c['tutorial_steps'], c['gift']), ('off', 0, false));
    expect(c['vessels'], (v10['crafting'] as Map)['vessels'], reason: 'os recipientes passam iguais');
    for (final k in v10.keys.where((k) => k != 'schema_version' && k != 'crafting')) {
      expect(out[k], v10[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save v10 na 0.24.1: nada some, as receitas antigas valem e o próximo Caco de vidro liga a quest já adiantada', () async {
    final data = loadGameData();
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v10)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1795600000, nextInt: (n) => 0, appVersion: '0.24.1+45');
    final s = session.state;
    expect(s.inventory, (v10['inventory'] as Map).cast<String, int>());
    expect(s.crafting.at(VesselPlace.belt), hasLength(1));
    expect(s.crafting.at(VesselPlace.planted), hasLength(1));
    for (final id in kRecipesKnownBefore0241) {
      expect(isKnown(s, data.recipes[id]!), isTrue, reason: id);
    }
    expect(s.crafting.tutorial, CraftTutorial.off);
    s.add('item.glass_shard', 1);
    expect(s.crafting.tutorial, CraftTutorial.on);
    // Já fez a garrafa e pôs no cinto na 0.24.0: a quest segue do passo de encher.
    expect(currentStep(s), TutStep.fill);
    await session.flush();
    expect(store.json!['schema_version'], saveSchemaVersion);
  });
}
