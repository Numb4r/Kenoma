import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/ui/game/climate_painter.dart';

import '../support/fixtures.dart';

void main() {
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));

  test('a chuva sobe devagar com o clima, a tempestade pesa mais e sem clima as gotas somem', () {
    final p = ClimatePainter();
    const size = ui.Size(411, 914);
    for (var i = 0; i < 300; i++) {
      p.update(1 / 30, size, catalog.of('rain'));
    }
    final light = p.count;
    expect(light, inInclusiveRange(95, 116));
    for (var i = 0; i < 300; i++) {
      p.update(1 / 30, size, catalog.of('storm'));
    }
    expect(p.count, greaterThan(light));
    expect(p.count, lessThanOrEqualTo(catalog.of('storm').maxParticles + 6));
    p.update(1 / 30, size, catalog.of('clear'));
    expect(p.count, greaterThan(0), reason: 'não corta de uma vez');
    for (var i = 0; i < 600; i++) {
      p.update(1 / 30, size, catalog.of('clear'));
    }
    expect(p.count, 0);
  });

  test('o teto do aparelho e o modo bolso limitam as partículas', () {
    final p = ClimatePainter(cap: 100, pocketRate: 0.2);
    const size = ui.Size(411, 914);
    for (var i = 0; i < 400; i++) {
      p.update(1 / 30, size, catalog.of('deluge'));
    }
    expect(p.count, lessThanOrEqualTo(106));
    p.setPocket(true);
    for (var i = 0; i < 400; i++) {
      p.update(1 / 30, size, catalog.of('deluge'));
    }
    expect(p.count, lessThanOrEqualTo(catalog.of('deluge').maxParticles * 0.2 + 6));
    final n = p.count;
    expect(n, greaterThan(0));
  });

  test('o interruptor dos Ajustes apaga o clima mesmo com chuva', () {
    final p = ClimatePainter();
    for (var i = 0; i < 300; i++) {
      p.update(1 / 30, const ui.Size(411, 914), catalog.of('rain'));
    }
    for (var i = 0; i < 600; i++) {
      p.update(1 / 30, const ui.Size(411, 914), catalog.of('rain'), enabled: false);
    }
    expect(p.count, 0);
  });

  // A faixa sem chuva (0.15.x): a gota anda de lado enquanto cai e nascia só até largura + 60, então o canto de baixo do
  // lado para onde ela anda ficava seco. As partículas são da tela, não do mapa: girar o mapa só muda a direção do vento
  // (testada aqui em vários ângulos) e o zoom não muda nada.
  group('as partículas cobrem a tela inteira, do topo aos cantos de baixo', () {
    const sizes = [ui.Size(411, 914), ui.Size(914, 411), ui.Size(360, 360), ui.Size(320, 1200)];
    void covers(String id, {double windDeg = 0}) {
      for (final size in sizes) {
        final p = ClimatePainter()..wind = ui.Offset(math.cos(windDeg * math.pi / 180), math.sin(windDeg * math.pi / 180));
        const cols = 6, rows = 10;
        final hit = <int>{};
        for (var i = 0; i < 1500; i++) {
          p.update(1 / 30, size, catalog.of(id));
          if (i < 120) continue; // depois de a chuva subir
          for (final q in p.positions) {
            if (q.dx < 0 || q.dy < 0 || q.dx >= size.width || q.dy >= size.height) continue;
            hit.add((q.dy / size.height * rows).floor() * cols + (q.dx / size.width * cols).floor());
          }
        }
        expect(hit.length, cols * rows, reason: '$id com vento a $windDeg° deixou parte de $size sem nada');
      }
    }

    for (final id in ['drizzle', 'rain', 'storm', 'hail', 'deluge', 'snow', 'inverted_sky', 'prismatic_drizzle']) {
      test(id, () => covers(id));
    }
    for (final deg in [0.0, 60.0, 135.0, 180.0, 250.0, 315.0]) {
      test('nevasca com o mapa girado ($deg°)', () => covers('blizzard', windDeg: deg));
    }
  });
}
