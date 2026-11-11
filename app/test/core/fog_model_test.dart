import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/fog_model.dart';

void main() {
  const fog = FogModel();

  test('neblina mais densa no vale que no morro, com vetores fixos', () {
    // O ponto 15 m abaixo da média do anel é fundo de vale; 15 m acima, alto de morro; igual, meio-termo.
    const mean = 1000 * 16;
    expect(fog.lowness(mean - 150 * 16, mean * 8, 0), 1.0);
    expect(fog.lowness(mean + 150 * 16, mean * 8, 0), 0.0);
    expect(fog.lowness(mean, mean * 8, 0), 0.5);
    expect(fog.lowness(mean - 75 * 16, mean * 8, 0), 0.75);
    expect(fog.lowness(mean, mean * 8, 1), 0.75, reason: 'a beira da água conta como baixada');
    expect(fog.density(1, -5), 1.0);
    expect(fog.density(0, -5), closeTo(0.3, 1e-12));
    expect(fog.density(1, -5), greaterThan(fog.density(0.5, -5)));
  });

  test('a visão dos Ecos: menos no vale, mais no morro', () {
    expect(fog.viewMult(1, 0), closeTo(0.6, 1e-12));
    expect(fog.viewMult(0, 0), 1.6);
    expect(fog.viewMult(0.5, 0), closeTo(1.1, 1e-12));
    // Com a visão de 60 m da Neblina: 36 m no vale, 96 m no morro.
    expect(60 * fog.viewMult(1, 0), closeTo(36, 1e-9));
    expect(60 * fog.viewMult(0, 0), closeTo(96, 1e-9));
  });

  test('o sol da manhã desfaz a neblina, pela altura dele', () {
    expect(fog.cleared(-10), 0);
    expect(fog.cleared(8), 0);
    expect(fog.cleared(19), 0.5);
    expect(fog.cleared(30), 1);
    expect(fog.cleared(60), 1);
    expect(fog.density(1, 19), 0.5);
    expect(fog.density(1, 30), 0);
    expect(fog.viewMult(1, 30), 2.5);
    expect(fog.viewMult(1, 19), closeTo(1.55, 1e-12));
    for (var a = -10.0; a < 40; a += 1) {
      expect(fog.viewMult(1, a + 1), greaterThanOrEqualTo(fog.viewMult(1, a)), reason: 'nunca piora com o sol subindo');
    }
  });

  test('lê os números da época', () {
    final f = FogModel.fromJson({'climates': ['fog'], 'valley_view': 0.5, 'span_dm': 100});
    expect(f.climates, {'fog'});
    expect(f.valleyView, 0.5);
    expect(f.spanDm, 100);
    expect(f.hillView, 1.6);
  });
}
