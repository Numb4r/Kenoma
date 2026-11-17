import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/player_painter.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart' show mapPlayerPx;

/// 0.24.0: o equipamento do Conjurador no mapa (bolsa, garrafas do cinto, brilho do amuleto) entra no teste de giro como
/// sprite de pé. Ele é desenhado no espaço da tela, junto com o Conjurador: não recebe o giro do mapa, tem o tamanho do
/// quadro dele, espelha junto quando ele vira e cada garrafa a mais vai 2 pixels de arte para o lado.
void main() {
  Future<ui.Image> png(WidgetTester tester, String name) async => (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(File('assets/art/ui/$name.png').readAsBytesSync());
        return (await codec.getNextFrame()).image;
      }))!;

  Future<List<int>> paint(WidgetTester tester, List<(ui.Image, int)> layers, {bool mirrored = false}) async {
    final rec = ui.PictureRecorder();
    paintPlayerGear(ui.Canvas(rec), const ui.Offset(48, 48), layers: layers, size: 48, mirrored: mirrored);
    final img = await tester.runAsync(() => rec.endRecording().toImage(96, 96));
    final bytes = await tester.runAsync(() => img!.toByteData());
    return bytes!.buffer.asUint8List().toList();
  }

  int alphaAt(List<int> rgba, int x, int y) => rgba[(y * 96 + x) * 4 + 3];

  testWidgets('o equipamento tem o tamanho do quadro do Conjurador e fica de pé', (tester) async {
    for (final n in ['gear_bag', 'gear_bottle', 'gear_amulet_glow']) {
      final img = await png(tester, n);
      expect((img.width, img.height), (mapPlayerPx, mapPlayerPx), reason: n);
    }
    final bottle = await png(tester, 'gear_bottle');
    final one = await paint(tester, [(bottle, 0)]);
    final two = await paint(tester, [(bottle, 0), (bottle, 2)]);
    // A garrafa ocupa a coluna 6 do quadro (3 dp por pixel de arte, o quadro começa em 24): a segunda, a coluna 8.
    expect(alphaAt(one, 24 + 6 * 3 + 1, 24 + 12 * 3 + 1), greaterThan(0));
    expect(alphaAt(one, 24 + 8 * 3 + 1, 24 + 12 * 3 + 1), 0);
    expect(alphaAt(two, 24 + 8 * 3 + 1, 24 + 12 * 3 + 1), greaterThan(0));
    // Virado para a esquerda, a garrafa vai para o outro lado do quadro (coluna 15 - 6 = 9).
    final left = await paint(tester, [(bottle, 0)], mirrored: true);
    expect(alphaAt(left, 24 + 9 * 3 + 1, 24 + 12 * 3 + 1), greaterThan(0));
    expect(alphaAt(left, 24 + 6 * 3 + 1, 24 + 12 * 3 + 1), 0);
  });
}
