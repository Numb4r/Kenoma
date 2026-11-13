import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/crafting.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// `test/fixtures/save_v7_0200.json` foi gravado pelo código da própria 0.20.0 (commit a70e6f7, build 0.20.0+32; ver
/// `test/fixtures/README.md`): é o save que os amigos têm no celular quando a 0.20.1 chega, com uma forma marcada.
void main() {
  final real = jsonDecode(File('test/fixtures/save_v7_0200.json').readAsStringSync()) as Map<String, dynamic>;

  test('o fixture é mesmo um save da 0.20.0: schema 7, uma marca só', () {
    expect((real['schema_version'], real['app_version'], real['bestiary_pin']), (7, '0.20.0+32', 'shade.eco'));
    expect(real.containsKey('bestiary_pins'), isFalse);
  });

  test('v7 vira v8: a marca única vira a lista, e o resto passa intacto', () {
    final out = migrateSave(real);
    expect(out['schema_version'], 8);
    expect(out['bestiary_pins'], ['shade.eco']);
    expect(out.containsKey('bestiary_pin'), isFalse);
    for (final k in real.keys.where((k) => k != 'schema_version' && k != 'bestiary_pin')) {
      expect(out[k], real[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
    final none = migrateSave({...real}..remove('bestiary_pin'));
    expect(none.containsKey('bestiary_pins'), isFalse, reason: 'sem marca, sem lista');
  });

  test('abrir o save da 0.20.0 na 0.20.1: o jogo é o mesmo, a marca continua, e grava no schema 8 com a origem dos spawns', () async {
    final data = loadGameData();
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1794700000, nextInt: (n) => 0, appVersion: '0.20.1+33');
    await session.flush();
    final s = session.state;
    expect(s.groupCode, real['group_code']);
    expect(s.collection.length, (real['collection'] as List).length);
    expect(s.inventory, real['inventory']);
    expect(s.circle, real['circle']);
    expect(s.founder!.playerId, (real['founder'] as Map)['player_id'], reason: 'o player_id não muda: a camada pessoal sai dele');
    expect(s.pins, ['shade.eco']);
    expect(s.builds, isEmpty);
    expect(s.collection.every((c) => !c.personal && !c.hidden), isTrue, reason: 'os antigos vieram da base');
    expect(store.json!['schema_version'], saveSchemaVersion);
    expect(s.togglePin('hum.eco'), isTrue);
    // Um Eco Oculto da camada pessoal capturado guarda a origem; com um Bit no Círculo, a destilação rende a mais.
    final c = s.capture(uid: 9200, speciesId: 'soot.eco', level: 3, nowUtc: 1794700100, personal: true, hidden: true);
    final back = GameState.fromJson(s.toJson(1794700200), data.progress);
    expect((back.creature(c.uid)!.personal, back.creature(c.uid)!.hidden), (true, true));
    expect(back.pins, ['shade.eco', 'hum.eco']);
    final plain = distillQty(s, 3, data, hidden: true);
    s.capture(uid: 9300, speciesId: 'bit.eco', level: 1, nowUtc: 1794700300);
    s.circle
      ..clear()
      ..add(GameState.uidKey(9300));
    expect(distillQty(s, 3, data, hidden: true), plain + data.personal.hiddenEssenceBonus);
    expect(distillQty(s, 3, data), plain, reason: 'só os que eram Ocultos');
  });
}
