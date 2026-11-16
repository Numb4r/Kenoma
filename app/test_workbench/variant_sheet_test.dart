// A folha de contato das variantes (0.21.0, seção 3): toda forma de criatura em cada variante, no tamanho do mapa, em cor
// e em escala de cinza, desenhada pelas funções do jogo (`EcoSprite.loadMap`, `loadMapVariant`, `loadMapGlow`). Fica fora
// de `test/`: não roda na suíte.
// Uso: cd app && flutter test test_workbench/variant_sheet_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/bestiary_view.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';

import '../test/support/fixtures.dart';

const out = '../workbench/catalog';
const variants = ['urban', 'green', 'water', 'residential', 'lit', 'sacred', 'crimson', 'shiny'];
const scale = 3; // o pixel de arte do mapa em 3 px: o tamanho em que se lê na tela

void main() {
  test('folha de contato das variantes', () async {
    final data = loadGameData();
    final forms = [for (final f in bestiaryForms(data)) if (!f.isSpark) f];
    const cell = 26 * scale, label = 0;
    final w = cell * (variants.length + 1), h = cell * forms.length + label;
    for (final gray in [false, true]) {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFF3A4150)); // o chão cinza do mapa
      for (final (r, f) in forms.indexed) {
        for (final (k, v) in [null, ...variants].indexed) {
          final img = v == null ? (await EcoSprite.loadMap(f.spriteKey)).normal : EcoSprite.loadMapVariant(f.spriteKey, v);
          final glow = v == null ? null : EcoSprite.loadMapGlow(f.spriteKey, v);
          final side = img.width * scale.toDouble();
          final dst = ui.Rect.fromLTWH(k * cell + (cell - side) / 2, r * cell + (cell - side) / 2, side, side);
          final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
          if (v == 'shiny') {
            c.drawCircle(dst.center, side * 0.85, ui.Paint()..shader = ui.Gradient.radial(dst.center, side * 0.85, [const ui.Color(0x73FFE9A8), const ui.Color(0x00FFE9A8)]));
          }
          if (glow != null) c.drawImageRect(glow, ui.Rect.fromLTWH(0, 0, glow.width + 0.0, glow.height + 0.0), dst, paint);
          c.drawImageRect(img, ui.Rect.fromLTWH(0, 0, img.width + 0.0, img.height + 0.0), dst, paint);
        }
      }
      var image = await rec.endRecording().toImage(w, h);
      if (gray) {
        final rec2 = ui.PictureRecorder();
        ui.Canvas(rec2).drawImage(image, ui.Offset.zero, ui.Paint()..colorFilter = const ui.ColorFilter.matrix([0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, 0, 0, 0, 1, 0]));
        image = await rec2.endRecording().toImage(w, h);
      }
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/variantes_${gray ? 'cinza' : 'cor'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    File('$out/variantes_linhas.txt').writeAsStringSync(['colunas: comum, ${variants.join(', ')}', for (final f in forms) f.id].join('\n'));
  });
}
