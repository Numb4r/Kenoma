import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart' show DayLight;
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/colors.dart';
import 'package:kenoma/ui/game/ghost_sprites.dart';
import 'package:kenoma/ui/game/traffic_painter.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/veil_traffic.dart';
import 'package:kenoma/world/visual_map.dart';

void main() {
  final bytes = File('assets/regions/campinas_e0_vis.bin').readAsBytesSync();
  TrafficPainter make() => TrafficPainter(VisualMap(VisualPack.parse(Uint8List.fromList(bytes)), cacheTiles: 16), carM: 6, pedestrianM: 4.5);

  test('as matrizes são retangulares e só usam papéis com cor, sem preto puro', () {
    for (final m in GhostModel.values) {
      for (var f = 0; f < framesOf(m); f++) {
        final rows = spriteRows(m, f);
        final w = rows.first.length;
        for (final r in rows) {
          expect(r.length, w, reason: '${m.name} quadro $f');
        }
        for (var p = 0; p < m.paletteCount; p++) {
          final colors = paletteOf(m, p);
          for (final r in rows) {
            for (final c in r.split('')) {
              if (c == '.') continue;
              expect(colors.containsKey(c), isTrue, reason: '${m.name} usa "$c" sem cor');
              expect(colors[c], isNot(const ui.Color(0xFF000000)));
            }
          }
          expect(colors['o'], kOutline);
        }
      }
    }
  });

  test('os modelos de pé têm dois quadros diferentes; há 4 carros e 4 passantes, de 4 a 6 paletas', () {
    for (final m in GhostModel.values.where(isUpright)) {
      expect(spriteRows(m, 0), isNot(spriteRows(m, 1)));
    }
    expect(GhostModel.values.where((m) => m.kind == GhostKind.car).length, 4);
    expect(GhostModel.values.where((m) => m.kind == GhostKind.pedestrian).length, 4);
    for (final m in GhostModel.values) {
      expect(m.paletteCount, inInclusiveRange(4, 6));
    }
  });

  test('passante com roupa pelo clima: cada grupo veste o que deve, varia por passante e é igual em dois aparelhos', () {
    final ids = [for (var i = 0; i < 400; i++) 0x9e3779b97f4a7c15 * (i + 1) & 0x7fffffffffffffff];
    const expected = {
      'rain': {GhostOutfit.umbrella, GhostOutfit.raincoat},
      'cold': {GhostOutfit.coat, GhostOutfit.beanie, GhostOutfit.scarf},
      'heat': {GhostOutfit.light, GhostOutfit.cap, GhostOutfit.hat},
      'mask': {GhostOutfit.mask},
    };
    for (final MapEntry(key: group, value: want) in expected.entries) {
      final worn = [for (final id in ids) ghostOutfit(group, id)];
      expect(worn, [for (final id in ids) ghostOutfit(group, id)], reason: 'a mesma escolha de novo');
      expect(worn.toSet().containsAll(want), isTrue, reason: '$group: ${worn.toSet()}');
      expect(worn.toSet().difference({...want, GhostOutfit.none}), isEmpty, reason: group);
      expect(worn.where(want.contains).length, greaterThan(ids.length * 0.7), reason: '$group: quase todos vestem');
    }
    expect(ids.map((id) => ghostOutfit(null, id)).toSet(), {GhostOutfit.none}, reason: 'céu limpo: roupa de sempre');
    expect(ghostOutfit('rain', ids.first), ghostOutfit('rain', ids.first));
    // O clima do `clima.json` liga ao grupo: a chuva veste guarda-chuva, o frio casaco, o sol boné, a fumaça máscara.
    final climas = jsonDecode(File('assets/data/clima.json').readAsStringSync())['climates'] as Map<String, dynamic>;
    for (final (id, group) in [('drizzle', 'rain'), ('storm', 'rain'), ('snow', 'cold'), ('freezing_rain', 'cold'), ('heat_wave', 'heat'), ('smog', 'mask'), ('acid_rain', 'mask')]) {
      expect((climas[id] as Map<String, dynamic>)['outfit'], group, reason: id);
    }
    // As matrizes com roupa continuam retangulares, com cor em cada papel, e o guarda-chuva fica por cima da cabeça.
    for (final m in GhostModel.values.where(isUpright)) {
      for (final o in GhostOutfit.values) {
        for (var f = 0; f < 2; f++) {
          final rows = spriteRows(m, f, o);
          final colors = paletteOf(m, 1, o);
          for (final r in rows) {
            expect(r.length, rows.first.length, reason: '${m.name} ${o.name}');
            for (final c in r.split('')) {
              if (c != '.') expect(colors.containsKey(c), isTrue, reason: '${m.name} ${o.name} usa "$c" sem cor');
            }
          }
          if (o == GhostOutfit.umbrella) expect(rows.length, spriteRows(m, f).length + 5);
        }
      }
    }
    expect(paletteOf(GhostModel.adult, 0, GhostOutfit.coat)['t'], isNot(paletteOf(GhostModel.adult, 0)['t']), reason: 'o casaco troca a blusa');
  });

  test('todos os modelos, paletas, quadros e fases desenham sem erro', () {
    final painter = make();
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    var n = 0;
    for (final m in GhostModel.values) {
      for (var p = 0; p < m.paletteCount; p++) {
        for (final phase in GhostPhase.values) {
          for (final travelled in [0.0, 0.7]) {
            final g = Ghost(id: n, model: m, palette: p, x: 0, y: 0, heading: 0.4 * n, speedMps: 3, phase: phase, phaseT: 0.5, travelledM: travelled);
            painter.drawGhost(canvas, g, 100.0 + n % 7, 200, 0.3, 8, n.isEven ? 0.0 : 1.0, outfit: const [null, "rain", "cold", "heat", "mask"][n % 5]);
            n++;
          }
        }
      }
    }
    final pic = rec.endRecording();
    expect(n, greaterThan(100));
    pic.dispose();
  });

  test('paint desenha fantasmas de Campinas no rush, dentro do teto, e nenhum com o pacote sem tráfego', () {
    final painter = make();
    final cam = MapCamera(centerX: 12092 * 64.0 + 32, centerY: 18513 * 64.0 + 32, pixelsPerCell: 360 * 17.6 / 50);
    const light = DayLight(night: 0, warm: 0);
    var best = 0;
    for (var k = 0; k < 40; k++) {
      final rec = ui.PictureRecorder();
      painter.paint(ui.Canvas(rec), const ui.Size(360, 780), cam, seed: 0x6ebe19ac6345175f, tUtc: 1790035200 + 21 * 3600 + k, lonDeg: -47.06, metersPerCell: 17.6, light: light);
      rec.endRecording().dispose();
      if (painter.lastDrawn > best) best = painter.lastDrawn;
    }
    expect(best, greaterThan(0));
    expect(best, lessThanOrEqualTo(160));
  });
}
