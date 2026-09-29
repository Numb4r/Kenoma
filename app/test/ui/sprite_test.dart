import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/sprites/sprite_data.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';

import '../support/fixtures.dart';

void main() {
  const outline = 0xFF1A1424;

  test('cada Eco de creatures.json tem sprite', () {
    final species = [for (final s in loadJson('assets/data/creatures.json')['species'] as List<dynamic>) (s as Map<String, dynamic>)['id']];
    expect(ecoSprites.keys.toSet(), species.toSet());
  });

  group('matrizes', () {
    for (final entry in {...ecoSprites, 'neutral': neutralSprite}.entries) {
      final rows = entry.value;

      test('${entry.key}: 48 x 48 e só caracteres da paleta', () {
        expect(rows, hasLength(48));
        for (final r in rows) {
          expect(r, hasLength(48));
          for (final ch in r.split('')) {
            expect(ch == '.' || spritePalette.containsKey(ch), isTrue, reason: 'caractere "$ch"');
          }
        }
      });

      test('${entry.key}: tem contorno, costuras violeta e brilho', () {
        final chars = rows.join();
        expect(chars, contains('O'));
        expect(chars, contains('v'));
        expect(chars, contains('u'));
      });

      test('${entry.key}: todo pixel do corpo encosta no contorno ou em outro pixel do corpo (sem ilhas soltas)', () {
        // Toda célula preenchida, menos o brilho 'u', fica a 4 vizinhos de outra preenchida.
        for (var y = 0; y < 48; y++) {
          for (var x = 0; x < 48; x++) {
            final ch = rows[y][x];
            if (ch == '.' || ch == 'u') continue;
            final neighbors = [
              if (x > 0) rows[y][x - 1],
              if (x < 47) rows[y][x + 1],
              if (y > 0) rows[y - 1][x],
              if (y < 47) rows[y + 1][x],
            ];
            expect(neighbors.any((n) => n != '.' && n != 'u'), isTrue, reason: '${entry.key} ($x, $y) "$ch" isolado');
          }
        }
      });

      test('${entry.key}: o corpo é fechado pelo contorno (nenhum corpo toca transparente)', () {
        for (var y = 0; y < 48; y++) {
          for (var x = 0; x < 48; x++) {
            final ch = rows[y][x];
            if (ch == '.' || ch == 'u' || ch == 'O') continue;
            for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
              final nx = x + dx, ny = y + dy;
              final n = (nx < 0 || ny < 0 || nx > 47 || ny > 47) ? '.' : rows[ny][nx];
              expect(n, isNot('.'), reason: '${entry.key} ($x, $y) "$ch" vaza para o transparente');
            }
          }
        }
      });

      test('${entry.key}: sem borda cortada no limite da imagem', () {
        for (var i = 0; i < 48; i++) {
          for (final ch in [rows[0][i], rows[47][i], rows[i][0], rows[i][47]]) {
            expect(ch, isNot('O'), reason: 'contorno encostando na borda');
          }
        }
      });
    }
  });

  test('paleta: contorno #1a1424, sem preto puro, até 24 cores no total', () {
    expect(spritePalette['O'], outline);
    expect(spritePalette.values.contains(0xFF000000), isFalse);
    final used = {for (final rows in [...ecoSprites.values, neutralSprite]) ...rows.join().split('')}..remove('.');
    expect(used.length, lessThanOrEqualTo(24));
    expect(used.every(spritePalette.containsKey), isTrue);
  });

  test('cores mágicas do GDD: costura violeta #9b7bff', () {
    expect(spritePalette['v'], 0xFF9B7BFF);
  });

  test('a silhueta neutra não usa nenhuma cor de tipo (soot, folha, água, brasa)', () {
    const typeChars = 'abcqopdefrshijkyz';
    expect(neutralSprite.join().split('').where(typeChars.contains), isEmpty);
    expect(ecoSprites.keys, isNot(contains('neutral')), reason: 'não é uma espécie');
  });

  group('conversão', () {
    test('pixels RGBA: transparente, contorno exato e costura violeta', () {
      final rows = sootlingSprite;
      final px = spritePixels(rows);
      expect(px.length, 48 * 48 * 4);
      expect(px.sublist(0, 4), [0, 0, 0, 0], reason: 'canto transparente');
      final o = _firstIndexOf(rows, 'O');
      expect(px.sublist(o, o + 4), [0x1A, 0x14, 0x24, 0xFF]);
      final v = _firstIndexOf(rows, 'v');
      expect(px.sublist(v, v + 4), [0x9B, 0x7B, 0xFF, 0xFF]);
    });

    test('versão acesa só muda costuras e brilho', () {
      final normal = spritePixels(sootlingSprite);
      final bright = spritePixels(sootlingSprite, brightSeams: true);
      var changed = 0;
      for (var y = 0; y < 48; y++) {
        for (var x = 0; x < 48; x++) {
          final i = (y * 48 + x) * 4;
          final same = _eq(normal, bright, i);
          final ch = sootlingSprite[y][x];
          if (ch == 'v' || ch == 'u') {
            expect(same, isFalse);
            changed++;
          } else {
            expect(same, isTrue);
          }
        }
      }
      expect(changed, greaterThan(20));
    });

    test('vira PNG de 48 x 48', () async {
      for (final rows in [...ecoSprites.values, neutralSprite]) {
        final png = await spriteToPng(rows);
        expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], reason: 'assinatura PNG');
        final header = ByteData.sublistView(Uint8List.fromList(png), 16, 24);
        expect((header.getUint32(0), header.getUint32(4)), (48, 48));
      }
    });
  });
}

int _firstIndexOf(List<String> rows, String ch) {
  for (var y = 0; y < 48; y++) {
    final x = rows[y].indexOf(ch);
    if (x >= 0) return (y * 48 + x) * 4;
  }
  throw StateError('sem $ch');
}

bool _eq(Uint8List a, Uint8List b, int i) => a[i] == b[i] && a[i + 1] == b[i + 1] && a[i + 2] == b[i + 2] && a[i + 3] == b[i + 3];
