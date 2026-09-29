import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/hidden_type.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

void main() {
  Pcg32 rng(int seed) => Pcg32(fnv1a64([seed]), saltKenoma);

  test('mesma semente, mesmo tipo', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(pickHiddenType(rng(seed)), pickHiddenType(rng(seed)));
    }
  });

  test('os três tipos saem, com frequência parecida', () {
    final counts = {for (final t in EcoType.values) t: 0};
    const n = 3000;
    for (var seed = 0; seed < n; seed++) {
      counts[pickHiddenType(rng(seed))] = counts[pickHiddenType(rng(seed))]! + 1;
    }
    for (final t in EcoType.values) {
      expect(counts[t]! / n, closeTo(1 / 3, 0.04), reason: t.name);
    }
  });

  test('sorteios seguidos do mesmo gerador variam', () {
    final r = rng(1);
    expect({for (var i = 0; i < 60; i++) pickHiddenType(r)}, EcoType.values.toSet());
  });

  group('pickHidden', () {
    const pool = [EcoType.fire, EcoType.plant, EcoType.water];

    test('nunca falha: sempre acha o item do tipo sorteado', () {
      for (var seed = 0; seed < 5000; seed++) {
        expect(() => pickHidden(pool, (t) => t, rng(seed)), returnsNormally, reason: 'semente $seed');
      }
    });

    test('sorteia o tipo uma vez só: consome um número do gerador, não um por item', () {
      for (var seed = 0; seed < 50; seed++) {
        final used = rng(seed);
        final reference = rng(seed);
        pickHidden(pool, (t) => t, used);
        reference.nextInt(3);
        expect(used.next(), reference.next(), reason: 'semente $seed');
      }
    });

    test('o item devolvido é do tipo sorteado por pickHiddenType', () {
      for (var seed = 0; seed < 200; seed++) {
        expect(pickHidden(pool, (t) => t, rng(seed)), pickHiddenType(rng(seed)));
      }
    });

    test('sem viés pela ordem do pool: cada tipo sai ~1/3, em qualquer ordem', () {
      for (final order in [pool, pool.reversed.toList(), [pool[1], pool[2], pool[0]]]) {
        final counts = {for (final t in EcoType.values) t: 0};
        const n = 3000;
        for (var seed = 0; seed < n; seed++) {
          final t = pickHidden(order, (x) => x, rng(seed));
          counts[t] = counts[t]! + 1;
        }
        for (final t in EcoType.values) {
          expect(counts[t]! / n, closeTo(1 / 3, 0.04), reason: '$t em $order');
        }
      }
    });

    test('falta um tipo no pool: erro em vez de escolher outro', () {
      expect(() => pickHidden([EcoType.fire], (t) => t, rng(2)), throwsStateError);
    });
  });
}
