import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/companion.dart';

void main() {
  // 6 m ao lado, com ~17,6 m por célula z21.
  const off = 6 / 17.6;
  const speed = 1.4 / 17.6; // células por segundo a 1,4 m/s

  /// Anda o avatar [seconds] s para [dirX], [dirY] e devolve o Familiar.
  Companion walk(double dirX, double dirY, double seconds, {Companion? from, double ax = 100, double ay = 100}) {
    final c = from ?? Companion();
    for (var t = 0.0; t < seconds; t += 1 / 30) {
      ax += dirX * speed / 30;
      ay += dirY * speed / 30;
      c.update(1 / 30, ax: ax, ay: ay, vx: dirX * speed, vy: dirY * speed, offsetCells: off);
    }
    lastAvatar = (ax, ay);
    return c;
  }

  test('o primeiro quadro já aparece no lugar certo, sem deslizar de longe', () {
    final c = Companion()..update(1 / 30, ax: 100, ay: 100, vx: 0, vy: 0, offsetCells: off);
    expect(c.hasPosition, isTrue);
    expect((c.x - 100).abs() + (c.y - 100).abs(), lessThan(off * 2));
  });

  test('andando a leste, o Familiar fica ao sul (a direita de quem anda) e um pouco atrás', () {
    final c = walk(1, 0, 10);
    final (ax, ay) = lastAvatar;
    expect(c.y - ay, closeTo(off * 0.9, 0.02), reason: 'a direita de quem vai a leste é o sul');
    expect(c.x - ax, lessThan(0), reason: 'um pouco atrás');
    expect(math.sqrt((c.x - ax) * (c.x - ax) + (c.y - ay) * (c.y - ay)) * 17.6, inInclusiveRange(4, 7), reason: 'perto do conjurador: ~6 m');
  });

  test('andando a norte ele fica a leste; a oeste, ao norte: sempre pela direita', () {
    final north = walk(0, -1, 10);
    final (nx, ny) = lastAvatar;
    expect(north.x - nx, greaterThan(0));
    expect((north.y - ny).abs(), lessThan(off));
    final west = walk(-1, 0, 10);
    final (wx, wy) = lastAvatar;
    expect(west.y - wy, lessThan(0));
    expect(wx, isNotNull);
  });

  test('nunca pula: o passo por quadro cabe na velocidade de quem anda', () {
    final c = Companion();
    var ax = 100.0, ay = 100.0;
    c.update(1 / 30, ax: ax, ay: ay, vx: speed, vy: 0, offsetCells: off);
    var px = c.x, py = c.y, worst = 0.0;
    for (var i = 0; i < 600; i++) {
      ax += speed / 30;
      c.update(1 / 30, ax: ax, ay: ay, vx: speed, vy: 0, offsetCells: off);
      worst = math.max(worst, math.sqrt((c.x - px) * (c.x - px) + (c.y - py) * (c.y - py)));
      px = c.x;
      py = c.y;
    }
    expect(worst * 17.6 * 30, lessThan(2.5), reason: 'menos de 2,5 m/s no pior quadro');
  });

  test('curva: ao virar de leste para norte ele troca de lado suavemente, sem salto', () {
    final c = walk(1, 0, 8);
    final east = (c.x, c.y);
    final (ax, ay) = lastAvatar;
    var worst = 0.0;
    var px = c.x, py = c.y;
    var x = ax, y = ay;
    for (var i = 0; i < 300; i++) {
      y -= speed / 30;
      c.update(1 / 30, ax: x, ay: y, vx: 0, vy: -speed, offsetCells: off);
      worst = math.max(worst, math.sqrt((c.x - px) * (c.x - px) + (c.y - py) * (c.y - py)));
      px = c.x;
      py = c.y;
    }
    expect(worst * 17.6 * 30, lessThan(4.0));
    expect(c.x - x, greaterThan(0), reason: 'agora a direita é o leste');
    expect(east, isNotNull);
  });

  test('parado, fica do lado em que estava e para de andar', () {
    final c = walk(1, 0, 8);
    final (ax, ay) = lastAvatar;
    for (var i = 0; i < 150; i++) {
      c.update(1 / 30, ax: ax, ay: ay, vx: 0, vy: 0, offsetCells: off);
    }
    expect(c.y - ay, greaterThan(0), reason: 'continua ao sul');
    expect(c.moving, isFalse);
    expect(c.heading, closeTo(0, 1e-9), reason: 'ainda olha para leste');
  });

  test('um teleporte leva o Familiar de uma vez, sem deslizar por cima do mapa', () {
    final c = walk(1, 0, 5);
    c.update(1 / 30, ax: 5000, ay: 5000, vx: 0, vy: 0, offsetCells: off);
    expect((c.x - 5000).abs(), lessThan(off * 2));
    expect((c.y - 5000).abs(), lessThan(off * 2));
  });

  test('o passo de tempo zero ou negativo não faz nada, e a suavização não depende do tamanho do passo', () {
    final a = Companion()..update(1 / 30, ax: 0, ay: 0, vx: 0, vy: 0, offsetCells: off);
    final before = (a.x, a.y);
    a.update(0, ax: 50, ay: 0, vx: 0, vy: 0, offsetCells: off);
    a.update(-1, ax: 50, ay: 0, vx: 0, vy: 0, offsetCells: off);
    expect((a.x, a.y), before);
    final fine = Companion()..update(1 / 30, ax: 0, ay: 0, vx: 0, vy: 0, offsetCells: off);
    final coarse = Companion()..update(1 / 30, ax: 0, ay: 0, vx: 0, vy: 0, offsetCells: off);
    for (var i = 0; i < 30; i++) {
      fine.update(1 / 60, ax: 3, ay: 0, vx: 0, vy: 0, offsetCells: off);
      fine.update(1 / 60, ax: 3, ay: 0, vx: 0, vy: 0, offsetCells: off);
    }
    for (var i = 0; i < 30; i++) {
      coarse.update(1 / 30, ax: 3, ay: 0, vx: 0, vy: 0, offsetCells: off);
    }
    expect(fine.x, closeTo(coarse.x, 1e-9));
  });
}

(double, double) lastAvatar = (0, 0);
