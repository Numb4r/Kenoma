import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/fog.dart';

void main() {
  const mpc = 17.6; // metros por célula z21 em Campinas

  group('bits e blocos', () {
    test('cada célula z20 tem uma chave de bloco z17 e um bit de 0 a 63', () {
      expect(FogState.chunkKey(387213, 592857), '48401,74107');
      expect(FogState.bitOf(387213, 592857), 1 * 8 + 5);
      expect(FogState.bitOf(0, 0), 0);
      expect(FogState.bitOf(7, 7), 63);
      expect(FogState.chunkKey(7, 7), '0,0');
      expect(FogState.chunkKey(8, 0), '1,0');
    });

    test('popCount conta bits, inclusive com o bit 63 (inteiro negativo)', () {
      expect(popCount(0), 0);
      expect(popCount(1 << 63), 1);
      expect(popCount((1 << 63) | 0xF), 5);
      expect(popCount(-1), 64);
    });
  });

  group('revelar', () {
    test('uma posição revela as células em volta, e a célula do jogador sempre entra', () {
      final fog = FogState();
      const x = 774426.4, y = 1185714.7; // z21 fracionário
      final n = fog.reveal(x, y, 40, mpc);
      expect(n, greaterThanOrEqualTo(4));
      expect(n, lessThanOrEqualTo(40));
      expect(fog.isRevealed((x / 2).floor(), (y / 2).floor()), isTrue);
      expect(fog.revealedCount, n);
    });

    test('revelar o mesmo lugar de novo não acrescenta nada', () {
      final fog = FogState();
      fog.reveal(774426.4, 1185714.7, 40, mpc);
      expect(fog.reveal(774426.4, 1185714.7, 40, mpc), 0);
    });

    test('só as células que tocam o círculo entram: raio maior revela mais', () {
      final small = FogState()..reveal(774426.4, 1185714.7, 20, mpc);
      final big = FogState()..reveal(774426.4, 1185714.7, 80, mpc);
      expect(big.revealedCount, greaterThan(small.revealedCount * 3));
    });

    test('andar uma rua em linha revela uma faixa contínua, sem buracos', () {
      final fog = FogState();
      var x = 774400.0;
      for (var i = 0; i < 100; i++) {
        fog.reveal(x, 1185714.3, 40, mpc);
        x += 1.4 / mpc * 5; // 5 s por passo a 1,4 m/s
      }
      final cx0 = (774400 / 2).floor(), cx1 = (x / 2).floor();
      for (var cx = cx0; cx <= cx1; cx++) {
        expect(fog.isRevealed(cx, (1185714.3 / 2).floor()), isTrue, reason: 'célula $cx');
      }
      expect(fog.isRevealed(cx1 + 5, (1185714.3 / 2).floor()), isFalse);
    });

    test('o raio de 40 m cobre a Aura de 25 m mais o bônus do Círculo (12 m): a névoa nunca esconde um Eco na Aura', () {
      final fog = FogState()..reveal(774426.4, 1185714.7, 40, mpc);
      for (var a = 0.0; a < 6.28; a += 0.2) {
        // Pontos a 37 m (a Aura maior possível) em volta do jogador.
        final px = 774426.4 + 37 / mpc * 0.999 * math.cos(a), py = 1185714.7 + 37 / mpc * 0.999 * math.sin(a);
        expect(fog.isRevealed((px / 2).floor(), (py / 2).floor()), isTrue, reason: 'ângulo $a');
      }
    });
  });

  group('debug', () {
    test('o caminho do simulador revela, mas fica à parte e dá para limpar sem tocar no real', () {
      final fog = FogState()..reveal(774426.4, 1185714.7, 40, mpc);
      final real = fog.revealedCount;
      fog.reveal(774600, 1185900, 40, mpc, debug: true);
      expect(fog.revealedCount, real, reason: 'o contador de área só conta o caminho real');
      expect(fog.debugCount, greaterThan(0));
      expect(fog.isRevealed((774600 / 2).floor(), (1185900 / 2).floor()), isTrue);
      fog.clearDebug();
      expect(fog.debugCount, 0);
      expect(fog.isRevealed((774600 / 2).floor(), (1185900 / 2).floor()), isFalse);
      expect(fog.revealedCount, real);
    });
  });

  group('save', () {
    test('vai e volta no JSON, com os dois conjuntos e os inteiros de 64 bits', () {
      final fog = FogState()
        ..reveal(774426.4, 1185714.7, 40, mpc)
        ..reveal(7.0, 7.0, 40, mpc) // bloco 0,0 com bits altos
        ..reveal(774600, 1185900, 40, mpc, debug: true);
      final again = FogState.fromJson(jsonDecode(jsonEncode(fog.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), fog.toJson());
      expect(again.revealedCount, fog.revealedCount);
      expect(again.debugCount, fog.debugCount);
    });

    test('um save sem o bloco começa tudo coberto', () {
      final fog = FogState.fromJson(null);
      expect(fog.revealedCount, 0);
      expect(fog.isRevealed(5, 5), isFalse);
    });

    test('a área revelada: células × lado², em km²', () {
      final fog = FogState()..reveal(774426.4, 1185714.7, 40, mpc);
      expect(fog.areaKm2(35.2), closeTo(fog.revealedCount * 35.2 * 35.2 / 1e6, 1e-12));
    });
  });
}
