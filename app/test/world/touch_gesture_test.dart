import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/touch_gesture.dart';

void main() {
  const o = Offset(100, 100);

  test('toque curto: solta parado antes de 500 ms devolve o ponto', () {
    final g = TouchGesture()..down(o, 0);
    expect(g.move(o + const Offset(5, 3)), 0);
    expect(g.up(o + const Offset(5, 3), 200), o + const Offset(5, 3));
  });

  test('passou do limiar de distância vira arrasto: devolve o dx a partir do ponto em que o limiar foi vencido, e soltar não é toque', () {
    final g = TouchGesture(slopPx: 12)..down(o, 0);
    expect(g.move(o + const Offset(20, 0)), 0, reason: 'o salto até o limiar não gira o mapa');
    expect(g.dragging, isTrue);
    expect(g.move(o + const Offset(35, 0)), 15);
    expect(g.move(o + const Offset(30, 4)), -5);
    expect(g.up(o + const Offset(30, 4), 100), isNull);
  });

  test('arrasto não vira toque longo, nem voltando ao ponto inicial', () {
    final g = TouchGesture()..down(o, 0);
    g.move(o + const Offset(40, 0));
    g.move(o);
    expect(g.checkLongPress(900), isNull);
    expect(g.up(o, 900), isNull);
  });

  test('toque longo: 500 ms parado dispara uma vez, no ponto de partida, e soltar depois não é toque', () {
    final g = TouchGesture()..down(o, 0);
    expect(g.checkLongPress(499), isNull);
    expect(g.checkLongPress(500), o);
    expect(g.checkLongPress(600), isNull);
    expect(g.up(o, 700), isNull);
  });

  test('soltar sem o temporizador ter rodado, depois de 500 ms, também não é toque', () {
    final g = TouchGesture()..down(o, 0);
    expect(g.up(o, 800), isNull);
  });

  test('dois dedos cancelam: nem toque, nem arrasto, nem toque longo', () {
    final g = TouchGesture()..down(o, 0);
    g.down(const Offset(200, 200), 50);
    expect(g.move(const Offset(300, 100)), 0);
    expect(g.checkLongPress(600), isNull);
    expect(g.up(o, 100), isNull);
    expect(g.up(o, 120), isNull);
  });

  test('um gesto novo depois de soltar começa limpo', () {
    final g = TouchGesture()..down(o, 0);
    g.move(o + const Offset(50, 0));
    g.up(o, 100);
    g.down(o, 1000);
    expect(g.up(o, 1100), o);
  });
}
