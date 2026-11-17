import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/city/city_upright.dart' show roofTextureMatrix;
import 'package:kenoma/ui/city/turn_category.dart';
import 'package:kenoma/world/style_advisor.dart';

/// 0.22.2: a categoria de giro de cada tipo de objeto, a textura do telhado presa ao contorno, a troca automática para o
/// Simplificado acima de 120 m e as ruas finas que somem de longe.
void main() {
  test('cada tipo de objeto tem a categoria de giro da regra: chão gira, o que tem altura fica de pé', () {
    for (final k in ['rua', 'calçada', 'faixa de pedestre', 'lote e quintal', 'sombra', 'marca do clima', 'telhado']) {
      expect(objectTurn[k], Turn.ground, reason: k);
    }
    for (final k in ['parede', 'janela', 'caixa d\'água / ar / antena', 'letreiro', 'árvore', 'ipê', 'poste', 'ponto de ônibus', 'banca', 'Eco', 'Fagulha', 'material', 'Conjurador', 'passante']) {
      expect(objectTurn[k], Turn.upright, reason: k);
    }
    // As exceções que esperam a decisão do dono: veículos e nomes de rua acompanham o rumo.
    expect([for (final e in objectTurn.entries) if (e.value == Turn.heading) e.key]..sort(), ['barco', 'carro', 'ciclista', 'nome de rua', 'ônibus']);
    for (final k in ['lamp', 'bus_stop', 'newsstand', 'tree_a', 'ipe_purple']) {
      expect(objectTurn[propKindName(k)], Turn.upright, reason: k);
    }
    expect(objectTurn[propKindName('crosswalk')], Turn.ground);
  });

  test('a textura do telhado fica na aresta mais longa e gira e anda exatamente com o contorno', () {
    List<ui.Offset> rect(double ang, ui.Offset at) {
      final c = math.cos(ang), s = math.sin(ang);
      ui.Offset p(double x, double y) => at + ui.Offset(x * c - y * s, x * s + y * c);
      return [p(0, 0), p(30, 0), p(30, 12), p(0, 12)]; // a aresta mais longa é a primeira (30)
    }

    for (final ang in [0.0, 0.5, 1.9, -2.4]) {
      final at = ui.Offset(40 + ang * 10, 70 - ang * 7);
      final m = roofTextureMatrix(rect(ang, at));
      expect(math.atan2(m[1], m[0]), closeTo(ang, 1e-9), reason: 'gira com o contorno ($ang)');
      expect((m[12], m[13]), (at.dx, at.dy), reason: 'presa no começo da aresta, anda com o prédio');
    }
  });

  test('acima de 120 m o mapa passa para o Simplificado e volta abaixo de 112 m, sem ficar trocando no limite', () {
    var auto = false;
    final seen = <bool>[];
    for (final w in [80.0, 119.0, 121.0, 118.0, 113.0, 111.0, 250.0, 115.0, 100.0]) {
      auto = autoSimple(widthM: w, wasAuto: auto);
      seen.add(auto);
    }
    expect(seen, [false, false, true, true, true, false, true, true, false]);
    expect(kWideZoomMaxM, 250);
  });

  test('de longe as ruas finas somem antes das avenidas', () {
    expect(hiddenRoadClasses(80), isEmpty);
    expect(hiddenRoadClasses(150), {'pedestrian'});
    expect(hiddenRoadClasses(250), {'pedestrian', 'local'});
    expect(hiddenRoadClasses(600), {'pedestrian', 'local', 'secondary'});
  });
}
