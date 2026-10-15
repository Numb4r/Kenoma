import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/moon_hud.dart';

double area(List<Offset> p) {
  var a = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[(i + 1) % p.length];
    a += p[i].dx * q.dy - q.dx * p[i].dy;
  }
  return a.abs() / 2;
}

double centroidX(List<Offset> p) => p.map((o) => o.dx).reduce((a, b) => a + b) / p.length;

void main() {
  test('a área iluminada é a fração iluminada da lua em todas as fases', () {
    for (var c = 0.02; c < 1; c += 0.07) {
      final frac = area(moonLitPolygon(c, 10, steps: 64)) / (math.pi * 100);
      expect(frac, closeTo((1 - math.cos(2 * math.pi * c)) / 2, 0.02), reason: 'ciclo $c');
    }
  });

  test('no norte a crescente acende a direita e a minguante a esquerda; no sul é o espelho', () {
    expect(centroidX(moonLitPolygon(0.1, 10)), greaterThan(0));
    expect(centroidX(moonLitPolygon(0.9, 10)), lessThan(0));
    expect(centroidX(moonLitPolygon(0.1, 10, southern: true)), lessThan(0));
    expect(centroidX(moonLitPolygon(0.9, 10, southern: true)), greaterThan(0));
  });

  test('lua cheia é o disco inteiro e a nova quase não tem luz', () {
    expect(area(moonLitPolygon(0.5, 10, steps: 64)) / (math.pi * 100), closeTo(1, 0.01));
    expect(area(moonLitPolygon(0.0, 10, steps: 64)) / (math.pi * 100), lessThan(0.01));
  });
}
