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
}
