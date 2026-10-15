import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/follow_camera.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/map_rotation.dart';

const pi = math.pi;

void main() {
  group('conversão tela-mundo com rotação (MapCamera)', () {
    const w = 400.0, h = 800.0;

    test('sem rotação nada muda: o leste fica à direita e o sul embaixo', () {
      const cam = MapCamera(centerX: 100, centerY: 200, pixelsPerCell: 10);
      expect(cam.cellToScreen(101, 200, w, h), (w / 2 + 10, h / 2));
      expect(cam.cellToScreen(100, 201, w, h), (w / 2, h / 2 + 10));
    });

    test('girar 90° no sentido horário leva o norte para a direita e o leste para baixo', () {
      const cam = MapCamera(centerX: 100, centerY: 200, pixelsPerCell: 10, rotation: pi / 2);
      final (nx, ny) = cam.cellToScreen(100, 199, w, h); // 1 célula ao norte
      expect(nx, closeTo(w / 2 + 10, 1e-9));
      expect(ny, closeTo(h / 2, 1e-9));
      final (ex, ey) = cam.cellToScreen(101, 200, w, h); // 1 célula a leste
      expect(ex, closeTo(w / 2, 1e-9));
      expect(ey, closeTo(h / 2 + 10, 1e-9));
    });

    test('ida e volta devolve a mesma coisa, em qualquer rotação e zoom', () {
      for (final rot in [0.0, 0.3, pi / 2, 2.5, pi, -1.1, -pi / 2 + 0.01]) {
        for (final ppc in [8.0, 40.0, 120.0]) {
          final cam = MapCamera(centerX: 5000.5, centerY: 7000.25, pixelsPerCell: ppc, rotation: rot);
          for (final (sx, sy) in [(0.0, 0.0), (w, h), (123.0, 456.0), (w / 2, h / 2)]) {
            final (cx, cy) = cam.screenToCell(sx, sy, w, h);
            final (bx, by) = cam.cellToScreen(cx, cy, w, h);
            expect(bx, closeTo(sx, 1e-6), reason: 'rot $rot, ppc $ppc');
            expect(by, closeTo(sy, 1e-6));
          }
        }
      }
    });

    test('o centro da tela é o centro da câmera, qualquer que seja a rotação', () {
      for (final rot in [0.0, 1.0, -2.0]) {
        final cam = MapCamera(centerX: 12.5, centerY: 34.5, pixelsPerCell: 20, rotation: rot);
        final (x, y) = cam.screenToCell(w / 2, h / 2, w, h);
        expect((x, y), (12.5, 34.5));
      }
    });

    test('tocar num ponto do mundo com o mapa girado encontra o ponto: o toque num Eco continua valendo', () {
      const cam = MapCamera(centerX: 1000, centerY: 2000, pixelsPerCell: 40, rotation: 0.9);
      const ecoX = 1001.7, ecoY = 1999.2;
      final (sx, sy) = cam.cellToScreen(ecoX, ecoY, w, h);
      final (cx, cy) = cam.screenToCell(sx, sy, w, h);
      expect(cx, closeTo(ecoX, 1e-9));
      expect(cy, closeTo(ecoY, 1e-9));
      // E um toque a 20 px dali ainda cai a menos de meia célula do Eco.
      final (nx, ny) = cam.screenToCell(sx + 20, sy, w, h);
      expect(math.sqrt(math.pow(nx - ecoX, 2) + math.pow(ny - ecoY, 2)), closeTo(0.5, 1e-9));
    });

    test('as células visíveis cobrem os quatro cantos com o mapa girado, e o retângulo cresce', () {
      const flat = MapCamera(centerX: 500, centerY: 500, pixelsPerCell: 20);
      const turned = MapCamera(centerX: 500, centerY: 500, pixelsPerCell: 20, rotation: pi / 4);
      final a = flat.visibleRange(w, h), b = turned.visibleRange(w, h);
      expect(b.count, greaterThan(a.count));
      for (final (sx, sy) in [(0.0, 0.0), (w, 0.0), (0.0, h), (w, h)]) {
        final (cx, cy) = turned.screenToCell(sx, sy, w, h);
        expect(b.contains(cx.floor(), cy.floor()), isTrue);
      }
      // Sem rotação o resultado é o de sempre.
      final (l, t) = flat.screenToCell(0, 0, w, h);
      expect(a.x0, l.floor());
      expect(a.y0, t.floor());
    });

    test('arrastar com o mapa girado move o mapa com o dedo, no sentido do dedo na tela', () {
      const cam = MapCamera(centerX: 100, centerY: 100, pixelsPerCell: 10, rotation: pi / 2);
      final moved = cam.panned(30, 0); // dedo 30 px para a direita
      // O ponto que estava no centro agora aparece 30 px à direita.
      final (sx, sy) = moved.cellToScreen(100, 100, w, h);
      expect(sx, closeTo(w / 2 + 30, 1e-9));
      expect(sy, closeTo(h / 2, 1e-9));
    });

    test('o zoom em torno de um ponto mantém o ponto parado, girado ou não', () {
      const cam = MapCamera(centerX: 700, centerY: 900, pixelsPerCell: 16, rotation: 0.7);
      const fx = 300.0, fy = 200.0;
      final (cx, cy) = cam.screenToCell(fx, fy, w, h);
      final zoomed = cam.zoomedAbout(24, fx, fy, w, h);
      final (sx, sy) = zoomed.cellToScreen(cx, cy, w, h);
      expect(sx, closeTo(fx, 1e-9));
      expect(sy, closeTo(fy, 1e-9));
      expect(zoomed.rotation, 0.7);
    });
  });

  group('ângulos', () {
    test('normalizar leva para (-pi, pi]', () {
      expect(normalizeAngle(0), 0);
      expect(normalizeAngle(3 * pi), closeTo(pi, 1e-12));
      expect(normalizeAngle(-3 * pi / 2), closeTo(pi / 2, 1e-12));
      expect(normalizeAngle(2 * pi + 0.1), closeTo(0.1, 1e-12));
    });

    test('o menor giro passa pelo lado curto, inclusive na virada de 180°', () {
      expect(shortestDelta(0.1, 0.3), closeTo(0.2, 1e-12));
      expect(shortestDelta(pi - 0.1, -pi + 0.1), closeTo(0.2, 1e-12));
      expect(shortestDelta(-pi + 0.1, pi - 0.1), closeTo(-0.2, 1e-12));
    });

    test('a suavização anda pelo caminho curto e nunca passa do alvo', () {
      var a = pi - 0.05;
      for (var i = 0; i < 200; i++) {
        final before = shortestDelta(a, -pi + 0.05).abs();
        a = smoothAngle(a, -pi + 0.05, 0.05, 0.35);
        expect(shortestDelta(a, -pi + 0.05).abs(), lessThanOrEqualTo(before + 1e-12));
      }
      expect(shortestDelta(a, -pi + 0.05).abs(), lessThan(1e-3));
    });

    test('a rotação para um rumo põe o rumo para cima: o celular no leste gira o mapa 90° para a esquerda', () {
      expect(rotationForHeading(0), 0);
      expect(rotationForHeading(90), closeTo(-pi / 2, 1e-12));
      expect(rotationForHeading(270), closeTo(pi / 2, 1e-12));
      // Com o mapa girado assim, 1 célula ao leste aparece acima do centro.
      final cam = MapCamera(centerX: 0, centerY: 0, pixelsPerCell: 10, rotation: rotationForHeading(90));
      final (x, y) = cam.cellToScreen(1, 0, 100, 100);
      expect(x, closeTo(50, 1e-9));
      expect(y, closeTo(50 - 10, 1e-9));
    });
  });

  group('MapRotation', () {
    test('começa com o norte para cima, sem bússola e sem seguir direção', () {
      final r = MapRotation();
      expect((r.angle, r.showCompass, r.followHeading), (0.0, false, false));
    });

    test('arrastar para a direita gira no sentido horário, direto no dedo, e a bússola aparece', () {
      final r = MapRotation();
      r.dragBy(80);
      expect(r.angle, closeTo(80 * MapRotation.radPerPx, 1e-12));
      expect(r.showCompass, isTrue);
      r.dragBy(-80);
      expect(r.angle, closeTo(0, 1e-12));
    });

    test('o giro manual fica onde está: nem soltar perto do norte nem o tempo o devolvem', () {
      final r = MapRotation();
      r.dragBy(4); // 0,05 rad, perto do norte
      final at = r.angle;
      for (var i = 0; i < 600; i++) {
        r.update(0.016);
      }
      expect(r.angle, closeTo(at, 1e-12));
    });

    test('arrastar além de uma volta normaliza o ângulo', () {
      final r = MapRotation();
      r.dragBy(600); // 7,5 rad
      expect(r.angle, inExclusiveRange(-pi - 1e-9, pi + 1e-9));
      expect(r.angle, closeTo(7.5 - 2 * pi, 1e-9));
    });

    test('tocar na bússola leva ao norte pelo caminho curto, e some a bússola', () {
      final r = MapRotation();
      r.dragBy(240); // 3,0 rad
      final start = r.angle;
      expect(start.abs(), greaterThan(2));
      r.goNorth();
      var last = r.angle.abs();
      for (var i = 0; i < 200; i++) {
        r.update(0.02);
        expect(r.angle.abs(), lessThanOrEqualTo(last + 1e-12), reason: 'só diminui');
        last = r.angle.abs();
      }
      expect(r.angle, 0);
      expect(r.showCompass, isFalse);
    });

    test('seguir direção: o mapa vai para o rumo do celular com suavização, e a bússola aparece mesmo no norte', () {
      final r = MapRotation();
      r.setHeading(90); // lê o rumo antes de ligar
      r.toggleFollowHeading();
      expect(r.followHeading, isTrue);
      expect(r.showCompass, isTrue);
      r.update(0.016);
      expect(r.angle, lessThan(0));
      expect(r.angle, greaterThan(-pi / 2), reason: 'não salta: suaviza');
      for (var i = 0; i < 300; i++) {
        r.update(0.016);
      }
      expect(r.angle, closeTo(-pi / 2, 1e-3));
      r.setHeading(100);
      for (var i = 0; i < 300; i++) {
        r.update(0.016);
      }
      expect(r.angle, closeTo(rotationForHeading(100), 1e-3));
    });

    test('seguir direção atravessa o norte pelo lado curto (350° para 10°)', () {
      final r = MapRotation();
      r.toggleFollowHeading();
      r.setHeading(350);
      for (var i = 0; i < 400; i++) {
        r.update(0.016);
      }
      r.setHeading(10);
      var maxAbs = 0.0;
      for (var i = 0; i < 400; i++) {
        r.update(0.016);
        maxAbs = math.max(maxAbs, r.angle.abs());
      }
      expect(maxAbs, lessThan(0.5), reason: 'nunca girou o caminho longo');
      expect(r.angle, closeTo(rotationForHeading(10), 1e-3));
    });

    test('desligar o seguir direção deixa o mapa onde está; girar com a mão também desliga', () {
      final r = MapRotation();
      r.setHeading(45);
      r.toggleFollowHeading();
      for (var i = 0; i < 300; i++) {
        r.update(0.016);
      }
      final at = r.angle;
      r.toggleFollowHeading();
      r.setHeading(200);
      for (var i = 0; i < 300; i++) {
        r.update(0.016);
      }
      expect(r.angle, closeTo(at, 1e-9));

      r.toggleFollowHeading();
      expect(r.followHeading, isTrue);
      r.dragBy(40);
      expect(r.followHeading, isFalse);
    });
  });

  group('FollowCamera com rotação', () {
    test('girar o mapa não tira o Conjurador do lugar na tela', () {
      final c = FollowCamera(x: 1000, y: 2000, pixelsPerCell: 20);
      const w = 400.0, h = 800.0;
      final before = c.camera.cellToScreen(1000, 2000, w, h);
      for (final rot in [0.4, 1.3, -2.0, 3.0]) {
        c.setRotation(rot);
        final after = c.camera.cellToScreen(1000, 2000, w, h);
        expect(after.$1, closeTo(before.$1, 1e-6), reason: 'rot $rot');
        expect(after.$2, closeTo(before.$2, 1e-6));
      }
    });
  });
}
