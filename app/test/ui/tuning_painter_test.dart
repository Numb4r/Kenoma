import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/ui/colors.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';
import 'package:kenoma/ui/tuning/tuning_painter.dart';

TuningView view({double progress = 0.5, bool aligned = false, double tremble = 0, bool showTarget = false, EcoType type = EcoType.fire}) =>
    TuningView(
      dial: 0.3,
      target: 0.7,
      tolerance: 0.08,
      progress: progress,
      timeRemaining: 12,
      timeLimit: 20,
      aligned: aligned,
      tremble: tremble,
      clock: 2.0,
      type: type,
      sealLabel: 'Selo simples',
      tonic: true,
      showTarget: showTarget,
    );

const size = ui.Size(412, 880);

Future<Uint8List> render(TuningView v, EcoSprite? sprite) async {
  final rec = ui.PictureRecorder();
  paintTuning(ui.Canvas(rec), size, v, sprite);
  final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  return (await img.toByteData())!.buffer.asUint8List();
}

int count(Uint8List px, ui.Color c) {
  var n = 0;
  final rgb = [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];
  for (var i = 0; i < px.length; i += 4) {
    if (px[i] == rgb[0] && px[i + 1] == rgb[1] && px[i + 2] == rgb[2] && px[i + 3] == 255) n++;
  }
  return n;
}

void main() {
  testWidgets('desenha as duas ondas, o dial e o anel com as cores do jogo', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final px = await render(view(), sprite);
      expect(px.length, 412 * 880 * 4);
      expect(count(px, kSignal), greaterThan(150), reason: 'onda da criatura em ciano');
      expect(count(px, kVeil), greaterThan(500), reason: 'onda do jogador, dial e anel em violeta');
      expect(count(px, kOutline), greaterThan(412 * 880 ~/ 3), reason: 'fundo em ameixa escuro');
      expect(count(px, const ui.Color(0xFF000000)), 0, reason: 'nunca preto puro');
    });
  });

  testWidgets('o anel de progresso cresce com o progresso', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final low = count(await render(view(progress: 0.1), sprite), kVeil);
      final high = count(await render(view(progress: 0.9), sprite), kVeil);
      expect(high, greaterThan(low));
    });
  });

  testWidgets('alinhado acende o aro ciano; a onda do Fogo tremula', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final off = count(await render(view(), sprite), kSignal);
      final on = count(await render(view(aligned: true), sprite), kSignal);
      expect(on, greaterThan(off), reason: 'aro do anel e borda do painel');
      final calm = await render(view(), sprite);
      final shaky = await render(view(tremble: 1), sprite);
      expect(shaky, isNot(calm));
    });
  });

  testWidgets('o alvo só aparece no dial com a ferramenta de debug ligada', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('rill.eco');
      final hidden = await render(view(showTarget: false, type: EcoType.water), sprite);
      final shown = await render(view(showTarget: true, type: EcoType.water), sprite);
      expect(shown, isNot(hidden), reason: 'a faixa do alvo é desenhada só com o debug ligado');
      expect(await render(view(showTarget: false, type: EcoType.water), sprite), hidden, reason: 'desenho estável');
    });
  });

  testWidgets('sem sprite ainda desenha o resto sem erro', (tester) async {
    await tester.runAsync(() async {
      final px = await render(view(), null);
      expect(count(px, kVeil), greaterThan(0));
    });
  });
}
