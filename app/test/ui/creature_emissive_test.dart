import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/creature_anim.dart';
import 'package:kenoma/ui/game/creature_art.dart';
import 'package:kenoma/ui/game/draw_order.dart';
import 'package:kenoma/ui/game/spawn_painter.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/spawn_field.dart';

/// 0.25.0 (docs/GDD.md, Direção de arte; docs/art/estilo-criaturas.md): o corpo da criatura recebe o tom da noite e o que
/// brilha (ocelos, veios) vai numa camada emissiva desenhada depois do tom e do clima.
void main() {
  test('a camada emissiva vem depois do tom da noite (base), das criaturas e do clima da tela', () {
    final order = MapLayer.values;
    expect(order.indexOf(MapLayer.emissive), greaterThan(order.indexOf(MapLayer.climateScreen)));
    expect(order.indexOf(MapLayer.emissive), greaterThan(order.indexOf(MapLayer.creatures)));
    expect(order.indexOf(MapLayer.emissive), greaterThan(order.indexOf(MapLayer.base)), reason: 'o tom da noite é pintado na base');
    expect(order.indexOf(MapLayer.emissive), lessThan(order.indexOf(MapLayer.hud)));
  });

  testWidgets('de noite o corpo escurece e o LED continua aceso, por cima do tom da tela', (tester) async {
    // Uma criatura de teste: 4 × 4, corpo branco e um LED ciano no pixel (1, 1), todos os quadros iguais.
    ui.Image square(int argb, {bool ledOnly = false}) {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      for (var f = 0; f < 4; f++) {
        if (ledOnly) {
          c.drawRect(ui.Rect.fromLTWH(f * 4 + 1.0, 1, 1, 1), ui.Paint()..color = ui.Color(argb));
        } else {
          c.drawRect(ui.Rect.fromLTWH(f * 4.0, 0, 4, 4), ui.Paint()..color = ui.Color(argb));
        }
      }
      return rec.endRecording().toImageSync(16, 4);
    }

    final body = square(0xFFFFFFFF), leds = square(0xFF5FD3C6, ledOnly: true);
    final strip = CreatureStrip(body: body, leds: leds, glow: null, frames: 4, fps: 4, bodyDy: const [0, 0, 0, 0]);
    CreatureArt.registerForTest('test.eco', CreatureArt(frame: 4, anims: {for (final a in CreatureAnim.values) a: strip}, variants: const {}));
    addTearDown(() => CreatureArt.registerForTest('test.eco', null));

    const view = ui.Size(64, 64);
    final eco = WorldSpawn(uid: 3, kind: 'eco', entryId: 'test.eco', quantity: 1, x: 10.5, y: 10.5, cellX: 5, cellY: 5, window: 0, level: 1);
    final cam = MapCamera(centerX: 10.5, centerY: 10.5, pixelsPerCell: 20);
    const night = ui.Color(0xFF3F4A8C);
    // Um instante em que o LED de uid 3 está aceso.
    var t = 0.0;
    while (!ledLit(3, t)) {
      t += 0.05;
    }
    final emissive = <void Function()>[];
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    paintSpawns(canvas, view, cam, [eco], sprites: const {}, typeOf: (_) => null, inAura: (_) => false, time: t, avoid: ui.Rect.zero, spriteSize: 40, sparkSize: 8, bodyTone: night, emissive: emissive);
    // O tom da tela (como a camada do clima) por cima de tudo o que já foi desenhado...
    canvas.drawRect(ui.Offset.zero & view, ui.Paint()..color = const ui.Color(0x40000000));
    // ...e depois a camada emissiva.
    for (final l in emissive) {
      l();
    }
    final img = rec.endRecording().toImageSync(64, 64);
    final bytes = (await tester.runAsync(() => img.toByteData()))!;
    int at(int x, int y) => bytes.getUint32((y * 64 + x) * 4) >> 8; // RGB
    // A criatura de 40 px centrada em (32, 32): cada pixel dela tem 10 px. O LED é o pixel (1, 1): de 22 a 32.
    final ledRgb = at(27, 27), bodyRgb = at(45, 45);
    expect(emissive, isNotEmpty, reason: 'o LED foi para a camada emissiva');
    expect(ledRgb, 0x5FD3C6, reason: 'o LED sai na cor cheia, por cima do tom');
    expect(bodyRgb & 0xFF0000, lessThan(0x800000), reason: 'o corpo branco escureceu com o tom da noite');
  });
}
