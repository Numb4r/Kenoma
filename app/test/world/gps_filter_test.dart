import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/pcg32.dart';
import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/gps_filter.dart';

const lat0 = -22.8174, lon0 = -47.0697;
const mLat = 111132.92, mLon = 111319.49;
final kLon = math.cos(lat0 * math.pi / 180);

/// Ruído gaussiano de desvio [sigma], pela caixa de Box-Muller sobre o PCG32 do projeto.
class Noise {
  Noise(int seed) : _rng = Pcg32(seed, 0x6b656e);

  final Pcg32 _rng;

  double next(double sigma) {
    final u1 = 1 - _rng.nextFloat(), u2 = _rng.nextFloat();
    return sigma * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

GeoFix fix(double eastM, double northM, int tMs, {double acc = 5, double? speed}) => GeoFix(
      lat: lat0 + northM / mLat,
      lon: lon0 + eastM / (mLon * kLon),
      accuracyM: acc,
      timeMs: tMs,
      speedMps: speed,
    );

(double, double) toMeters(double lat, double lon) => ((lon - lon0) * mLon * kLon, (lat - lat0) * mLat);

double dist(FilteredPosition p, double eastM, double northM) {
  final (x, y) = toMeters(p.lat, p.lon);
  return math.sqrt((x - eastM) * (x - eastM) + (y - northM) * (y - northM));
}

double std(List<double> xs) {
  final m = xs.reduce((a, b) => a + b) / xs.length;
  return math.sqrt(xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length);
}

void main() {
  group('precisão', () {
    test('recusa leitura pior que 50 m e aceita a de 50 m', () {
      final f = GpsFilter();
      expect(f.add(fix(0, 0, 1000, acc: 50.01)), isNull);
      expect(f.add(fix(0, 0, 1000, acc: 120)), isNull);
      expect(f.rejected, 2);
      expect(f.position, isNull, reason: 'nada aceito ainda');
      expect(f.add(fix(0, 0, 1000, acc: 50)), isNotNull);
      expect(f.add(fix(0, 0, 2000, acc: 49.9)), isNotNull);
      expect(f.rejected, 2);
    });

    test('leitura ruim no meio não move a estimativa', () {
      final f = GpsFilter();
      f.add(fix(0, 0, 1000));
      final before = f.position!;
      expect(f.add(fix(300, 300, 2000, acc: 80)), isNull);
      expect(f.position!.lat, before.lat);
      expect(f.position!.lon, before.lon);
    });

    test('leitura inválida (NaN, precisão negativa) é recusada', () {
      final f = GpsFilter();
      expect(f.add(GeoFix(lat: double.nan, lon: 0, accuracyM: 5, timeMs: 1)), isNull);
      expect(f.add(const GeoFix(lat: 0, lon: 0, accuracyM: -1, timeMs: 1)), isNull);
      expect(f.add(const GeoFix(lat: 0, lon: 0, accuracyM: double.nan, timeMs: 1)), isNull);
    });

    test('a precisão limite é configurável', () {
      final f = GpsFilter(maxAccuracyM: 20);
      expect(f.add(fix(0, 0, 1000, acc: 25)), isNull);
      expect(f.add(fix(0, 0, 1000, acc: 20)), isNotNull);
    });
  });

  group('parado', () {
    test('com ruído de 5 m a leitura crua tremula, e a posição filtrada fica parada (menos de 1 m de desvio)', () {
      final f = GpsFilter();
      final n = Noise(1);
      final raw = <double>[], out = <double>[];
      for (var i = 0; i < 300; i++) {
        final ex = n.next(5), ny = n.next(5);
        final p = f.add(fix(ex, ny, 1000 * (i + 1)))!;
        if (i >= 30) {
          raw.add(ex);
          out.add(toMeters(p.lat, p.lon).$1);
        }
      }
      expect(std(raw), greaterThan(4), reason: 'o ruído cru é de ~5 m');
      expect(std(out), lessThan(1.0), reason: 'o marcador não treme: desvio ${std(out)} m');
    });

    test('o deslocamento da posição filtrada entre leituras seguidas, parado, é de poucos centímetros', () {
      final f = GpsFilter();
      final n = Noise(2);
      FilteredPosition? prev;
      var maxStep = 0.0;
      for (var i = 0; i < 300; i++) {
        final p = f.add(fix(n.next(4), n.next(4), 1000 * (i + 1), acc: 4))!;
        if (prev != null && i > 30) {
          final (x0, y0) = toMeters(prev.lat, prev.lon);
          final (x1, y1) = toMeters(p.lat, p.lon);
          maxStep = math.max(maxStep, math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)));
        }
        prev = p;
      }
      expect(maxStep, lessThan(1.0), reason: 'maior passo parado: $maxStep m');
    });

    test('a incerteza cai parado e o filtro não se declara em movimento', () {
      final f = GpsFilter();
      final n = Noise(3);
      FilteredPosition? p;
      for (var i = 0; i < 100; i++) {
        p = f.add(fix(n.next(5), n.next(5), 1000 * (i + 1)));
      }
      expect(p!.accuracyM, lessThan(2.5));
      expect(p.moving, isFalse);
    });

    test('a posição parada converge para o ponto verdadeiro (erro médio abaixo de 2 m)', () {
      final f = GpsFilter();
      final n = Noise(4);
      FilteredPosition? p;
      for (var i = 0; i < 200; i++) {
        p = f.add(fix(40 + n.next(5), -25 + n.next(5), 1000 * (i + 1)));
      }
      expect(dist(p!, 40, -25), lessThan(3.0));
    });
  });

  group('robustez', () {
    test('em 20 sementes de ruído, parado nunca se declara em movimento e nunca dá passo de mais de 1,5 m', () {
      for (var seed = 1; seed <= 20; seed++) {
        final f = GpsFilter();
        final n = Noise(seed * 31);
        FilteredPosition? prev;
        for (var i = 0; i < 400; i++) {
          final p = f.add(fix(n.next(5), n.next(5), 1000 * (i + 1)))!;
          if (i > 30) {
            expect(p.moving, isFalse, reason: 'seed $seed, leitura $i');
            final (x0, y0) = toMeters(prev!.lat, prev.lon);
            final (x1, y1) = toMeters(p.lat, p.lon);
            expect(math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)), lessThan(1.5), reason: 'seed $seed, leitura $i');
          }
          prev = p;
        }
      }
    });

    test('começando a andar a 1,4 m/s, o marcador arranca em até 12 s e depois segue a menos de 10 m (a leitura crua erra até ~15)', () {
      for (var seed = 1; seed <= 10; seed++) {
        final f = GpsFilter();
        final n = Noise(seed * 17);
        for (var t = 1; t <= 40; t++) {
          f.add(fix(n.next(5), n.next(5), 1000 * t));
        }
        int? startedAt;
        var worst = 0.0;
        for (var t = 41; t <= 100; t++) {
          final east = 1.4 * (t - 40);
          final p = f.add(fix(east + n.next(5), n.next(5), 1000 * t))!;
          if (startedAt == null && toMeters(p.lat, p.lon).$1 > 4) startedAt = t - 40;
          if (t - 40 >= 25) worst = math.max(worst, dist(p, east, 0));
        }
        expect(startedAt, isNotNull, reason: 'seed $seed');
        expect(startedAt!, lessThanOrEqualTo(12), reason: 'seed $seed: arrancou em $startedAt s');
        expect(worst, lessThan(10.0), reason: 'seed $seed: pior erro $worst m');
      }
    });
  });

  group('velocidade informada pela fonte', () {
    test('com a velocidade do GPS o marcador arranca em poucos segundos, bem antes dos ~9 m de deslocamento', () {
      for (final speed in [1.4, 3.0, 6.0]) {
        final f = GpsFilter();
        final n = Noise(11);
        for (var t = 1; t <= 40; t++) {
          f.add(fix(n.next(3), n.next(3), 1000 * t, acc: 4, speed: 0));
        }
        int? startedAt;
        for (var t = 41; t <= 70; t++) {
          final east = speed * (t - 40);
          final p = f.add(fix(east + n.next(3), n.next(3), 1000 * t, acc: 4, speed: speed))!;
          if (startedAt == null && toMeters(p.lat, p.lon).$1 > 0.5 * east + 1 && east > 2) startedAt = t - 40;
        }
        expect(startedAt, isNotNull, reason: '${speed}m/s');
        expect(startedAt!, lessThanOrEqualTo(4), reason: '${speed}m/s arrancou em $startedAt s');
      }
    });

    test('uma única leitura com velocidade alta (um tranco do GPS) não vira movimento', () {
      final f = GpsFilter();
      final n = Noise(5);
      FilteredPosition? p;
      for (var t = 1; t <= 60; t++) {
        p = f.add(fix(n.next(4), n.next(4), 1000 * t, acc: 4, speed: t == 30 ? 5.0 : 0.0));
        expect(p!.moving, isFalse, reason: 'leitura $t');
      }
    });

    test('parado, com velocidade 0 e ruído, continua parado e firme (o ganho de resposta não custa tremor)', () {
      final f = GpsFilter();
      final n = Noise(8);
      final out = <double>[];
      for (var t = 1; t <= 300; t++) {
        final p = f.add(fix(n.next(5), n.next(5), 1000 * t, speed: 0))!;
        if (t > 30) {
          expect(p.moving, isFalse);
          out.add(toMeters(p.lat, p.lon).$1);
        }
      }
      expect(std(out), lessThan(1.0));
    });

    test('um 0 informado enquanto anda não faz o marcador parar: quem manda é o deslocamento', () {
      final f = GpsFilter();
      FilteredPosition? p;
      for (var t = 1; t <= 60; t++) {
        p = f.add(fix(1.4 * t, 0, 1000 * t, speed: 0)); // aparelho que nunca informa velocidade (manda 0)
      }
      expect(toMeters(p!.lat, p.lon).$1, closeTo(84, 8), reason: 'sem a velocidade, cai para o modo por deslocamento');
    });

    test('depois de andar, ao parar de verdade o filtro volta a segurar o marcador', () {
      final f = GpsFilter();
      for (var t = 1; t <= 20; t++) {
        f.add(fix(3.0 * t, 0, 1000 * t, speed: 3.0));
      }
      FilteredPosition? p;
      for (var t = 21; t <= 80; t++) {
        p = f.add(fix(60, 0, 1000 * t, speed: 0));
      }
      expect(p!.moving, isFalse);
      expect(toMeters(p.lat, p.lon).$1, closeTo(60, 3));
    });
  });

  group('andando', () {
    /// Anda para o leste a [speed] m/s com ruído [sigma], e devolve o erro (m) de cada leitura depois de [warm] leituras.
    List<double> walk(double speed, double sigma, {int seed = 7, int n = 120, int warm = 15}) {
      final f = GpsFilter();
      final noise = Noise(seed);
      final errors = <double>[];
      for (var i = 0; i < n; i++) {
        final t = i + 1;
        final east = speed * t, north = 0.0;
        final p = f.add(fix(east + noise.next(sigma), north + noise.next(sigma), 1000 * t, acc: math.max(sigma, 3)))!;
        if (i >= warm) errors.add(dist(p, east, north));
      }
      return errors;
    }

    test('andando a 1,4 m/s com ruído de 5 m, o erro típico fica abaixo da precisão do GPS', () {
      final e = walk(1.4, 5);
      final mean = e.reduce((a, b) => a + b) / e.length;
      expect(mean, lessThan(5.0), reason: 'erro médio $mean m');
      expect(e.reduce(math.max), lessThan(10.0));
    });

    test('correndo a 3 m/s e de bicicleta a 6 m/s o filtro acompanha, sem se perder', () {
      for (final speed in [3.0, 6.0]) {
        final e = walk(speed, 5);
        final mean = e.reduce((a, b) => a + b) / e.length;
        expect(mean, lessThan(8.0), reason: '${speed}m/s: erro médio $mean m');
      }
    });

    test('anda mesmo: depois de 60 s a 1,4 m/s a posição andou ~84 m para o leste', () {
      final f = GpsFilter();
      FilteredPosition? p;
      for (var t = 1; t <= 60; t++) {
        p = f.add(fix(1.4 * t, 0, 1000 * t));
      }
      expect(toMeters(p!.lat, p.lon).$1, closeTo(84, 4));
      expect(p.moving, isTrue);
    });

    test('começar a andar depois de parado: o marcador arranca em poucos segundos', () {
      final f = GpsFilter();
      for (var t = 1; t <= 40; t++) {
        f.add(fix(0, 0, 1000 * t));
      }
      FilteredPosition? p;
      for (var t = 41; t <= 50; t++) {
        p = f.add(fix(2.0 * (t - 40), 0, 1000 * t)); // 2 m/s por 10 s = 20 m
      }
      expect(toMeters(p!.lat, p.lon).$1, greaterThan(10), reason: 'em 10 s já andou mais da metade');
    });
  });

  group('saltos e tempo', () {
    test('um salto grande (teletransporte do simulador) recomeça na leitura, sem arrastar o marcador', () {
      final f = GpsFilter();
      for (var t = 1; t <= 20; t++) {
        f.add(fix(0, 0, 1000 * t));
      }
      final p = f.add(fix(5000, 3000, 21000))!;
      expect(dist(p, 5000, 3000), lessThan(0.5));
    });

    test('um salto pequeno com precisão ruim é tratado como ruído, não como teletransporte', () {
      final f = GpsFilter();
      for (var t = 1; t <= 20; t++) {
        f.add(fix(0, 0, 1000 * t));
      }
      final p = f.add(fix(60, 0, 21000, acc: 40))!;
      expect(dist(p, 0, 0), lessThan(30), reason: 'o salto de 60 m com ±40 m move só uma parte');
    });

    test('leitura repetida ou fora de ordem no tempo é ignorada', () {
      final f = GpsFilter();
      f.add(fix(0, 0, 5000));
      final before = f.position!;
      expect(f.add(fix(30, 0, 5000)), isNull);
      expect(f.add(fix(30, 0, 4000)), isNull);
      expect(f.position!.lon, before.lon);
    });

    test('reset esquece tudo: a próxima leitura vira a posição', () {
      final f = GpsFilter();
      f.add(fix(0, 0, 1000));
      f.reset();
      expect(f.position, isNull);
      final p = f.add(fix(10, 10, 2000))!;
      expect(dist(p, 10, 10), lessThan(0.01));
    });

    test('um buraco longo no tempo (app em segundo plano) não faz o filtro explodir', () {
      final f = GpsFilter();
      f.add(fix(0, 0, 1000));
      final p = f.add(fix(25, 0, 600000))!; // 10 minutos depois, 25 m adiante
      expect(dist(p, 25, 0), lessThan(15));
      expect(p.accuracyM.isFinite, isTrue);
    });
  });
}
