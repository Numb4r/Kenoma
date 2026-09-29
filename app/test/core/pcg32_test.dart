import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

void main() {
  test('srandom(42, 54): vetor da referência', () {
    final rng = Pcg32(42, 54);
    expect([rng.next(), rng.next(), rng.next()], [0xa15c02b7, 0x7b47f409, 0xba1d3330]);
  });

  test('semeado com h_0 da spec e a sequência KENOMA', () {
    final rng = Pcg32(0x90a9f55334e3a1bc, saltKenoma);
    expect([rng.next(), rng.next(), rng.next()], [937126716, 1949151193, 2853980563]);
  });

  test('mesma semente, mesma sequência', () {
    final a = Pcg32(123, saltKenoma);
    final b = Pcg32(123, saltKenoma);
    expect([for (var i = 0; i < 50; i++) a.next()], [for (var i = 0; i < 50; i++) b.next()]);
  });

  test('saídas cabem em 32 bits sem sinal', () {
    final rng = Pcg32(0x90a9f55334e3a1bc, saltKenoma);
    for (var i = 0; i < 1000; i++) {
      expect(rng.next(), inInclusiveRange(0, 0xffffffff));
    }
  });

  test('float é next() / 2^32 e fica em [0, 1)', () {
    final a = Pcg32(42, 54);
    final b = Pcg32(42, 54);
    expect(a.nextFloat(), b.next() / 4294967296.0);
    final rng = Pcg32(7, 7);
    for (var i = 0; i < 1000; i++) {
      expect(rng.nextFloat(), allOf(greaterThanOrEqualTo(0.0), lessThan(1.0)));
    }
  });

  test('inteiro é (next() * n) >>> 32 e fica em [0, n)', () {
    final a = Pcg32(42, 54);
    final b = Pcg32(42, 54);
    expect(a.nextInt(1200), (b.next() * 1200) >>> 32);
    final rng = Pcg32(9, 9);
    for (var i = 0; i < 1000; i++) {
      expect(rng.nextInt(5), inInclusiveRange(0, 4));
    }
  });

  test('inteiro cobre todo o intervalo', () {
    final rng = Pcg32(1, 1);
    expect({for (var i = 0; i < 500; i++) rng.nextInt(5)}, {0, 1, 2, 3, 4});
  });
}
