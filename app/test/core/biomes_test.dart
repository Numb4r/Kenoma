import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/biomes.dart';

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

  group('paleta do mapa (biomes.json)', () {
    final biomes = loadBiomes();

    test('cada bioma tem 3 tons, do mais escuro ao mais claro', () {
      expect(biomes.all.map((b) => b.key), ['void', 'urban', 'green', 'water', 'residential']);
      for (final b in biomes.all) {
        expect(b.palette, hasLength(3), reason: b.key);
        final luma = [for (final c in b.palette) _luma(c)];
        expect(luma[0], lessThan(luma[1]), reason: b.key);
        expect(luma[1], lessThan(luma[2]), reason: b.key);
      }
    });

    test('regra de arte: nada saturado, tudo frio, e os cinco biomas se distinguem', () {
      for (final b in biomes.all) {
        for (final c in b.palette) {
          expect(_saturation(c), lessThan(0.35), reason: '${b.key} #${c.toRadixString(16)} é saturado demais');
          final (r, g, bl) = _rgb(c);
          expect(bl, greaterThanOrEqualTo(r), reason: '${b.key}: azul não pode ficar abaixo do vermelho (paleta fria)');
          expect(bl + g + r, lessThan(3 * 140), reason: '${b.key}: nada claro a ponto de gritar no mapa');
        }
      }
      final bases = [for (final b in biomes.all) b.palette[1]];
      for (var i = 0; i < bases.length; i++) {
        for (var j = i + 1; j < bases.length; j++) {
          expect(_distance(bases[i], bases[j]), greaterThan(14), reason: '${biomes.all[i].key} x ${biomes.all[j].key}');
        }
      }
    });

    test('a cidade é cinza-índigo, o verde e a água são apagados', () {
      final urban = biomes.byId(1).palette[1];
      final (ur, ug, ub) = _rgb(urban);
      expect(ub, greaterThan(ur), reason: 'índigo: azul acima do vermelho');
      expect((ur - ug).abs(), lessThan(14));
      final (gr, gg, gb) = _rgb(biomes.byId(2).palette[1]);
      expect(gg, greaterThan(gr));
      expect(gg, greaterThan(gb), reason: 'verde');
      final (wr, wg, wb) = _rgb(biomes.byId(3).palette[1]);
      expect(wb, greaterThan(wg));
      expect(wb, greaterThan(wr), reason: 'azul');
    });

    test('os nomes da interface vêm de biomes.json', () {
      expect([for (final b in biomes.all) b.name], ['Vazio', 'Urbano', 'Verde', 'Água', 'Residencial']);
    });

    test('cor inválida em biomes.json é erro de dados', () {
      expect(
        () => BiomeDef.fromJson({'id': 9, 'key': 'x', 'name': 'X', 'priority': 1, 'palette': ['vermelho']}),
        throwsFormatException,
      );
    });
  });
}

(int, int, int) _rgb(int c) => ((c >> 16) & 255, (c >> 8) & 255, c & 255);

double _luma(int c) {
  final (r, g, b) = _rgb(c);
  return 0.299 * r + 0.587 * g + 0.114 * b;
}

double _saturation(int c) {
  final (r, g, b) = _rgb(c);
  final mx = [r, g, b].reduce((a, b) => a > b ? a : b) / 255, mn = [r, g, b].reduce((a, b) => a < b ? a : b) / 255;
  final l = (mx + mn) / 2;
  if (mx == mn) return 0;
  return (mx - mn) / (1 - (2 * l - 1).abs());
}

double _distance(int a, int b) {
  final (ar, ag, ab) = _rgb(a);
  final (br, bg, bb) = _rgb(b);
  return math.sqrt((ar - br) * (ar - br) + (ag - bg) * (ag - bg) + (ab - bb) * (ab - bb));
}
