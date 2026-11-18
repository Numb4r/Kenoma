import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/spawn_painter.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/spawn_field.dart';

/// 0.25.0: os efeitos ancorados numa criatura (anel da sintonia, o desfazer da fuga) se centram no ponto de ancoragem do
/// sprite, como ele foi desenhado, e não no canto nem na posição crua.
void main() {
  test('o retângulo do efeito fica centrado na âncora, em pixels inteiros, de qualquer tamanho', () {
    for (final (x, y) in [(100.0, 100.0), (101.0, 57.0), (33.0, 210.0)]) {
      for (final size in [19.0, 28.0, 38.0, 57.0]) {
        final r = anchoredRect(ui.Offset(x, y), size);
        expect((r.center.dx - x).abs(), lessThanOrEqualTo(0.5), reason: 'x em $size');
        expect((r.center.dy - y).abs(), lessThanOrEqualTo(0.5), reason: 'y em $size');
        expect((r.left, r.top), (r.left.roundToDouble(), r.top.roundToDouble()));
      }
    }
  });

  test('o pintor dos spawns guarda o centro em que desenhou cada Eco', () {
    const view = ui.Size(200, 200);
    final eco = WorldSpawn(uid: 7, kind: 'eco', entryId: 'soot.eco', quantity: 1, x: 10.75, y: 10.25, cellX: 5, cellY: 5, window: 0, level: 1);
    final cam = MapCamera(centerX: 10.5, centerY: 10.5, pixelsPerCell: 40);
    final anchors = <int, ui.Offset>{};
    paintSpawns(ui.Canvas(ui.PictureRecorder()), view, cam, [eco], sprites: const {}, typeOf: (_) => null, inAura: (_) => true, time: 0, avoid: ui.Rect.zero, spriteSize: 40, sparkSize: 12, anchors: anchors);
    final (sx, sy) = cam.cellToScreen(eco.x, eco.y, view.width, view.height);
    expect(anchors[7], ui.Offset(sx.roundToDouble(), sy.roundToDouble()));
  });
}
