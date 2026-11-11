import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/motion_model.dart';

void main() {
  const m = MotionModel();
  const mpc = 17.6;

  test('Eco Passivo: anda devagar num raio pequeno, sem salto, igual em dois aparelhos', () {
    expect(m.wander(1234, 1900000000), m.wander(1234, 1900000000));
    expect(m.wander(1234, 1900000000), isNot(m.wander(1235, 1900000000)), reason: 'cada Eco com a sua fase');
    var prev = m.wander(77, 0), maxR = 0.0, moved = 0.0;
    for (var t = 0.25; t < 600; t += 0.25) {
      final p = m.wander(77, t);
      final r = math.sqrt(p.$1 * p.$1 + p.$2 * p.$2), step = math.sqrt(math.pow(p.$1 - prev.$1, 2) + math.pow(p.$2 - prev.$2, 2));
      maxR = math.max(maxR, r);
      moved += step;
      expect(step, lessThan(0.2), reason: 'a 4 Hz, menos de 20 cm por leitura');
      prev = p;
    }
    expect(maxR, lessThanOrEqualTo(m.wanderM + 1e-9));
    expect(maxR, greaterThan(m.wanderM * 0.6));
    expect(moved / 600, inInclusiveRange(0.05, 0.6), reason: 'devagar: centímetros a decímetros por segundo');
    // Vetor fixo, para pegar qualquer mudança na conta.
    final v = m.wander(42, 1000.0);
    expect((v.$1 * 1e6).round(), -1281461);
    expect((v.$2 * 1e6).round(), -752296);
  });

  test('Eco de Água: ronda a poça num círculo', () {
    for (var t = 0.0; t < 200; t += 3) {
      final p = m.orbit(9, t);
      expect(math.sqrt(p.$1 * p.$1 + p.$2 * p.$2), closeTo(m.waterOrbitM, 1e-9));
    }
    final a = m.orbit(9, 0), b = m.orbit(9, m.waterOrbitPeriodS);
    expect(b.$1, closeTo(a.$1, 1e-9), reason: 'uma volta por período');
    expect(b.$2, closeTo(a.$2, 1e-9));
  });

  test('Correntes do Véu: nove em dez células têm redemoinho, fixo pela seed', () {
    var n = 0;
    for (var i = 0; i < 2000; i++) {
      final v = m.vortexOf(7, 9, 100000 + i % 50, 200000 + i ~/ 50);
      if (v == null) continue;
      n++;
      expect(v.$1 ~/ 8, 100000 + i % 50);
      expect(v.$2 ~/ 8, 200000 + i ~/ 50);
    }
    expect(n, inInclusiveRange(1740, 1860));
    expect(m.vortexOf(7, 9, 100000, 200000), m.vortexOf(7, 9, 100000, 200000));
    expect([for (var i = 0; i < 40; i++) m.vortexOf(8, 9, 100000 + i, 200000)], isNot([for (var i = 0; i < 40; i++) m.vortexOf(7, 9, 100000 + i, 200000)]));
  });

  test('a Fagulha desliza para o redemoinho, chega sem salto e gira em volta', () {
    const vortex = (800004.0, 1600002.0), x = 800002.5, y = 1600002.0; // 26,4 m a oeste do redemoinho
    expect(m.current(5, x, y, vortex, 0, mpc), (x, y), reason: 'nasce onde nasceu');
    final half = m.current(5, x, y, vortex, 100, mpc);
    expect((half.$1 - x) * mpc, closeTo(4.0, 1e-9), reason: '0,04 m/s por 100 s, em linha reta');
    expect(half.$2, closeTo(y, 1e-12));
    var prev = m.current(5, x, y, vortex, 0, mpc);
    for (var age = 1.0; age <= 1200; age += 1) {
      final p = m.current(5, x, y, vortex, age, mpc);
      final step = math.sqrt(math.pow((p.$1 - prev.$1) * mpc, 2) + math.pow((p.$2 - prev.$2) * mpc, 2));
      expect(step, lessThan(0.3), reason: 'sem salto aos $age s');
      final d = math.sqrt(math.pow((p.$1 - vortex.$1) * mpc, 2) + math.pow((p.$2 - vortex.$2) * mpc, 2));
      expect(d, greaterThanOrEqualTo(m.vortexOrbitM - 1e-6), reason: 'não atravessa o redemoinho');
      prev = p;
    }
    final end = m.current(5, x, y, vortex, 1200, mpc);
    expect(math.sqrt(math.pow((end.$1 - vortex.$1) * mpc, 2) + math.pow((end.$2 - vortex.$2) * mpc, 2)), closeTo(m.vortexOrbitM, 1e-6), reason: 'girando em volta');
    // Duas Fagulhas da vizinhança acabam no mesmo redemoinho.
    final other = m.current(6, 800005.0, 1600003.5, vortex, 1200, mpc);
    expect(math.sqrt(math.pow((other.$1 - end.$1) * mpc, 2) + math.pow((other.$2 - end.$2) * mpc, 2)), lessThanOrEqualTo(2 * m.vortexOrbitM + 1e-6));
  });

  test('a Fagulha procura o redemoinho mais perto, até o alcance', () {
    var withOne = 0, far = 0;
    for (var i = 0; i < 300; i++) {
      final x = 800000.0 + i * 3.7, y = 1600000.0 + i * 1.3;
      final v = m.vortexFor(7, 9, x, y, mpc);
      if (v == null) continue;
      withOne++;
      if (math.sqrt(math.pow((v.$1 - x) * mpc, 2) + math.pow((v.$2 - y) * mpc, 2)) > m.currentMaxM) far++;
    }
    expect(withOne, greaterThan(120));
    expect(far, 0);
  });
}
