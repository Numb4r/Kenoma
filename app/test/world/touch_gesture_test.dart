import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/touch_gesture.dart';

void main() {
  const center = Offset(200, 400); // o Conjurador, no centro da tela
  const o = Offset(100, 100);

  double angleOf(Offset p) => math.atan2(p.dy - center.dy, p.dx - center.dx);

  group('toque, arrasto e toque longo', () {
    test('toque curto: solta parado antes de 500 ms devolve o ponto', () {
      final g = TouchGesture()..down(o, 0);
      expect(g.move(o + const Offset(5, 3), center: center), 0);
      expect(g.up(o + const Offset(5, 3), 200), o + const Offset(5, 3));
    });

    test('passou do limiar de distância vira arrasto, e soltar não é toque', () {
      final g = TouchGesture(slopPx: 12)..down(o, 0);
      g.move(o + const Offset(20, 0), center: center);
      expect(g.dragging, isTrue);
      expect(g.up(o + const Offset(20, 0), 100), isNull);
    });

    test('arrasto não vira toque longo, nem voltando ao ponto inicial', () {
      final g = TouchGesture()..down(o, 0);
      g.move(o + const Offset(40, 0), center: center);
      g.move(o, center: center);
      expect(g.longPress(), isNull);
      expect(g.up(o, 900), isNull);
    });

    test('toque longo: dispara uma vez, no ponto de partida, e soltar depois não é toque', () {
      final g = TouchGesture()..down(o, 0);
      expect(g.longPress(), o);
      expect(g.longPress(), isNull, reason: 'uma vez só');
      expect(g.up(o, 700), isNull);
    });

    test('soltar depois de 500 ms sem o temporizador ter rodado também não é toque', () {
      final g = TouchGesture()..down(o, 0);
      expect(g.up(o, 800), isNull);
    });

    test('dois dedos cancelam: nem toque, nem arrasto, nem toque longo', () {
      final g = TouchGesture()..down(o, 0);
      g.down(const Offset(200, 200), 50);
      expect(g.move(const Offset(300, 100), center: center), 0);
      expect(g.longPress(), isNull);
      expect(g.up(o, 100), isNull);
      expect(g.up(o, 120), isNull);
    });

    test('um gesto novo depois de soltar começa limpo', () {
      final g = TouchGesture()..down(o, 0);
      g.move(o + const Offset(50, 0), center: center);
      g.up(o, 100);
      g.down(o, 1000);
      expect(g.up(o, 1100), o);
    });
  });

  group('o giro acompanha o dedo em volta do Conjurador', () {
    test('do lado direito, descer o dedo gira no sentido horário (positivo)', () {
      final g = TouchGesture()..down(center + const Offset(150, 0), 0);
      var turn = g.move(center + const Offset(150, 40), center: center);
      turn += g.move(center + const Offset(150, 100), center: center);
      expect(turn, greaterThan(0));
      expect(turn, closeTo(angleOf(center + const Offset(150, 100)) - angleOf(center + const Offset(150, 0)), 1e-9));
    });

    test('do lado esquerdo, subir o dedo também gira no sentido horário: o mesmo giro dos dois lados', () {
      double spin(Offset from, Offset to) {
        final g = TouchGesture()..down(from, 0);
        return g.move(to, center: center);
      }

      final right = spin(center + const Offset(150, 0), center + const Offset(150, 80));
      final left = spin(center + const Offset(-150, 0), center + const Offset(-150, -80));
      expect(right, greaterThan(0));
      expect(left, closeTo(right, 1e-9), reason: 'a assimetria do lado direito era o bug');
    });

    test('em cima da tela, o dedo para a direita é horário; embaixo, para a esquerda é horário', () {
      double spin(Offset from, Offset to) => (TouchGesture()..down(from, 0)).move(to, center: center);
      expect(spin(center + const Offset(0, -150), center + const Offset(80, -150)), greaterThan(0));
      expect(spin(center + const Offset(0, 150), center + const Offset(-80, 150)), greaterThan(0));
      expect(spin(center + const Offset(0, -150), center + const Offset(-80, -150)), lessThan(0));
    });

    test('o ponto do mapa sob o dedo fica sob o dedo: o giro acumulado é o ângulo que o dedo percorreu', () {
      final g = TouchGesture()..down(center + const Offset(120, 0), 0);
      var total = 0.0;
      var last = center + const Offset(120, 0);
      // O dedo dá três quartos de volta em torno do centro, num círculo de raio 120, em passos pequenos.
      for (var i = 1; i <= 90; i++) {
        final a = 2 * math.pi * 0.75 * i / 90;
        last = center + Offset(120 * math.cos(a), 120 * math.sin(a));
        total += g.move(last, center: center);
      }
      expect(total, closeTo(2 * math.pi * 0.75, 1e-6));
    });

    test('atravessar o lado esquerdo (a virada de ±π) não dá salto', () {
      final g = TouchGesture()..down(center + const Offset(-120, -10), 0);
      final before = g.move(center + const Offset(-120, -40), center: center); // acima do eixo: o ângulo é negativo
      final across = g.move(center + const Offset(-120, 10), center: center); // cruza o eixo: o ângulo passa de -π para π
      expect(before.abs(), lessThan(0.5));
      expect(across.abs(), lessThan(0.6), reason: 'nada de uma volta inteira de uma vez');
    });

    test('o primeiro movimento depois do limiar conta desde onde o dedo desceu: o mapa não fica para trás', () {
      final g = TouchGesture(slopPx: 12)..down(center + const Offset(150, 0), 0);
      final first = g.move(center + const Offset(150, 30), center: center);
      expect(first, closeTo(angleOf(center + const Offset(150, 30)) - angleOf(center + const Offset(150, 0)), 1e-9));
    });

    test('dentro do limiar de distância não gira nada', () {
      final g = TouchGesture(slopPx: 12)..down(center + const Offset(150, 0), 0);
      expect(g.move(center + const Offset(150, 8), center: center), 0);
      expect(g.dragging, isFalse);
    });

    test('muito perto do centro o ângulo do dedo não é confiável: o giro espera', () {
      final g = TouchGesture()..down(center + const Offset(10, 0), 0);
      expect(g.move(center + const Offset(10, 30), center: center), 0);
      expect(g.dragging, isTrue, reason: 'já é arrasto, então não vira toque');
      expect(g.move(center + const Offset(100, 30), center: center), 0, reason: 'o ponto anterior ainda estava perto demais');
      expect(g.move(center + const Offset(100, 90), center: center), greaterThan(0), reason: 'agora segue o dedo');
    });
  });
}
