import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/game/art_renderer.dart';
import 'package:kenoma/ui/game/art_style.dart';
import 'package:kenoma/world/map_balance.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/visual_map.dart';

import '../data/visual_pack_test.dart' show syntheticPack;
import '../support/fixtures.dart';

const size = ui.Size(200, 200);
const dpr = 2.0;
const lat = -22.9;

void main() {
  final balance = MapBalance(loadJson('assets/data/balance.json'));
  final style = ArtStyle(loadBiomes());
  final mpc = metersPerCell(lat);
  final k = (balance.artPixelDp * dpr).round(); // pixels físicos por pixel de arte
  // O tile (5, 7) do pacote sintético: rua principal pela borda de cima (y = 0) e o lago em 100..900 (com uma
  // ilha). 1 unidade = 1/4096 tile = ~0,25 m.
  ArtRenderer make() => ArtRenderer(visual: VisualMap(VisualPack.parse(syntheticPack())), style: style, balance: balance);

  /// Pixels físicos da tela inteira (200 x 200 lógicos a 2x = 400 x 400).
  Future<List<int>> render(ArtRenderer r, MapCamera cam, {int coarse = 1}) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec)..scale(dpr, dpr); // como o Flame: o canvas já vem na escala do aparelho
    r.paint(canvas, size, cam, dpr: dpr, metersPerCell: mpc, coarse: coarse);
    final image = rec.endRecording().toImageSync(400, 400);
    return (await image.toByteData())!.buffer.asUint8List();
  }

  int colorAt(List<int> px, int x, int y) {
    final i = (y * 400 + x) * 4;
    return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
  }

  int rgb(ui.Color c) => c.toARGB32() & 0xFFFFFF;
  Set<int> tones(Material3 m) => {rgb(m.dark), rgb(m.base), rgb(m.light)};

  MapCamera over(double ux, double uy, {double widthM = 90, double rotation = 0}) =>
      MapCamera(centerX: (5 + ux / 4096) * 64, centerY: (7 + uy / 4096) * 64, pixelsPerCell: size.width * mpc / widthM, rotation: rotation);

  test('o pixel de arte tem tamanho fixo de tela: 3 dp, em pixels físicos inteiros, em qualquer zoom', () {
    final r = make();
    expect(r.pixelSize(dpr), k);
    expect(r.pixelSize(2.625), 8, reason: 'moto g54: 3 dp x 2,625 = 7,9 -> 8 pixels físicos');
    expect(r.pixelSize(dpr, coarse: 2), 2 * k);
    for (final w in [60.0, 90.0, 150.0]) {
      r.paint(ui.Canvas(ui.PictureRecorder()), size, over(2048, 2048, widthM: w), dpr: dpr, metersPerCell: mpc);
      expect(r.lastPixelSize, k, reason: 'largura $w m');
      expect(r.lastBuffer, (400 ~/ k + (400 % k == 0 ? 0 : 1), 400 ~/ k + (400 % k == 0 ? 0 : 1)));
    }
    r.dispose();
  });

  testWidgets('cada pixel de arte ocupa um bloco de k x k pixels físicos: a ampliação é inteira', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      final px = await render(r, over(2048, 2048, rotation: 0.6));
      for (var by = 0; by < 400 ~/ k; by += 7) {
        for (var bx = 0; bx < 400 ~/ k; bx += 5) {
          final c0 = colorAt(px, bx * k, by * k);
          for (var dy = 0; dy < k; dy++) {
            for (var dx = 0; dx < k; dx++) {
              expect(colorAt(px, bx * k + dx, by * k + dy), c0, reason: 'bloco ($bx, $by)');
            }
          }
        }
      }
      r.dispose();
    });
  });

  testWidgets('a água cobre o lago, em qualquer rotação', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      for (final rot in [0.0, 0.7, math.pi / 2, 2.4, -1.2]) {
        final px = await render(r, over(250, 250, rotation: rot));
        expect(tones(style.water).contains(colorAt(px, 200, 200)), isTrue, reason: 'rotação $rot');
      }
      r.dispose();
    });
  });

  testWidgets('o desenho é o mesmo de uma vez para outra', (tester) async {
    await tester.runAsync(() async {
      final a = await render(make(), over(250, 250, rotation: 0.4));
      final b = await render(make(), over(250, 250, rotation: 0.4));
      expect(a, b);
    });
  });

  testWidgets('a rua tem asfalto no meio, calçada de 1 pixel de arte de cada lado e chão fora', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      final px = await render(r, over(2048, 0));
      final asphalt = rgb(style.asphalt), sidewalk = rgb(style.sidewalk);
      expect(colorAt(px, 200, 200), asphalt);
      // Rua principal de 12 m: com 90 m em 400 px físicos, 1 m = 4,44 px.
      final half = 12 / 2 * 400 / 90;
      expect(colorAt(px, 200, 200 + (half - 6).round()), asphalt, reason: 'ainda no asfalto');
      expect(colorAt(px, 200, 200 + (half + k / 2).round()), sidewalk, reason: 'na calçada');
      expect(tones(style.ground).contains(colorAt(px, 200, 200 + (half + 2 * k + 8).round())), isTrue, reason: 'depois da calçada é chão');
      r.dispose();
    });
  });

  testWidgets('girando o mapa 90° a rua deixa de ser horizontal: vira vertical, com o mesmo traço', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      final flat = await render(r, over(2048, 0));
      final turned = await render(r, over(2048, 0, rotation: math.pi / 2));
      final asphalt = rgb(style.asphalt);
      expect(colorAt(flat, 200, 200), asphalt);
      expect(colorAt(flat, 60, 200), asphalt, reason: 'sem rotação a rua corre na horizontal');
      expect(colorAt(turned, 200, 200), asphalt);
      expect(colorAt(turned, 200, 60), asphalt, reason: 'girada 90°, a rua corre na vertical');
      expect(colorAt(turned, 60, 200), isNot(asphalt), reason: 'e saiu da horizontal');
      r.dispose();
    });
  });

  testWidgets('a nitidez é a mesma em qualquer zoom: o buffer e o pixel de arte não mudam', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      final sizes = <int>{};
      final buffers = <(int, int)>{};
      for (final w in [60.0, 100.0, 150.0]) {
        await render(r, over(250, 250, widthM: w, rotation: 0.3));
        sizes.add(r.lastPixelSize);
        buffers.add(r.lastBuffer);
      }
      expect(sizes.length, 1);
      expect(buffers.length, 1);
      r.dispose();
    });
  });

  testWidgets('a resolução cai pela metade com coarse 2 (recurso para segurar o fps no gesto) e o mundo continua no lugar', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      final sharp = await render(r, over(250, 250));
      final sharpBuffer = r.lastBuffer;
      final coarse = await render(r, over(250, 250), coarse: 2);
      expect(r.lastPixelSize, 2 * k);
      expect(r.lastBuffer.$1, lessThan(sharpBuffer.$1));
      expect(tones(style.water).contains(colorAt(sharp, 200, 200)), isTrue);
      expect(tones(style.water).contains(colorAt(coarse, 200, 200)), isTrue);
      r.dispose();
    });
  });

  testWidgets('os caminhos de um tile são montados uma vez e voltam do cache', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      await render(r, over(2048, 2048));
      final cached = r.cachedTiles;
      expect(cached, greaterThan(0));
      await render(r, over(2048, 2048, rotation: 1.0));
      expect(r.cachedTiles, cached);
      r.dispose();
    });
  });
}
