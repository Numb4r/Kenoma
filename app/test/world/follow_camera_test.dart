import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/aura.dart';
import 'package:kenoma/world/follow_camera.dart';
import 'package:kenoma/world/map_camera.dart';

/// Roda a câmera por [seconds] em passos de 1/60 s.
void run(FollowCamera c, double seconds) {
  for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
    c.update(1 / 60);
  }
}

void main() {
  group('seguir', () {
    test('começa olhando para o alvo, na escala padrão (16 px por célula)', () {
      final c = FollowCamera(x: 1000, y: 2000);
      expect((c.camera.centerX, c.camera.centerY, c.camera.pixelsPerCell), (1000.0, 2000.0, 16.0));
          });

    test('desliza para o alvo: em 3 constantes de tempo cobre ~95%, e nunca passa do alvo', () {
      final c = FollowCamera(x: 0, y: 0)..setTarget(10, 0);
      var prev = 0.0;
      for (var i = 0; i < 300; i++) {
        c.update(1 / 60);
        expect(c.followX, greaterThanOrEqualTo(prev));
        expect(c.followX, lessThanOrEqualTo(10));
        prev = c.followX;
      }
      final d = FollowCamera(x: 0, y: 0)..setTarget(10, 0);
      run(d, 0.75); // 3 x 0,25 s
      expect(d.followX, closeTo(10 * (1 - math.exp(-3)), 0.15));
      run(d, 3);
      expect(d.followX, closeTo(10, 0.001));
    });

    test('a suavização não depende do tamanho do passo de tempo', () {
      final a = FollowCamera(x: 0, y: 0)..setTarget(10, 5);
      final b = FollowCamera(x: 0, y: 0)..setTarget(10, 5);
      for (var i = 0; i < 60; i++) {
        a.update(1 / 60);
      }
      for (var i = 0; i < 10; i++) {
        b.update(0.1);
      }
      expect(a.followX, closeTo(b.followX, 1e-9));
      expect(a.followY, closeTo(b.followY, 1e-9));
    });

    test('um alvo que anda a 1,4 m/s (~0,08 célula/s) é acompanhado de perto', () {
      final c = FollowCamera(x: 0, y: 0);
      var worst = 0.0;
      for (var i = 0; i < 600; i++) {
        c.setTarget(0.08 * i / 60, 0);
        c.update(1 / 60);
        worst = math.max(worst, 0.08 * i / 60 - c.followX);
      }
      expect(worst, lessThan(0.08 * 0.25 + 1e-6), reason: 'o atraso de uma constante de tempo: ~0,02 célula');
    });

    test('um teleporte (alvo a mais de 200 células) pula em vez de deslizar por cima do mapa', () {
      final c = FollowCamera(x: 0, y: 0)..setTarget(5000, 3000);
      c.update(1 / 60);
      expect((c.followX, c.followY), (5000.0, 3000.0));
    });

    test('snapToTarget vai direto, sem deslizar (a primeira posição)', () {
      final c = FollowCamera(x: 0, y: 0)..setTarget(10, 10);
      c.snapToTarget();
      expect((c.followX, c.followY), (10.0, 10.0));
    });

    test('passo de tempo zero ou negativo não faz nada', () {
      final c = FollowCamera(x: 0, y: 0)..setTarget(10, 0);
      c.update(0);
      c.update(-1);
      expect(c.followX, 0);
    });
  });

  group('presa ao Conjurador', () {
    test('o centro da câmera é sempre o do Conjurador, mesmo com o dedo na tela e girando', () {
      final c = FollowCamera(x: 100, y: 100);
      c.touchStart();
      c.setRotation(1.2);
      run(c, 5);
      expect((c.camera.centerX, c.camera.centerY), (100.0, 100.0));
      expect(c.touching, isTrue);
      c.touchEnd();
      expect(c.touching, isFalse);
    });
  });

  group('zoom do jogo', () {
    test('a faixa de jogo é menor que a do debug', () {
      expect(FollowCamera.minScale, greaterThan(MapCamera.minScale));
      expect(FollowCamera.maxScale, lessThan(MapCamera.maxScale));
      expect((FollowCamera.minScale, FollowCamera.maxScale, FollowCamera.defaultScale), (8.0, 24.0, 16.0));
    });

    test('setScale limita à faixa e o zoom não mexe no centro', () {
      final c = FollowCamera(x: 50, y: 60);
      c.setScale(20);
      expect(c.pixelsPerCell, 20);
      c.setScale(1);
      expect(c.pixelsPerCell, 8);
      c.setScale(100);
      expect(c.pixelsPerCell, 24);
      expect((c.camera.centerX, c.camera.centerY), (50.0, 60.0));
      expect(FollowCamera(x: 0, y: 0, pixelsPerCell: 99).pixelsPerCell, 24);
    });

  });

  group('Aura', () {
    test('40 m em Campinas são ~2,3 células: ~36 px a 16 px por célula e ~73 px a 32', () {
      expect(auraRadiusPx(auraM: 40, lat: -22.8174, pixelsPerCell: 16), closeTo(36.4, 0.3));
      expect(auraRadiusPx(auraM: 40, lat: -22.8174, pixelsPerCell: 32), closeTo(72.7, 0.6));
    });

    test('cresce com o zoom e com o raio, e o diâmetro da Aura cabe com folga na faixa de zoom do jogo', () {
      final small = auraRadiusPx(auraM: 40, lat: -22.8, pixelsPerCell: FollowCamera.minScale);
      final big = auraRadiusPx(auraM: 40, lat: -22.8, pixelsPerCell: FollowCamera.maxScale);
      expect(big / small, closeTo(3, 1e-9));
      expect(auraRadiusPx(auraM: 80, lat: -22.8, pixelsPerCell: 16), closeTo(2 * auraRadiusPx(auraM: 40, lat: -22.8, pixelsPerCell: 16), 1e-9));
      expect(small, greaterThan(15), reason: 'no zoom mínimo a Aura ainda é visível');
    });
  });
}
