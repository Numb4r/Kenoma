// As cenas de bioma do laboratório visual para o catálogo do workbench (0.21.0): uma cena pequena por bioma, desenhada
// pelo renderizador do laboratório (`lab_renderer.dart`), ao lado da imagem atual do bioma. Fica fora de `test/`.
// Uso: cd app && flutter test test_workbench/lab_biomes_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/lab/lab_art.dart';
import 'package:kenoma/ui/lab/lab_renderer.dart';
import 'package:kenoma/world/lab_block.dart';

import '../test/support/fixtures.dart';

const out = '../workbench/catalog/biomas';

List<Pt> rect(double x, double y, double w, double h) => [(x, y), (x + w, y), (x + w, y + h), (x, y + h)];

LabBuilding b(int i, List<Pt> pts, String type, {bool shop = false, double? levels}) => LabBuilding(pts: pts, type: type, heightM: 6, shop: shop, levels: levels, index: i);

void main() {
  test('cenas de bioma do laboratório', () async {
    final road = [(cls: 'local', pts: <Pt>[(-80, 30), (80, 30)]), (cls: 'secondary', pts: <Pt>[(-20, -80), (-20, 80)])];
    final scenes = <String, (String, LabBlock)>{
      'void': ('urban', LabBlock(sizeM: (160, 160), buildings: [b(0, rect(10, -30, 14, 10), 'construction')], roads: road, greens: const [], waters: const [], trees: const [], lots: [rect(-80, -80, 160, 160)])),
      'urban': ('urban', LabBlock(sizeM: (160, 160), buildings: [b(1, rect(0, -40, 30, 26), 'apartments', levels: 8), b(2, rect(36, -40, 22, 30), 'yes'), b(3, rect(0, 40, 50, 20), 'warehouse')], roads: road, greens: const [], waters: const [], trees: const [], lots: const [])),
      'green': ('green', LabBlock(sizeM: (160, 160), buildings: const [], roads: road, greens: [rect(-80, -80, 160, 160)], waters: const [], trees: const [], lots: const [])),
      'water': ('water', LabBlock(sizeM: (160, 160), buildings: const [], roads: [road.first], greens: [rect(-80, 40, 160, 40)], waters: [rect(-80, -80, 160, 105)], trees: const [], lots: const [])),
      'residential': ('residential', LabBlock(sizeM: (160, 160), buildings: [b(4, rect(-5, -45, 12, 10), 'house'), b(5, rect(15, -45, 11, 12), 'house'), b(6, rect(-5, -12, 10, 12), 'house'), b(7, rect(18, -14, 12, 10), 'house'), b(8, rect(-5, 42, 12, 10), 'house')], roads: road, greens: const [], waters: const [], trees: const [], lots: const [])),
      'lit': ('lit', LabBlock(sizeM: (160, 160), buildings: [b(9, rect(-4, -36, 22, 14), 'retail', shop: true), b(10, rect(22, -36, 18, 14), 'yes', shop: true), b(11, rect(-4, 40, 30, 14), 'commercial', shop: true)], roads: road, greens: const [], waters: const [], trees: const [], lots: const [])),
      'sacred': ('sacred', LabBlock(sizeM: (160, 160), buildings: [b(12, rect(0, -40, 18, 34), 'church')], roads: road, greens: [rect(30, -50, 40, 40)], waters: const [], trees: const [], lots: const [])),
    };
    final art = LabArt.build();
    Directory(out).createSync(recursive: true);
    const w = 140, h = 140, scale = 3;
    for (final (night, tag) in [(false, 'lab'), (true, 'lab_noite')]) {
      for (final e in scenes.entries) {
        final r = LabRenderer(e.value.$2, art, loadBiomes());
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec)..scale(scale.toDouble());
        final small = ui.PictureRecorder();
        r.paint(ui.Canvas(small), const ui.Size(w + 0.0, h + 0.0), LabView(cx: 10, cy: 0, rotation: 0, pxPerM: 1.1, sunAltDeg: night ? -25 : 35, sunAzDeg: 70, localHour: night ? 22 : 9), after: true, baseGround: e.value.$1);
        final img = small.endRecording().toImageSync(w, h);
        c.drawImage(img, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.none);
        final big = await rec.endRecording().toImage(w * scale, h * scale);
        final bytes = await big.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${e.key}_$tag.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    }
  });
}
