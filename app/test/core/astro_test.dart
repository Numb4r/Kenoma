import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';

int utc(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

/// O instante, em minutos UTC desde a meia-noite, em que a altura do sol cruza [level] graus subindo ([rising]) ou
/// descendo, no dia [day].
double crossing(double lat, double lon, String day, double level, {required bool rising}) {
  final t0 = utc('${day}T00:00:00Z');
  double? prev;
  for (var m = 0; m <= 24 * 60; m++) {
    final alt = sunAltitudeDeg(lat, lon, t0 + m * 60);
    if (prev != null && ((rising && prev < level && alt >= level) || (!rising && prev > level && alt <= level))) return m.toDouble();
    prev = alt;
  }
  throw StateError('sem cruzamento');
}

double maxAltitude(double lat, double lon, String day) {
  final t0 = utc('${day}T00:00:00Z');
  var best = -90.0;
  for (var m = 0; m <= 24 * 60; m += 2) {
    final a = sunAltitudeDeg(lat, lon, t0 + m * 60);
    if (a > best) best = a;
  }
  return best;
}

void main() {
  const campinas = (-22.8174, -47.0697);

  group('altura do sol', () {
    test('no equinócio o sol passa a pino sobre o equador', () {
      expect(maxAltitude(0, 0, '2026-03-20'), closeTo(90, 1.0));
    });

    test('solstício de verão no sul: sol quase a pino em Campinas; de inverno: 43,7° ao meio-dia', () {
      expect(maxAltitude(campinas.$1, campinas.$2, '2026-12-21'), closeTo(89.5, 0.6));
      expect(maxAltitude(campinas.$1, campinas.$2, '2026-06-21'), closeTo(43.7, 0.6));
    });

    test('o nascer e o pôr do sol de Campinas em 21/12 batem com as tabelas (~05:23 e ~18:47 em Brasília)', () {
      // Brasília é UTC-3. A altura geométrica zero adianta o nascer e atrasa o pôr uns 4 min em relação às tabelas.
      final rise = crossing(campinas.$1, campinas.$2, '2026-12-21', 0, rising: true);
      final set = crossing(campinas.$1, campinas.$2, '2026-12-21', 0, rising: false);
      expect(rise / 60, closeTo(8 + 23 / 60, 0.2), reason: '05:23 BRT = 08:23 UTC');
      expect(set / 60, closeTo(21 + 47 / 60, 0.2), reason: '18:47 BRT = 21:47 UTC');
    });

    test('meia-noite local é noite, e o dia tem o sol alto no meio dele', () {
      expect(sunAltitudeDeg(campinas.$1, campinas.$2, utc('2026-10-15T03:00:00Z')), lessThan(-30)); // 00:00 BRT
      expect(sunAltitudeDeg(campinas.$1, campinas.$2, utc('2026-10-15T15:00:00Z')), greaterThan(60)); // 12:00 BRT
    });

    test('a longitude muda a hora: o mesmo instante é dia num lugar e noite no oposto', () {
      final t = utc('2026-06-21T12:00:00Z');
      expect(sunAltitudeDeg(0, 0, t), greaterThan(60));
      expect(sunAltitudeDeg(0, 180, t), lessThan(-60));
    });

    test('é função só da data e da posição: o mesmo instante dá o mesmo valor', () {
      final t = utc('2026-10-15T14:03:00Z');
      expect(sunAltitudeDeg(-22.8, -47.0, t), sunAltitudeDeg(-22.8, -47.0, t));
    });
  });

  group('luz do mapa', () {
    test('dia pleno, noite fechada e nada de corte no meio', () {
      expect(lightForAltitude(30).night, 0);
      expect(lightForAltitude(4).night, 0);
      expect(lightForAltitude(-12).night, 1);
      expect(lightForAltitude(-40).night, 1);
      var prev = lightForAltitude(10).night;
      for (var a = 10.0; a >= -20; a -= 0.25) {
        final n = lightForAltitude(a).night;
        expect(n, greaterThanOrEqualTo(prev - 1e-12), reason: 'só escurece conforme o sol desce');
        expect(n - prev, lessThan(0.06), reason: 'em passos de 0,25° não há salto: amanhecer e anoitecer suaves');
        prev = n;
      }
    });

    test('o tom quente só aparece com o sol baixo', () {
      expect(lightForAltitude(40).warm, 0);
      expect(lightForAltitude(-20).warm, 0);
      expect(lightForAltitude(3).warm, closeTo(1, 1e-9));
      expect(lightForAltitude(0).warm, greaterThan(0.4));
    });

    test('ao longo de um dia real a noite sobe e desce uma vez só em Campinas', () {
      final t0 = utc('2026-10-15T00:00:00Z');
      var flips = 0;
      var wasDay = dayLightAt(campinas.$1, campinas.$2, t0).isDay;
      for (var m = 1; m <= 24 * 60; m++) {
        final day = dayLightAt(campinas.$1, campinas.$2, t0 + m * 60).isDay;
        if (day != wasDay) flips++;
        wasDay = day;
      }
      expect(flips, 2);
    });
  });

  group('lua', () {
    test('lua cheia de 26/09/2026 e lua nova de 10/10/2026 (tolerância de um dia: é a fase média)', () {
      expect(moonCycle(utc('2026-09-26T16:49:00Z')), closeTo(0.5, 0.04));
      expect(moonPhase(utc('2026-09-26T16:49:00Z')), MoonPhase.fullMoon);
      final nearNew = moonCycle(utc('2026-10-10T15:50:00Z'));
      expect(nearNew < 0.04 || nearNew > 0.96, isTrue, reason: 'ciclo $nearNew');
      expect(moonPhase(utc('2026-10-10T15:50:00Z')), MoonPhase.newMoon);
    });

    test('iluminação: 0 na nova, 1 na cheia, 0,5 nos quartos', () {
      expect(moonIllumination(utc('2026-10-10T15:50:00Z')), lessThan(0.03));
      expect(moonIllumination(utc('2026-09-26T16:49:00Z')), greaterThan(0.97));
      expect(moonIllumination(utc('2026-10-03T00:00:00Z')), closeTo(0.5, 0.2)); // perto do quarto minguante
    });

    test('as oito fases passam em ordem, uma vez por mês', () {
      final seen = <MoonPhase>[];
      final t0 = utc('2026-10-10T16:00:00Z');
      for (var d = 0; d < 30; d++) {
        final p = moonPhase(t0 + d * 86400);
        if (seen.isEmpty || seen.last != p) seen.add(p);
      }
      expect(seen.take(8), MoonPhase.values);
      expect(moonPhaseNames.length, 8);
    });

    test('a idade fica sempre entre 0 e o mês sinódico, mesmo antes de 2000', () {
      for (final t in [0, utc('1999-05-05T00:00:00Z'), utc('2026-10-15T00:00:00Z'), utc('2100-01-01T00:00:00Z')]) {
        final a = moonAgeDays(t);
        expect(a, inInclusiveRange(0, synodicMonthDays));
      }
    });
  });
}
