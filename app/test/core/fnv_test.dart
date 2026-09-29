import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/fnv.dart';

void main() {
  group('FNV-1a 64', () {
    test('vetores da spec: string vazia e "a"', () {
      expect(fnv1a64Bytes(const []), 0xcbf29ce484222325);
      expect(fnv1a64Bytes('a'.codeUnits), 0xaf63dc4c8601ec8c);
    });

    test('lista vazia de campos dá o offset', () {
      expect(fnv1a64(const []), fnvOffset);
    });

    test('campo é serializado como 8 bytes little-endian', () {
      expect(fnv1a64([1]), fnv1a64Bytes([1, 0, 0, 0, 0, 0, 0, 0]));
      expect(fnv1a64([0x0102030405060708]), fnv1a64Bytes([8, 7, 6, 5, 4, 3, 2, 1]));
    });

    test('campo negativo usa complemento de dois', () {
      expect(fnv1a64([-1]), fnv1a64Bytes(List.filled(8, 0xff)));
    });

    test('a ordem dos campos importa', () {
      expect(fnv1a64([1, 2]), isNot(fnv1a64([2, 1])));
    });
  });

  group('salts', () {
    test('valores da spec', () {
      expect(salt('SPWN'), 0x4E575053);
      expect(salt('OFFS'), 0x5346464F);
      expect(salt('UID_'), 0x5F444955);
      expect(salt('KENOMA'), 0x414D4F4E454B);
    });

    test('constantes batem com o cálculo', () {
      expect(saltSpwn, salt('SPWN'));
      expect(saltOffs, salt('OFFS'));
      expect(saltUid, salt('UID_'));
      expect(saltKenoma, salt('KENOMA'));
    });
  });

  group('hashMod', () {
    test('usa os 32 bits de cima, também com o bit 63 ligado (int negativo em Dart)', () {
      const h = 0xaf63dc4c8601ec8c;
      expect(h, isNegative);
      expect(hashMod(h, 1200), 60);
      expect(hashMod(h, 7), 6);
      expect(hashMod(0x90a9f55334e3a1bc, 1200), 1091);
    });

    test('resultado sempre em [0, n)', () {
      for (var i = 0; i < 1000; i++) {
        final r = hashMod(fnv1a64([i]), 1200);
        expect(r, inInclusiveRange(0, 1199));
      }
    });
  });

  test('hex64 trata o valor como sem sinal, com 16 dígitos', () {
    expect(hex64(0xaf63dc4c8601ec8c), '0xaf63dc4c8601ec8c');
    expect(hex64(0x8eea7d7ebe0ef0), '0x008eea7d7ebe0ef0');
    expect(hex64(0), '0x0000000000000000');
  });
}
