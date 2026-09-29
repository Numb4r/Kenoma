import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/vibe.dart';

void main() {
  final fire = identityPattern(EcoType.fire);
  final water = identityPattern(EcoType.water);
  final plant = identityPattern(EcoType.plant);

  test('formato do pacote vibration: [espera, vibra, ...] e uma amplitude por posição', () {
    for (final p in [fire, water, plant, fireWarningPattern, waterSwellPattern, plantPulsePattern(80)]) {
      expect(p.pattern.length, p.segments.length * 2);
      expect(p.intensities.length, p.pattern.length);
      for (var i = 0; i < p.segments.length; i++) {
        expect(p.pattern[2 * i], p.segments[i].pauseMs);
        expect(p.pattern[2 * i + 1], p.segments[i].durationMs);
        expect(p.intensities[2 * i], 0, reason: 'esperas têm amplitude 0');
        expect(p.intensities[2 * i + 1], inInclusiveRange(1, 255));
      }
      expect(p.totalMs, p.pattern.reduce((a, b) => a + b));
    }
  });

  test('as três identidades são diferentes entre si', () {
    expect(fire.pattern, isNot(water.pattern));
    expect(fire.pattern, isNot(plant.pattern));
    expect(water.pattern, isNot(plant.pattern));
  });

  group('dá para reconhecer de olhos fechados', () {
    test('Fogo: rajada de toques secos e muito curtos, com pausa entre eles', () {
      expect(fire.segments.length, greaterThanOrEqualTo(3));
      expect(fire.segments.every((s) => s.durationMs <= 40), isTrue);
      expect(fire.segments.skip(1).every((s) => s.pauseMs >= 40), isTrue);
      expect(fire.segments.every((s) => s.amplitude == 255), isTrue, reason: 'seco: sempre no máximo');
    });

    test('Água: uma onda longa e contínua, sem pausas, que sobe e desce', () {
      expect(water.totalMs, greaterThanOrEqualTo(600));
      expect(water.segments.every((s) => s.pauseMs == 0), isTrue);
      final a = [for (final s in water.segments) s.amplitude];
      final peak = a.indexOf(a.reduce((x, y) => x > y ? x : y));
      expect(peak, greaterThan(0));
      expect(peak, lessThan(a.length - 1));
      for (var i = 1; i <= peak; i++) {
        expect(a[i], greaterThanOrEqualTo(a[i - 1]));
      }
      for (var i = a.length - 1; i > peak; i--) {
        expect(a[i - 1], greaterThanOrEqualTo(a[i]));
      }
    });

    test('Planta: pulsos cada vez mais curtos', () {
      final d = [for (final s in plant.segments) s.durationMs];
      expect(d.length, greaterThanOrEqualTo(3));
      for (var i = 1; i < d.length; i++) {
        expect(d[i], lessThan(d[i - 1]));
      }
      expect(plant.segments.skip(1).every((s) => s.pauseMs > 0), isTrue);
    });

    test('duração e ritmo separam os tipos mesmo sem controle de amplitude', () {
      // Sem amplitude só resta o liga e desliga: Água é um bloco longo, Fogo é picotado e curto,
      // Planta é picotado com pulsos maiores que os do Fogo.
      final longestFire = fire.segments.map((s) => s.durationMs).reduce((a, b) => a > b ? a : b);
      final longestPlant = plant.segments.map((s) => s.durationMs).reduce((a, b) => a > b ? a : b);
      expect(longestFire, lessThan(longestPlant));
      expect(water.totalMs, greaterThan(fire.totalMs));
      expect(water.segments.fold(0, (m, s) => m + s.pauseMs), 0);
    });
  });

  group('vibrações de resistência', () {
    test('Fogo: um toque curto de aviso', () {
      expect(fireWarningPattern.segments, hasLength(1));
      expect(fireWarningPattern.totalMs, lessThanOrEqualTo(50));
    });

    test('Água: ondulação longa', () {
      expect(waterSwellPattern.totalMs, greaterThanOrEqualTo(400));
      expect(waterSwellPattern.segments.every((s) => s.pauseMs == 0), isTrue);
    });

    test('Planta: um pulso com a duração pedida', () {
      expect(plantPulsePattern(90).segments.single.durationMs, 90);
    });
  });
}
