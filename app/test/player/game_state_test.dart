import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

void main() {
  GameState fresh() => GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {'item.seal.simple': 5, 'item.chalk': 3}, balance: loadProgressBalance());

  test('o inventário soma e gasta, e não gasta o que não tem', () {
    final s = fresh();
    s.add('item.herbs', 2);
    expect(s.count('item.herbs'), 2);
    expect(s.take('item.herbs'), isTrue);
    expect(s.take('item.herbs'), isTrue);
    expect(s.take('item.herbs'), isFalse);
    expect(s.inventory.containsKey('item.herbs'), isFalse);
    expect(s.count('item.seal.simple'), 5);
  });

  test('o registro lembra o uid, inclusive com sinal, e esquece depois de 48 h', () {
    final s = fresh();
    const uid = -0x4eacbd2a2508a3d3; // uid de 64 bits que aparece negativo no Dart
    expect(s.isDone(uid), isFalse);
    s.markDone(uid, 1000);
    expect(s.isDone(uid), isTrue);
    s.markDone(7, 1000 + registryKeepSeconds); // exatamente 48 h: ainda vale
    expect(s.isDone(uid), isTrue);
    s.markDone(8, 1001 + registryKeepSeconds);
    expect(s.isDone(uid), isFalse, reason: 'passou de 48 h');
    expect(s.isDone(7), isTrue);
  });

  test('capturar põe na coleção e no registro', () {
    final s = fresh();
    final c = s.capture(uid: 42, speciesId: 'soot.eco', level: 3, nowUtc: 500);
    expect(s.collection.single.uid, c.uid);
    expect(s.isDone(42), isTrue);
  });

  test('o save vai e volta sem perder nada, e guarda campos que não conhece', () async {
    final store = MemorySaveStore();
    final session = await GameSession.open(store: store, startInventory: {'item.chalk': 3}, balance: loadProgressBalance(), nowUtc: () => 99, nextInt: (n) => 1);
    final s = session.state;
    expect(s.groupCode, matches(RegExp(r'^[0-9A-Z]{5}-[0-9A-Z]{5}$')));
    s.add('item.herbs', 4);
    s.capture(uid: -5, speciesId: 'rill.eco', level: 2, nowUtc: 100);
    await session.flush();
    store.json!['future_field'] = {'x': 1};

    final again = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 200, nextInt: (n) => 0);
    expect(again.state.groupCode, s.groupCode, reason: 'a seed não muda ao reabrir');
    expect(again.state.count('item.herbs'), 4);
    expect(again.state.count('item.chalk'), 3);
    expect(again.state.collection.single.speciesId, 'rill.eco');
    expect(again.state.isDone(-5), isTrue);
    expect(again.state.toJson(0)['future_field'], {'x': 1});
  });

  test('várias mudanças seguidas terminam gravadas em ordem', () async {
    final store = MemorySaveStore();
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1, nextInt: (n) => 0);
    for (var i = 0; i < 20; i++) {
      session.state.add('item.scrap', 1);
    }
    await session.flush();
    expect((store.json!['inventory'] as Map)['item.scrap'], 20);
  });
}
