import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/craft/ui_art.dart';
import 'package:kenoma/ui/game/touch_fx.dart';
import 'package:kenoma/world/map_camera.dart';

/// 0.24.2: as reações ao toque (pena, folha, onda, clarão, coração) saem das tiras do `criativo` e ficam presas ao mapa.
void main() {
  testWidgets('a reação desenha o quadro da tira no ponto tocado e some depois da vida dela', (tester) async {
    await tester.runAsync(() => UiArt.load());
    for (final strip in ['fx_cat_heart', 'fx_feather', 'fx_leaf', 'fx_ripple', 'fx_lamp_flicker', 'fx_ipe_petal']) {
      expect(UiArt.instance!.image(strip), isNotNull, reason: strip);
    }
    final cam = MapCamera(centerX: 100, centerY: 100, pixelsPerCell: 20);
    const view = ui.Size(200, 200);
    final layer = TouchFxLayer()..add(TouchFx('fx_cat_heart', 100, 100, 0, life: 0.9));
    Future<int> inkAt(double t) async {
      final rec = ui.PictureRecorder();
      layer.paint(ui.Canvas(rec), view, cam, t, 3);
      final img = await tester.runAsync(() => rec.endRecording().toImage(200, 200));
      final bytes = (await tester.runAsync(() => img!.toByteData()))!;
      var n = 0;
      for (var i = 3; i < bytes.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) > 0) n++;
      }
      return n;
    }

    expect(await inkAt(0.1), greaterThan(0), reason: 'o coração aparece em cima do gato');
    expect(await inkAt(2), 0, reason: 'depois da vida, some');
  });
}
