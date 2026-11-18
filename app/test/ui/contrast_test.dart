import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/ui/colors.dart';
import 'package:kenoma/ui/kit.dart';
import 'package:kenoma/ui/tema.dart';

/// 0.26.0: o texto corrido sobre os painéis do kit tem contraste de pelo menos 4,5:1 (WCAG 2), nas combinações que as telas
/// usam: texto e texto mudo nos painéis, rótulos de botão na face do botão, e a etiqueta e o nome de cada tipo.
double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const panels = {'painel': kPanel, 'superfície 1': KCores.superficie1, 'fundo': KCores.fundo, 'superfície 2': KCores.superficie2};
  const face = Color(0xFF3D3357); // a face do botão (`button.png`)

  test('texto e texto mudo sobre todo painel', () {
    for (final p in panels.entries) {
      for (final t in {'texto': KCores.texto, 'kText': kText, 'mudo': KCores.textoMudo, 'kDim': kDim, 'sinal': kSignal, 'Véu': kVeil, 'Essência': kEssence}.entries) {
        expect(contrast(t.value, p.value), greaterThanOrEqualTo(4.5), reason: '${t.key} sobre ${p.key}');
      }
    }
  });

  test('rótulos na face do botão (o violeta e o cinza viram o tom claro)', () {
    for (final c in [kVeil, kDim, kText, kSignal, kEssence, KCores.veuClaro]) {
      expect(contrast(onButtonFace(c), face), greaterThanOrEqualTo(4.5), reason: 'rótulo $c');
    }
    expect(contrast(KCores.textoMudo, KCores.superficie2), greaterThanOrEqualTo(4.5), reason: 'botão desativado');
  });

  test('cada tipo: o nome no tom claro na etiqueta e a cor principal sobre o painel', () {
    for (final t in EcoType.values) {
      expect(contrast(typeColorLight(t), kTextOnFaceBackground), greaterThanOrEqualTo(4.5), reason: '${t.name} na etiqueta');
      expect(contrast(typeColor(t), KCores.superficie1), greaterThanOrEqualTo(4.5), reason: '${t.name} no painel');
    }
  });
}
