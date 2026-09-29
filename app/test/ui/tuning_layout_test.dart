import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/tuning/tuning_layout.dart';

void main() {
  group('ângulos do dial', () {
    test('0 é o canto inferior esquerdo, 0,5 é o topo, 1 é o canto inferior direito', () {
      expect(dialAngle(0), closeTo(3 * math.pi / 4, 1e-12));
      expect(math.cos(dialAngle(0.5)), closeTo(0, 1e-12));
      expect(math.sin(dialAngle(0.5)), closeTo(-1, 1e-12), reason: 'y para cima é negativo');
      expect(math.cos(dialAngle(1)), closeTo(math.sqrt1_2, 1e-12));
      expect(math.sin(dialAngle(1)), closeTo(math.sqrt1_2, 1e-12));
    });

    test('a abertura é de 270 graus', () {
      expect(dialAngle(1) - dialAngle(0), closeTo(3 * math.pi / 2, 1e-12));
    });

    test('angleDelta pega o caminho curto, também na virada de -pi para pi', () {
      const deg = math.pi / 180;
      expect(angleDelta(10 * deg, 30 * deg), closeTo(20 * deg, 1e-12));
      expect(angleDelta(179 * deg, -179 * deg), closeTo(2 * deg, 1e-12));
      expect(angleDelta(-179 * deg, 179 * deg), closeTo(-2 * deg, 1e-12));
    });

    test('girar o dial no sentido horário sobe a frequência; a abertura toda vai de 0 a 1', () {
      expect(dialAfterTurn(0, dialSweepRad), closeTo(1, 1e-12));
      expect(dialAfterTurn(0.5, dialSweepRad / 10), closeTo(0.6, 1e-12));
      expect(dialAfterTurn(0.5, -dialSweepRad / 10), closeTo(0.4, 1e-12));
    });

    test('o dial para nas pontas', () {
      expect(dialAfterTurn(0.9, dialSweepRad), 1);
      expect(dialAfterTurn(0.1, -dialSweepRad), 0);
    });
  });

  group('layout', () {
    for (final size in const [Size(360, 760), Size(393, 851), Size(412, 915), Size(430, 932)]) {
      test('$size: nada se sobrepõe e tudo cabe na tela', () {
        final l = TuningLayout(size);
        final screen = Offset.zero & size;
        final ring = Rect.fromCircle(center: l.creatureCenter, radius: l.ringRadius + 8);
        final dial = Rect.fromCircle(center: l.dialCenter, radius: l.dialRadius + 6);
        expect(screen.contains(ring.topLeft) && screen.contains(ring.bottomRight), isTrue, reason: 'criatura');
        expect(screen.contains(l.wavePanel.topLeft) && screen.contains(l.wavePanel.bottomRight), isTrue, reason: 'ondas');
        expect(screen.contains(dial.topLeft) && screen.contains(dial.bottomRight), isTrue, reason: 'dial');
        expect(l.timeBar.bottom, lessThan(ring.top), reason: 'HUD acima da criatura');
        expect(ring.bottom, lessThan(l.wavePanel.top), reason: 'criatura acima das ondas');
        expect(l.wavePanel.bottom, lessThan(dial.top), reason: 'ondas acima do dial');
        expect(l.spriteScale, greaterThanOrEqualTo(2));
        expect(l.spriteScale, isA<int>(), reason: 'escala inteira, vizinho mais próximo');
      });
    }

    test('o dial responde abaixo do painel das ondas e não na criatura', () {
      final l = TuningLayout(const Size(412, 915));
      expect(l.isDialTouch(l.dialCenter), isTrue);
      expect(l.isDialTouch(Offset(20, l.wavePanel.bottom + 1)), isTrue);
      expect(l.isDialTouch(l.creatureCenter), isFalse);
      expect(l.isDialTouch(l.wavePanel.center), isFalse);
    });

    test('angleOf mede a partir do centro do dial', () {
      final l = TuningLayout(const Size(412, 915));
      expect(l.angleOf(l.dialCenter + const Offset(0, -50)), closeTo(-math.pi / 2, 1e-12));
      expect(l.angleOf(l.dialCenter + const Offset(50, 0)), closeTo(0, 1e-12));
      expect(l.angleOf(l.dialCenter + const Offset(0, 50)), closeTo(math.pi / 2, 1e-12));
    });

    test('arrastar o dedo de baixo-esquerda por cima até baixo-direita cobre 0 a 1', () {
      final l = TuningLayout(const Size(412, 915));
      var dial = 0.0;
      var last = l.angleOf(l.dialCenter + Offset.fromDirection(dialAngle(0), 100));
      for (var i = 1; i <= 90; i++) {
        final a = l.angleOf(l.dialCenter + Offset.fromDirection(dialAngle(i / 90), 100));
        dial = dialAfterTurn(dial, angleDelta(last, a));
        last = a;
      }
      expect(dial, closeTo(1, 1e-9));
    });
  });
}
