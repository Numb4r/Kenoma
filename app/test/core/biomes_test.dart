import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

// ids de shared/biomes.json
const void_ = 0, urban = 1, green = 2, water = 3, residential = 4;

void main() {
  final biomes = loadBiomes();

  test('lê os cinco biomas com as prioridades da spec', () {
    expect([for (final id in [void_, urban, green, water, residential]) biomes.byId(id).priority],
        [0, 2, 3, 4, 1]);
  });

  test('Vazio conta como Residencial nas tabelas de spawn', () {
    expect(biomes.spawnKey(void_), 'residential');
    expect(biomes.spawnKey(urban), 'urban');
    expect(biomes.spawnKey(water), 'water');
  });

  group('bioma da célula de spawn (moda das 2 x 2)', () {
    test('maioria vence, mesmo com prioridade menor', () {
      expect(biomes.spawnCellBiome([residential, residential, residential, water]), residential);
      expect(biomes.spawnCellBiome([void_, void_, void_, green]), void_);
      expect(biomes.spawnCellBiome([urban, green, urban, water]), urban, reason: '2 contra 1 contra 1');
    });

    test('empate 2 contra 2 sai pela maior prioridade, em qualquer ordem das células', () {
      // Urbano (2) contra Residencial (1): Urbano.
      for (final quad in [
        [urban, urban, residential, residential],
        [residential, urban, residential, urban],
        [urban, residential, residential, urban],
        [residential, residential, urban, urban],
      ]) {
        expect(biomes.spawnCellBiome(quad), urban, reason: '$quad');
      }
      // Verde (3) contra Urbano (2): Verde. Água (4) contra Verde (3): Água.
      expect(biomes.spawnCellBiome([urban, green, urban, green]), green);
      expect(biomes.spawnCellBiome([green, water, water, green]), water);
      // Vazio (0) perde para qualquer outro.
      expect(biomes.spawnCellBiome([void_, residential, void_, residential]), residential);
    });

    test('empate 1-1-1-1 vence a maior prioridade', () {
      expect(biomes.spawnCellBiome([void_, urban, green, residential]), green);
      expect(biomes.spawnCellBiome([void_, urban, green, water]), water);
      expect(biomes.spawnCellBiome([void_, urban, residential, void_]), void_, reason: 'Vazio 2 contra 1 contra 1');
    });

    test('quatro iguais', () {
      expect(biomes.spawnCellBiome([green, green, green, green]), green);
    });

    test('bioma desconhecido é erro', () {
      expect(() => biomes.spawnCellBiome([9, 9, 9, 9]), throwsStateError);
      expect(() => biomes.spawnCellBiome([9, 9, 1, 1]), throwsStateError);
    });
  });
}
