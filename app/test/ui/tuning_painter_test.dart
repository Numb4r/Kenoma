import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/fx/dial_fx.dart';
import 'package:kenoma/capture/fx/fire_fx.dart';
import 'package:kenoma/capture/signal.dart';
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
      type: type,
      sealLabel: 'Selo simples',
      tonic: true,
      showTarget: showTarget,
      hidden: hidden,
      fx: fx,
    );

/// Fogo com a onda partida em [burnU]. [life] é a vida da isca (0 = cinza).
TuningFx splitFx({double burnU = 0.5, double life = 1, RetiredDecoy? retired}) => TuningFx(
      dial: DialFx(),
      dialColor: kSignal,
      fire: FireFxState(
        split: FireSplit(index: 0, burnU: burnU, since: 0.5, decoyFrequency: 0.3, decoyLife: life, retired: retired),
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

  testWidgets('Fogo partido: a fronteira da queima é uma linha vertical e a isca morta fica cinza', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      final plain = await render(view(), sprite);
      final alive = await render(view(fx: splitFx()), sprite);
      final dead = await render(view(fx: splitFx(life: 0)), sprite);
      expect(count(alive, kEssence), greaterThan(count(plain, kEssence) + 100), reason: 'a linha da queima corta o painel');
      expect(count(dead, kDim), greaterThan(count(alive, kDim)), reason: 'isca morta: cinza');
      expect(count(dead, kSignal), lessThan(count(alive, kSignal)), reason: 'isca viva: ciano');
      expect(alive, isNot(plain));
    });
  });

  testWidgets('a isca aposentada por um pico novo aparece cinza e some depois do fade', (tester) async {
    await tester.runAsync(() async {
      final sprite = await EcoSprite.load('soot.eco');
      const fresh = RetiredDecoy(0.7, 0.2, 0);
      const gone = RetiredDecoy(0.7, 0.2, 2.0);
      final with0 = await render(view(fx: splitFx(life: 0, retired: fresh)), sprite);
      final without = await render(view(fx: splitFx(life: 0)), sprite);
      final faded = await render(view(fx: splitFx(life: 0, retired: gone)), sprite);
      expect(count(with0, kDim), greaterThan(count(without, kDim)));
      expect(faded, without);
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
