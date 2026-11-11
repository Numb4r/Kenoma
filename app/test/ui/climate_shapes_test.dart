import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/game/climate_cover.dart';
import 'package:kenoma/ui/game/climate_ground.dart';
import 'package:kenoma/ui/game/climate_puddle.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/visual_map.dart';

import '../support/fixtures.dart';

Set<(int, int)> _cells(List<PuddleRow> rows) => {
      for (final (y, x0, x1) in rows)
        for (var x = x0; x <= x1; x++) (x, y),
    };

/// Quanto duas formas diferem: células que só uma tem, sobre as que alguma tem (0 iguais, 1 sem nada em comum).
double _diff(List<PuddleRow> a, List<PuddleRow> b) {
  final ca = _cells(a), cb = _cells(b);
  return 1 - ca.intersection(cb).length / ca.union(cb).length;
}

void main() {
  group('formas das marcas no chão (blobRows)', () {
    test('seis famílias de contorno, todas diferentes entre si de forma perceptível', () {
      expect(blobFamilies, greaterThanOrEqualTo(6));
      final shapes = [for (var f = 0; f < blobFamilies; f++) blobRows(0x1234567890AB, 12, family: f)];
      for (var i = 0; i < shapes.length; i++) {
        expect(shapes[i], isNotEmpty);
        for (var j = i + 1; j < shapes.length; j++) {
          expect(_diff(shapes[i], shapes[j]), greaterThan(0.2), reason: 'famílias $i e $j');
        }
      }
    });

    test('o mesmo hash dá a mesma forma; marcas vizinhas nunca saem iguais', () {
      // Os hashes de marcas vizinhas (uid e índice seguidos), como o desenho usa.
      final hs = [for (var i = 0; i < 60; i++) fnv1a64Of3(77, i, 0xF0D)];
      expect(blobRows(hs[0], 10), blobRows(hs[0], 10));
      for (var i = 0; i + 1 < hs.length; i++) {
        expect(_diff(blobRows(hs[i], 10), blobRows(hs[i + 1], 10)), greaterThan(0.12), reason: 'marcas $i e ${i + 1}');
      }
      expect({for (final h in hs) blobFamilyOf(h)}.length, blobFamilies, reason: 'todas as famílias aparecem');
      final sizes = [for (final h in hs) blobScaleOf(h)];
      expect(sizes.reduce(math.max) / sizes.reduce(math.min), greaterThan(1.4), reason: 'tamanhos variados');
      // A rotação varia: a direção do eixo comprido da família comprida muda de marca para marca.
      final wide = [for (final h in hs.take(12)) () { final c = _cells(blobRows(h, 10, family: 1)); final xs = c.map((p) => p.$1), ys = c.map((p) => p.$2); return (xs.reduce(math.max) - xs.reduce(math.min)) > (ys.reduce(math.max) - ys.reduce(math.min)); }()];
      expect(wide.toSet(), {true, false});
    });

    test('mesmo pequena (brasa, pingo de vela), a marca tem pelo menos 6 formas', () {
      final small = {for (var i = 0; i < 80; i++) blobRows(fnv1a64Of3(5, i, 1), 2).toString()};
      expect(small.length, greaterThanOrEqualTo(6));
    });

    test('nenhuma marca do chão é círculo ou oval liso no código', () {
      final src = File('lib/ui/game/climate_ground.dart').readAsStringSync();
      final marks = src.substring(src.indexOf('void _mark('));
      expect(marks.contains('drawOval') || marks.contains('drawCircle'), isFalse);
      final zone = src.substring(src.indexOf("default: // zone"), src.indexOf('void _blob('));
      expect(zone.contains('drawCircle'), isFalse);
    });
  });

  group('cobertura das ruas sem cortes retos', () {
    test('a duna afina nas pontas e cada uma tem o seu contorno', () {
      final pts = [const ui.Offset(0, 0), const ui.Offset(40, 0)];
      double width(({List<ui.Offset> mid, List<ui.Offset> left, List<ui.Offset> right}) s, int i) => (s.left[i] - s.right[i]).distance;
      final shapes = [for (var k = 0; k < 6; k++) duneOutline(pts, 6, 1, fnv1a64Of3(9, k, 2), step: 1)];
      for (final s in shapes) {
        final n = s.mid.length;
        expect(width(s, 0), lessThan(0.5), reason: 'ponta fina, sem corte reto');
        expect(width(s, n - 1), lessThan(1.5));
        expect([for (var i = 0; i < n; i++) width(s, i)].reduce(math.max), greaterThan(4));
      }
      final sigs = {for (final s in shapes) [for (var i = 0; i < s.mid.length; i += 4) width(s, i).toStringAsFixed(1)].join(',')};
      expect(sigs.length, 6);
    });

    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 32);
    final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
    final mpc = metersPerCell(-22.8174);
    const cx = 12092 * 64.0 + 32, cy = 18513 * 64.0 + 32;

    Future<Uint8List> render(String climate, double rotation, {String? out}) async {
      const view = ui.Size(360, 480);
      final g = ClimateGround(catalog: catalog, visual: visual);
      final cam0 = MapCamera(centerX: cx, centerY: cy, pixelsPerCell: double.tryParse(Platform.environment['KENOMA_PPC'] ?? '') ?? 14, rotation: rotation);
      // Os blocos do campo ficam prontos um por quadro e a imagem chega depois: desenha até todos estarem na tela.
      ClimateCover.buildInline = true;
      for (var k = 0, last = -1; k < 400; k++) {
        final warm = ui.PictureRecorder();
        g.paint(ui.Canvas(warm), view, cam0, mpc: mpc, exactUtc: 1900007200, seed: 7, shown: catalog.of(climate), c: PlayerClimate(id: climate, runStartUtc: 1900000000));
        warm.endRecording().dispose();
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final cover = g.cover!;
        if (k > 3 && cover.fieldBuilds == last && cover.fieldDrawn >= cover.fieldBuilds) break;
        last = cover.fieldBuilds;
      }
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec)..drawRect(ui.Offset.zero & view, ui.Paint()..color = const ui.Color(0xFF272A37));
      g.paint(canvas, view, MapCamera(centerX: cx, centerY: cy, pixelsPerCell: double.tryParse(Platform.environment['KENOMA_PPC'] ?? '') ?? 14, rotation: rotation), mpc: mpc, exactUtc: 1900007200, seed: 7, shown: catalog.of(climate), c: PlayerClimate(id: climate, runStartUtc: 1900000000));
      final img = rec.endRecording().toImageSync(360, 480);
      if (out != null) File(out).writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      return (await img.toByteData())!.buffer.asUint8List();
    }

    test('os blocos do campo ficam prontos fora da thread do desenho (isolate) e chegam à tela', () async {
      const view = ui.Size(360, 480);
      final g = ClimateGround(catalog: catalog, visual: visual);
      final cam = MapCamera(centerX: cx, centerY: cy, pixelsPerCell: 100);
      ClimateCover.buildInline = false;
      for (var k = 0; k < 600 && g.cover!.fieldDrawn < 6; k++) {
        final rec = ui.PictureRecorder();
        g.paint(ui.Canvas(rec), view, cam, mpc: mpc, exactUtc: 1900007200, seed: 7, shown: catalog.of('snow'), c: const PlayerClimate(id: 'snow', runStartUtc: 1900000000));
        rec.endRecording().dispose();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(g.cover!.fieldBuilds, greaterThanOrEqualTo(6));
      expect(g.cover!.fieldDrawn, greaterThanOrEqualTo(6));
      // ignore: avoid_print
      print('bloco pelo isolate: ${g.cover!.fieldLastMs.toStringAsFixed(1)} ms');
    });

    test('neve, gelo, fuligem, Dilúvio e areia desenham sobre as ruas do Centro, em qualquer rotação', () async {
      final dir = Platform.environment['KENOMA_SHOTS'];
      for (final id in ['snow', 'freezing_rain', 'smog', 'deluge', 'sandstorm']) {
        final plain = await render(id, 0, out: dir == null ? null : '$dir/cover_$id.png');
        final turned = await render(id, 0.6);
        int painted(Uint8List px) {
          var n = 0;
          for (var i = 0; i < px.length; i += 4) {
            if (px[i] != 0x27 || px[i + 1] != 0x2A || px[i + 2] != 0x37) n++;
          }
          return n;
        }

        expect(painted(plain), greaterThan(2000), reason: id);
        expect(painted(turned), greaterThan(2000), reason: id);
      }
    });
  });
}
