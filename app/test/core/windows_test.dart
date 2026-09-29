import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/windows.dart';

import '../support/fixtures.dart';

void main() {
  test('vetor da spec: deslocamento 534 e janela 1491667', () {
    expect(windowOffset(vectorSeed, vectorCellX, vectorCellY), 534);
    expect(windowIndex(vectorSeed, vectorCellX, vectorCellY, vectorTime), vectorWindow);
  });

  test('deslocamento fica em [0, 1200)', () {
    for (var dx = 0; dx < 50; dx++) {
      expect(windowOffset(vectorSeed, vectorCellX + dx, vectorCellY), inInclusiveRange(0, 1199));
    }
  });

  test('a janela troca exatamente a cada 1200 s, no instante deslocado', () {
    const offset = 534;
    // A célula do vetor troca de janela quando (t + 534) é múltiplo de 1200.
    final next = (vectorWindow + 1) * windowSeconds - offset;
    expect(windowIndex(vectorSeed, vectorCellX, vectorCellY, next - 1), vectorWindow);
    expect(windowIndex(vectorSeed, vectorCellX, vectorCellY, next), vectorWindow + 1);
  });

  test('células vizinhas trocam de janela em momentos diferentes', () {
    final offsets = {
      for (var dx = -1; dx <= 1; dx++)
        for (var dy = -1; dy <= 1; dy++) windowOffset(vectorSeed, vectorCellX + dx, vectorCellY + dy),
    };
    expect(offsets.length, greaterThanOrEqualTo(5), reason: '9 vizinhas não podem trocar todas juntas');

    // No instante em que a célula do vetor troca, alguma vizinha ainda está na janela antiga.
    final t = (vectorWindow + 1) * windowSeconds - 534;
    final windows = {
      for (var dx = -1; dx <= 1; dx++)
        for (var dy = -1; dy <= 1; dy++) windowIndex(vectorSeed, vectorCellX + dx, vectorCellY + dy, t),
    };
    expect(windows.length, greaterThan(1));
  });

  test('a seed muda o deslocamento', () {
    expect(windowOffset(vectorSeed + 1, vectorCellX, vectorCellY), isNot(534));
  });
}
