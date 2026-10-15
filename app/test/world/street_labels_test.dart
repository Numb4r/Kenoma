import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/street_labels.dart';

VisualLine line(String? name, List<int> xy, {RoadClass c = RoadClass.principal}) => VisualLine(c, Int32List.fromList(xy), name: name);

void main() {
  group('trecho mais reto', () {
    test('uma reta é o trecho inteiro', () {
      final r = straightestRun([0, 0, 100, 0, 200, 0])!;
      expect((r.from, r.to, r.length), (0, 2, 200.0));
    });

    test('numa curva em L escolhe o braço mais longo', () {
      final r = straightestRun([0, 0, 50, 0, 50, 300])!;
      expect((r.from, r.to), (1, 2));
      expect(r.length, 300);
    });

    test('desvios pequenos não quebram o trecho, desvios grandes quebram', () {
      expect(straightestRun([0, 0, 100, 5, 200, 0])!.to, 2, reason: 'menos de 20°');
      expect(straightestRun([0, 0, 100, 100, 200, 0])!.to, 1, reason: '45° de desvio');
    });

    test('menos de dois pontos não tem trecho', () {
      expect(straightestRun([5, 5]), isNull);
      expect(straightestRun([]), isNull);
    });
  });

  group('pontos de rótulo do tile', () {
    // 2^6 = 64 células por tile z15, 4096 unidades: 64 unidades por célula.
    List<LabelSpot> spots(VisualTile t, {int perName = 2}) => labelSpotsOfTile(t, 10, 20, cellsPerTile: 64, extent: 4096, perName: perName);

    test('o rótulo fica no meio do trecho, em células z21, com a direção do trecho', () {
      final s = spots(VisualTile(lines: [line('Av. Brasil', [0, 0, 640, 0])], areas: const [])).single;
      expect(s.name, 'Av. Brasil');
      expect(s.x, closeTo(10 * 64 + 5, 1e-9));
      expect(s.y, closeTo(20 * 64, 1e-9));
      expect(s.angle, 0);
      expect(s.lengthCells, 10);
    });

    test('linhas sem nome e trechos curtos demais ficam de fora', () {
      final tile = VisualTile(lines: [line(null, [0, 0, 640, 0]), line('Curta', [0, 0, 10, 0])], areas: const []);
      expect(spots(tile), isEmpty);
    });

    test('no máximo dois por nome, os mais longos', () {
      final tile = VisualTile(lines: [
        line('Rua A', [0, 0, 128, 0]),
        line('Rua A', [0, 100, 640, 100]),
        line('Rua A', [0, 200, 320, 200]),
        line('Rua B', [0, 300, 192, 300]),
      ], areas: const []);
      final out = spots(tile);
      expect(out.where((s) => s.name == 'Rua A').map((s) => s.lengthCells), [10.0, 5.0]);
      expect(out.where((s) => s.name == 'Rua B'), hasLength(1));
    });
  });

  group('ângulo na tela', () {
    test('o texto nunca fica de cabeça para baixo', () {
      for (var w = -3.0; w <= 3.0; w += 0.37) {
        for (var r = -3.0; r <= 3.0; r += 0.41) {
          final a = labelScreenAngle(w, r);
          expect(a, inInclusiveRange(-math.pi / 2 - 1e-9, math.pi / 2 + 1e-9), reason: 'w=$w r=$r');
        }
      }
    });

    test('segue a rotação do mapa e vira para o lado certo', () {
      expect(labelScreenAngle(0, 0.3), closeTo(0.3, 1e-12));
      expect(labelScreenAngle(0, math.pi), closeTo(0, 1e-9), reason: 'meia volta: o texto desvira');
      expect(labelScreenAngle(0.2, 0.3), closeTo(0.5, 1e-12));
    });
  });

  group('escolha dos rótulos', () {
    LabelSpot at(String n, double x, double y, double len) => LabelSpot(name: n, x: x, y: y, angle: 0, lengthCells: len);
    List<PlacedLabel> place(List<LabelSpot> s, {double ppc = 20, double rot = 0}) => placeLabels(
          s,
          project: (x, y) => (x * ppc, y * ppc),
          textWidth: (n) => n.length * 6.0,
          pixelsPerCell: ppc,
          mapRotation: rot,
          viewWidth: 400,
          viewHeight: 800,
        );

    test('só entra o rótulo que cabe no trecho', () {
      // "Av. Longa" tem 54 px + 12 de folga: pede ao menos 66 px; a 20 px por célula, 4 células não bastam (80 px bastam).
      expect(place([at('Av. Longa', 5, 5, 3)]), isEmpty);
      expect(place([at('Av. Longa', 5, 5, 4)]), hasLength(1));
    });

    test('rótulos que se sobrepõem: fica o do trecho mais longo; os afastados ficam os dois', () {
      final out = place([at('Rua Um', 5, 5, 5), at('Rua Dois', 5.2, 5, 9), at('Rua Tres', 15, 15, 6)]);
      expect(out.map((p) => p.spot.name), ['Rua Dois', 'Rua Tres']);
    });

    test('o mesmo nome não se repete perto, mas se repete longe', () {
      final near = place([at('Rua Um', 3, 5, 6), at('Rua Um', 10, 5, 6)]); // 140 px de distância na tela: no limite
      final far = place([at('Rua Um', 3, 5, 6), at('Rua Um', 15, 5, 6)]);
      expect(far, hasLength(2));
      expect(near.length, lessThanOrEqualTo(2));
      expect(place([at('Rua Um', 3, 5, 6), at('Rua Um', 5, 5, 5)]), hasLength(1));
    });

    test('fora da tela não entra, e o máximo vale', () {
      expect(place([at('Rua Um', -50, 5, 6)]), isEmpty);
      final many = [for (var i = 0; i < 100; i++) at('R$i', (i % 10) * 3.0 + 1, (i ~/ 10) * 3.0 + 1, 8)];
      expect(place(many).length, lessThanOrEqualTo(40));
    });

    test('a ordem é a mesma de um quadro para o outro (nada pula)', () {
      final spots = [at('Rua Um', 5, 5, 5), at('Rua Dois', 15, 15, 9), at('Rua Tres', 5, 20, 7)];
      expect(place(spots).map((p) => p.spot.name), place(spots.reversed.toList()).map((p) => p.spot.name));
    });

    test('o ângulo do rótulo acompanha a rotação do mapa', () {
      expect(place([at('Rua Um', 5, 5, 6)], rot: 0.4).single.angle, closeTo(0.4, 1e-12));
    });
  });
}
