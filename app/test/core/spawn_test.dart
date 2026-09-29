import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/spawn.dart';

import '../support/fixtures.dart';

List<SpawnItem> cell(Epoch epoch, String key, {int cx = vectorCellX, int cy = vectorCellY, int window = vectorWindow}) =>
    generateCell(seed: vectorSeed, epoch: epoch, cellX: cx, cellY: cy, window: window, biomeKey: key);

/// Cópia da época 0 com a chance de todos os itens trocada por [chance].
Epoch withChance(double chance) {
  final json = jsonDecode(jsonEncode(epochsJson())) as Map<String, dynamic>;
  final e0 = (json['epochs'] as List<dynamic>).single as Map<String, dynamic>;
  for (final item in (e0['spawn'] as Map<String, dynamic>)['items'] as List<dynamic>) {
    final chances = (item as Map<String, dynamic>)['chance'] as Map<String, dynamic>;
    for (final k in chances.keys) {
      chances[k] = chance;
    }
  }
  return Epoch.fromJson(e0);
}

void main() {
  final epoch = loadEpochs().epochs.single;

  test('vetores da spec: h_0 e uid_0 da época 0', () {
    expect(spawnHash(vectorSeed, 0, vectorCellX, vectorCellY, vectorWindow, 0), 0x90a9f55334e3a1bc);
    expect(spawnUid(vectorSeed, 0, vectorCellX, vectorCellY, vectorWindow, 0), 0xb15342d5daf75c2d);
  });

  test('h_i e uid_i mudam com o índice, a época, a célula e a janela', () {
    final base = spawnHash(vectorSeed, 0, vectorCellX, vectorCellY, vectorWindow, 0);
    expect(spawnHash(vectorSeed, 0, vectorCellX, vectorCellY, vectorWindow, 1), isNot(base));
    expect(spawnHash(vectorSeed, 1, vectorCellX, vectorCellY, vectorWindow, 0), isNot(base));
    expect(spawnHash(vectorSeed, 0, vectorCellX + 1, vectorCellY, vectorWindow, 0), isNot(base));
    expect(spawnHash(vectorSeed, 0, vectorCellX, vectorCellY, vectorWindow + 1, 0), isNot(base));
    expect(spawnUid(vectorSeed, 0, vectorCellX, vectorCellY, vectorWindow, 0), isNot(base), reason: 'salts diferentes');
  });

  group('valores fixos da célula do vetor (segunda implementação independente, em Python)', () {
    void expectItem(SpawnItem i, int index, bool exists, String entry, int? delta, int qty, double px, double py, int uid) {
      expect(i.index, index);
      expect(i.exists, exists, reason: 'item $index');
      expect(i.entryId, entry, reason: 'item $index');
      expect(i.levelDelta, delta, reason: 'item $index');
      expect(i.quantity, qty, reason: 'item $index');
      expect(i.px, px, reason: 'item $index');
      expect(i.py, py, reason: 'item $index');
      expect(i.uid, uid, reason: 'item $index');
    }

    test('urbano', () {
      final items = cell(epoch, 'urban');
      expectItem(items[0], 0, false, 'soot.eco', 1, 1, 0.9405720923095942, 0.7890118251089007, 0xb15342d5daf75c2d);
      expectItem(items[1], 1, true, 'item.dust.plant', null, 1, 0.7773419993463904, 0.17112608067691326, 0x8eea7d7ebe0ef0);
      expectItem(items[2], 2, false, 'item.dust.fire', null, 1, 0.19933417974971235, 0.45233821612782776, 0xe6ab800a352f1317);
      expectItem(items[3], 3, false, 'item.chalk', null, 3, 0.2633866223040968, 0.03894061129540205, 0xc31b9290c62a426a);
    });

    test('residencial: só a espécie muda, os demais sorteios são os mesmos', () {
      final items = cell(epoch, 'residential');
      expectItem(items[0], 0, false, 'frond.eco', 1, 1, 0.9405720923095942, 0.7890118251089007, 0xb15342d5daf75c2d);
      expectItem(items[1], 1, true, 'item.dust.water', null, 1, 0.7773419993463904, 0.17112608067691326, 0x8eea7d7ebe0ef0);
      expectItem(items[2], 2, false, 'item.dust.plant', null, 1, 0.19933417974971235, 0.45233821612782776, 0xe6ab800a352f1317);
      expectItem(items[3], 3, false, 'item.herbs', null, 3, 0.2633866223040968, 0.03894061129540205, 0xc31b9290c62a426a);
    });

    test('água, célula vizinha e janela seguinte', () {
      final items = cell(epoch, 'water', cx: vectorCellX + 1, window: vectorWindow + 1);
      expectItem(items[0], 0, false, 'rill.eco', -1, 1, 0.27335180109366775, 0.43919435515999794, 0xbfc8d374dd214e7d);
      expectItem(items[1], 1, false, 'item.dust.water', null, 1, 0.5482350359670818, 0.8878142884932458, 0x395e90ecb1855c00);
      expectItem(items[2], 2, false, 'item.dust.water', null, 1, 0.8330262084491551, 0.6507992171682417, 0xce5e50f6b760c327);
      expectItem(items[3], 3, false, 'item.pure_water', null, 1, 0.48220837116241455, 0.21486765914596617, 0x2902b86e7009663a);
    });
  });

  test('estrutura: quatro itens fixos, com eco, duas fagulhas e um material', () {
    final items = cell(epoch, 'urban');
    expect(items.map((i) => i.index), [0, 1, 2, 3]);
    expect(items.map((i) => i.kind), ['eco', 'spark', 'spark', 'material']);
    expect(items.map((i) => i.uid).toSet(), hasLength(4));
  });

  test('determinismo: mesma entrada, mesma saída', () {
    final a = cell(epoch, 'green');
    final b = cell(epoch, 'green');
    for (var i = 0; i < 4; i++) {
      expect((a[i].exists, a[i].entryId, a[i].quantity, a[i].px, a[i].py, a[i].uid),
          (b[i].exists, b[i].entryId, b[i].quantity, b[i].px, b[i].py, b[i].uid));
    }
  });

  test('todo item consome os mesmos sorteios existindo ou não', () {
    final never = withChance(0.0);
    final always = withChance(1.0);
    for (var w = 0; w < 200; w++) {
      final a = cell(never, 'urban', window: vectorWindow + w);
      final b = cell(always, 'urban', window: vectorWindow + w);
      for (var i = 0; i < 4; i++) {
        expect(a[i].exists, isFalse);
        expect(b[i].exists, isTrue);
        expect((a[i].entryId, a[i].levelDelta, a[i].quantity, a[i].px, a[i].py, a[i].uid),
            (b[i].entryId, b[i].levelDelta, b[i].quantity, b[i].px, b[i].py, b[i].uid),
            reason: 'janela $w item $i');
      }
    }
  });

  test('faixas: delta do Eco em [-2, 2], quantidade da tabela, posição em [0, 1)', () {
    for (var w = 0; w < 500; w++) {
      final items = cell(epoch, 'green', window: vectorWindow + w);
      expect(items[0].levelDelta, inInclusiveRange(-2, 2));
      for (final i in items.skip(1)) {
        expect(i.levelDelta, isNull);
      }
      for (final i in items) {
        final def = epoch.items[i.index];
        expect(i.quantity, inInclusiveRange(def.qtyMin, def.qtyMax));
        expect(i.px, allOf(greaterThanOrEqualTo(0.0), lessThan(1.0)));
        expect(i.py, allOf(greaterThanOrEqualTo(0.0), lessThan(1.0)));
        expect(def.table['green']!.map((e) => e.id), contains(i.entryId));
      }
    }
  });

  test('sorteio ponderado: espécie nativa sai ~6 vezes em 8, e a chance de existir é respeitada', () {
    const n = 4000;
    var soot = 0, exists = 0;
    for (var w = 0; w < n; w++) {
      final eco = cell(epoch, 'urban', window: vectorWindow + w)[0];
      if (eco.entryId == 'soot.eco') soot++;
      if (eco.exists) exists++;
    }
    expect(soot / n, closeTo(6 / 8, 0.03));
    expect(exists / n, closeTo(epoch.items[0].chance['urban']!, 0.02));
  });

  test('bioma sem chance ou sem tabela é erro de dados', () {
    expect(() => cell(epoch, 'lava'), throwsStateError);
  });

  test('uid inclui a janela: o mesmo ponto não repete uid na janela seguinte', () {
    final a = cell(epoch, 'urban');
    final b = cell(epoch, 'urban', window: vectorWindow + 1);
    expect(a.map((i) => i.uid).toSet().intersection(b.map((i) => i.uid).toSet()), isEmpty);
    expect(hex64(a[0].uid), '0xb15342d5daf75c2d');
  });
}
