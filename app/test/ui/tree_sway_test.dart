import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/city/city_renderer.dart';
import 'package:kenoma/ui/game/touch_fx.dart';
import 'package:kenoma/ui/lab/lab_art.dart';
import 'package:kenoma/world/city_scene.dart';
import 'package:kenoma/world/map_camera.dart';

/// 0.24.3: tocar a árvore balança a copa de verdade (o carimbo de pé), não só a folha que cai na frente.
void main() {
  test('o balanço começa e termina parado, vai para os dois lados e amortece', () {
    expect(treeSwayPx(0), 0);
    expect(treeSwayPx(kTreeSwayS), 0);
    final xs = [for (var t = 0.0; t < kTreeSwayS; t += 0.02) treeSwayPx(t).round()];
    expect(xs.reduce(math.max), greaterThanOrEqualTo(2));
    expect(xs.reduce(math.min), lessThanOrEqualTo(-1));
    expect(treeSwayPx(kTreeSwayS - 0.05).abs(), lessThan(0.5), reason: 'para sem tranco');
  });

  testWidgets('o topo da copa sai do lugar e o terço de baixo fica', (tester) async {
    final art = LabArt.build();
    addTearDown(art.dispose);
    const view = ui.Size(120, 160), mpc = 17.6, k = 3;
    final tile = CityTile(roads: const [], greens: const [], waters: const [], buildings: const [], props: [CityProp('tree', 10, 10, hash: 1)]);
    final c = CityRenderer(art: art, tileAt: (tx, ty) => tx == 0 && ty == 0 ? tile : CityTile.empty, biomeAt: (_, _) => 'urban', cellsPerTile: 64, budgetMs: 1000);
    final cam = MapCamera(centerX: 10, centerY: 10, pixelsPerCell: view.width / (30 / mpc));
    Future<ByteData> render(double Function(double, double)? sway) async {
      final rec = ui.PictureRecorder();
      c.paintUpright(ui.Canvas(rec), view, cam, dpr: 1, artPixelDp: k.toDouble(), mpc: mpc, sunAltDeg: 40, sunAzDeg: 80, localHour: 10, month: 3, snowRoofs: false, items: const [], sway: sway);
      final img = rec.endRecording().toImageSync(view.width.toInt(), view.height.toInt());
      return (await tester.runAsync(() => img.toByteData()))!;
    }

    final still = await render(null);
    final tree = c.upright.drawn.firstWhere((d) => d.name == 'tree').rect;
    final swayed = await render((x, y) => x == 10 && y == 10 ? 3 : 0);
    bool sameRow(int y) {
      for (var x = 0; x < view.width; x++) {
        final i = (y * view.width.toInt() + x) * 4;
        if (still.getUint32(i) != swayed.getUint32(i)) return false;
      }
      return true;
    }

    final top = (tree.top * k).round(), bottom = (tree.bottom * k).round(), trunk = (tree.top + tree.height * 2 / 3).ceil() * k;
    expect([for (var y = top; y < trunk; y++) y].any((y) => !sameRow(y)), isTrue, reason: 'a copa balança');
    expect([for (var y = trunk; y < bottom && y < view.height; y++) y].every(sameRow), isTrue, reason: 'a base da copa fica');
    expect((await render((_, _) => 0)).buffer.asUint8List(), still.buffer.asUint8List(), reason: 'sem balanço, o mesmo desenho');
  });
}
