import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/colors.dart';
import 'package:kenoma/ui/game/loading_screen.dart';

/// 0.26.2: a costura do Véu da tela de carregamento fecha conforme o progresso: aberta no começo (a borda violeta em
/// várias alturas, o miolo aceso), fechada no fim (a borda numa linha só, coberta de pontos).
void main() {
  /// As linhas (em pixels de arte) com a borda violeta e quantos pontos claros há, com [progress].
  Future<(Set<int>, int)> paint(WidgetTester tester, double progress) async {
    const size = Size(240, 60);
    final rec = ui.PictureRecorder();
    SeamPainter(progress, 0).paint(Canvas(rec), size);
    final img = (await tester.runAsync(() => rec.endRecording().toImage(size.width.toInt(), size.height.toInt())))!;
    final b = (await tester.runAsync(() => img.toByteData()))!;
    final edgeRows = <int>{};
    var stitches = 0;
    for (var y = 0; y < img.height; y += 3) {
      for (var x = 0; x < img.width; x += 3) {
        final i = ((y + 1) * img.width + x + 1) * 4;
        final c = Color.fromARGB(b.getUint8(i + 3), b.getUint8(i), b.getUint8(i + 1), b.getUint8(i + 2));
        if (c == kVeil) edgeRows.add(y ~/ 3);
        if (c == kText) stitches++;
      }
    }
    return (edgeRows, stitches);
  }

  testWidgets('aberta no começo, fechada e costurada no fim', (tester) async {
    final (open, none) = await paint(tester, 0);
    final (closed, sewn) = await paint(tester, 1);
    expect(open.length, greaterThan(6), reason: 'a fenda aberta tem borda em várias alturas');
    expect(none, 0, reason: 'sem progresso, sem pontos');
    expect(closed.length, 1, reason: 'fechada: a borda numa linha só');
    expect(sewn, greaterThan(10));
  });

  testWidgets('a tela mostra o nome e o aviso de carregamento', (tester) async {
    await tester.pumpWidget(MaterialApp(home: KenomaLoading(progress: ValueNotifier(0.3))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('KENOMA'), findsOneWidget);
    expect(find.text('Carregando mapa...'), findsOneWidget);
  });
}
