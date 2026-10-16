import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/sprites/sprite_data.dart';
import 'package:kenoma/ui/sprites/sprite_downscale.dart';

void main() {
  int count(List<String> rows, String c) => rows.join().split('').where((x) => x == c).length;
  int solid(List<String> rows) => rows.join().split('').where((x) => x != '.').length;

  group('redesenho em grade menor', () {
    for (final entry in ecoSprites.entries) {
      test('${entry.key}: sai quadrado na grade pedida, só com caracteres do sprite e sem mistura', () {
        final small = downscaleRows(entry.value, 20);
        expect(small.length, 20);
        expect(small.every((r) => r.length == 20), isTrue);
        final alphabet = entry.value.join().split('').toSet();
        expect(small.join().split('').toSet().difference(alphabet), isEmpty, reason: 'nenhuma cor nova: sem filtro');
        expect(solid(small), greaterThan(60), reason: 'ainda é uma criatura, não um borrão vazio');
      });

      test('${entry.key}: as costuras violeta continuam lá (são a identidade da criatura)', () {
        final small = downscaleRows(entry.value, 20);
        expect(count(small, 'v') + count(small, 'u'), greaterThan(0));
      });

      test('${entry.key}: a silhueta não engorda: a área sólida cai na proporção da grade', () {
        final big = solid(entry.value) / (48 * 48);
        final small = solid(downscaleRows(entry.value, 20)) / (20 * 20);
        expect(small, closeTo(big, 0.12));
      });
    }

    test('o Conjurador nos três quadros cabe em 18 pixels e continua legível', () {
      for (final f in [playerSprite, playerStepASprite, playerStepBSprite]) {
        final small = downscaleRows(f, 18);
        expect(small.length, 18);
        expect(solid(small), greaterThan(50));
        expect(small.first.split('').every((c) => c == '.') && small.last.split('').every((c) => c == '.'), isFalse, reason: 'ocupa a altura');
      }
    });

    test('os cantos continuam transparentes e o redesenho é determinístico', () {
      final a = downscaleRows(sootlingSprite, 20), b = downscaleRows(sootlingSprite, 20);
      expect(a, b);
      expect(a.first[0], '.');
      expect(a.last[19], '.');
    });

    test('mesmo tamanho devolve o mesmo sprite', () {
      expect(downscaleRows(sootlingSprite, 48), sootlingSprite);
    });
  });

  group('tamanho na tela', () {
    test('é sempre um múltiplo inteiro de pixels físicos por pixel do sprite', () {
      for (final dpr in [1.0, 2.0, 2.625, 3.0]) {
        for (var dp = 10.0; dp < 120; dp += 3.3) {
          final size = snapSpriteSize(dp, dpr, 20);
          final k = size * dpr / 20;
          expect((k - k.round()).abs(), lessThan(1e-9), reason: 'dp $dp dpr $dpr');
          expect(k.round(), greaterThanOrEqualTo(1));
        }
      }
    });

    test('fica perto do tamanho pedido e só cresce junto com ele', () {
      var prev = 0.0;
      for (var dp = 10.0; dp < 120; dp += 0.5) {
        final size = snapSpriteSize(dp, 2.625, 20);
        expect(size, greaterThanOrEqualTo(prev));
        expect((size - dp).abs(), lessThanOrEqualTo(20 / 2.625 / 2 + 1e-9), reason: 'no máximo meio passo');
        prev = size;
      }
    });

    test('no moto g54 em 90 m de largura: Eco de 9 m e Conjurador de 8 m ficam com ~2 dp por pixel', () {
      const dpPerM = 411.4 / 90;
      final eco = snapSpriteSize(9 * dpPerM, 2.625, 20);
      final player = snapSpriteSize(8 * dpPerM, 2.625, 18);
      expect(eco / 20, closeTo(1.9, 0.2), reason: '5 pixels físicos por pixel do sprite');
      expect(player / 18, closeTo(1.9, 0.2));
      expect(eco / dpPerM, closeTo(9, 0.8));
      expect(player / dpPerM, closeTo(8, 0.8));
    });
  });
}
