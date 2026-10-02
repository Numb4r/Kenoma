import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/fx/dial_fx.dart';
import 'package:kenoma/capture/fire_wave.dart';
import 'package:kenoma/capture/fx/fire_fx.dart';
import 'package:kenoma/capture/fx/wave_geometry.dart';
import 'package:kenoma/ui/colors.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';
import 'package:kenoma/ui/tuning/fx_painter.dart';
import 'package:kenoma/ui/tuning/tuning_painter.dart';

TuningView view({double progress = 0.5, bool aligned = false, bool showTarget = false, EcoType type = EcoType.fire, bool hidden = false, TuningFx? fx}) =>
    TuningView(
      dial: 0.3,
      target: 0.7,
      tolerance: 0.08,
      progress: progress,
      timeRemaining: 12,
      timeLimit: 20,
      aligned: aligned,
      clock: 2.0,
      scroll: 0.0,
      type: type,
      sealLabel: 'Selo simples',
      tonic: true,
      showTarget: showTarget,
      hidden: hidden,
      fx: fx,
    );

/// Fogo com a onda partida em [burnU]: a real à direita, a isca cinza à esquerda e, com
/// [olderDecoys], mais um trecho cinza antigo, ainda na tela, à esquerda dela.
TuningFx splitFx({double burnU = 0.5, bool olderDecoys = false}) => TuningFx(
      dial: DialFx(),
      dialColor: kSignal,
      fire: FireFxState(
        split: FireSplit(
          index: 0,
          since: 0.5,
          boundaryU: burnU,
          decoyFrequency: 0.3,
          decoyLife: 1,
          segments: [
            WaveSegment(fromU: burnU, toU: 1, frequency: 0.7, anchorU: burnU, phase: 0, real: true),
            WaveSegment(fromU: olderDecoys ? 0.2 : 0, toU: burnU, frequency: 0.3, anchorU: burnU, phase: 0, real: false),
            if (olderDecoys) const WaveSegment(fromU: 0, toU: 0.2, frequency: 0.5, anchorU: 0.2, phase: 1, real: false),
          ],
        ),
      ),
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

  testWidgets('alinhado acende o aro ciano', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final off = count(await render(view(), sprite), kSignal);
      final on = count(await render(view(aligned: true), sprite), kSignal);
      expect(on, greaterThan(off), reason: 'aro do anel e borda do painel');
    });
  });

  testWidgets('Fogo partido: a fronteira da queima é uma linha vertical e a isca é cinza desde a queima', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final plain = await render(view(), sprite);
      final split = await render(view(fx: splitFx()), sprite);
      expect(count(split, kEssence), greaterThan(count(plain, kEssence) + 100), reason: 'a linha da queima corta o painel');
      expect(count(split, kDim), greaterThan(count(plain, kDim)), reason: 'o trecho da esquerda é cinza, não ciano');
      expect(count(split, kSignal), lessThan(count(plain, kSignal)), reason: 'só o trecho da direita é ciano');
      expect(split, isNot(plain));
    });
  });

  testWidgets('a isca antiga que ainda está na tela também é cinza e tem a fronteira dela', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final one = await render(view(fx: splitFx()), sprite);
      final two = await render(view(fx: splitFx(olderDecoys: true)), sprite);
      expect(count(two, kDim), greaterThan(count(one, kDim)));
      expect(two, isNot(one));
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

  testWidgets('tipo oculto: a onda do sinal fica cinza, sem onda partida, e a silhueta é neutra', (tester) async {
    await tester.runAsync(() async {
      final neutral = await EcoSprite.loadNeutral();
      final shown = await render(view(), neutral);
      final hidden = await render(view(hidden: true, fx: splitFx()), neutral);
      expect(count(shown, kSignal), greaterThan(150));
      expect(count(hidden, kSignal), lessThan(20), reason: 'sem ciano na onda: a cor do sinal é cinza');
      expect(count(hidden, kDim), greaterThan(100), reason: 'onda cinza');
      final calm = await render(view(hidden: true, fx: TuningFx(dial: DialFx(), dialColor: kSignal)), neutral);
      expect(hidden, calm, reason: 'a onda partida do Fogo não aparece no modo oculto');
    });
  });

  testWidgets('a silhueta neutra desenha diferente de qualquer Eco', (tester) async {
    await tester.runAsync(() async {
      final neutral = await render(view(hidden: true), await EcoSprite.loadNeutral());
      for (final id in ['soot.eco', 'frond.eco', 'rill.eco']) {
        expect(neutral, isNot(await render(view(hidden: true), await EcoSprite.load(id))), reason: id);
      }
    });
  });
}
