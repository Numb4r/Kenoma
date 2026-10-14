import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';

import '../support/fixtures.dart';

void main() {
  test('vetor da spec: KENOMA-TESTE', () {
    expect(seedGlobal(vectorSeedCode), vectorSeed);
  });

  test('normalização tira espaços e hífens e põe em maiúsculas', () {
    expect(normalizeSeedCode(' kenoma - teste '), 'KENOMATESTE');
    expect(normalizeSeedCode('kenoma-teste'), 'KENOMATESTE');
    expect(normalizeSeedCode('KENOMA TESTE'), 'KENOMATESTE');
  });

  test('variações do mesmo código dão a mesma seed', () {
    for (final variant in ['kenoma-teste', 'KENOMA TESTE', 'KenomaTeste', ' kenoma teste ']) {
      expect(seedGlobal(variant), vectorSeed, reason: variant);
    }
  });

  test('códigos diferentes dão seeds diferentes', () {
    expect(seedGlobal('KENOMA-TESTF'), isNot(vectorSeed));
  });

  test('código novo: XXXXX-XXXXX em base32 de Crockford, e vira uma seed estável', () {
    var i = 0;
    final code = generateGroupCode((n) => (i++ * 7) % n);
    expect(code, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$')));
    expect(seedGlobal(code), seedGlobal(code.toLowerCase().replaceAll('-', ' ')));
  });
}
