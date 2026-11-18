import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/player_painter.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart' show mapPlayerPx;

/// 0.24.0: o equipamento do Conjurador no mapa (bolsa, garrafas do cinto, brilho do amuleto) entra no teste de giro como
/// sprite de pé. Ele é desenhado no espaço da tela, junto com o Conjurador: não recebe o giro do mapa, tem o tamanho do
/// quadro dele, espelha junto quando ele vira e cada garrafa a mais vai largura / 8 pixels de arte para o lado (2 na grade de 16, 3 na de 24).
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

  int alphaAt(List<int> rgba, double x, double y) => rgba[(y.floor() * 96 + x.floor()) * 4 + 3];

  testWidgets('o equipamento tem o tamanho do quadro do Conjurador e fica de pé', (tester) async {
    for (final n in ['gear_bag', 'gear_bottle', 'gear_amulet_glow']) {
      final img = await png(tester, n);
      expect((img.width, img.height), (mapPlayerPx, mapPlayerPx), reason: n);
    }
    final bottle = await png(tester, 'gear_bottle');
    // 0.25.0: a garrafa é achada na própria arte (na grade de 24 ela está em (9, 18)); o quadro tem 48 dp e começa em 24,
    // então cada pixel de arte vale 48 / 24 = 2 dp. A segunda garrafa vem `largura / 8` pixels depois (3 na grade de 24).
    final bytes = (await tester.runAsync(() => bottle.toByteData()))!;
    var col = -1, row = -1;
    for (var y = 0; y < bottle.height && col < 0; y++) {
      for (var x = 0; x < bottle.width; x++) {
        if (bytes.getUint8((y * bottle.width + x) * 4 + 3) > 0) (col, row) = (x, y);
        if (col >= 0) break;
      }
    }
    expect(col, greaterThanOrEqualTo(0));
    final step = bottle.width ~/ 8, px = 48 / mapPlayerPx;
    double at(int c) => 24 + c * px + px / 2;
    final one = await paint(tester, [(bottle, 0)]);
    final two = await paint(tester, [(bottle, 0), (bottle, step)]);
    expect(alphaAt(one, at(col), at(row)), greaterThan(0));
    expect(alphaAt(one, at(col + step), at(row)), 0);
    expect(alphaAt(two, at(col + step), at(row)), greaterThan(0));
    // Virado para a esquerda, a garrafa vai para o outro lado do quadro (coluna largura - 1 - col).
    final left = await paint(tester, [(bottle, 0)], mirrored: true);
    expect(alphaAt(left, at(bottle.width - 1 - col), at(row)), greaterThan(0));
    expect(alphaAt(left, at(col), at(row)), 0);
  });
}
