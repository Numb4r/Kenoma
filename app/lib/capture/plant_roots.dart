/// Planta: a cada broto uma raiz é fincada numa faixa fixa do eixo do dial, perto da frequência em que
/// o sinal está naquele momento. As raízes ficam paradas até o fim da sintonia, e a mais antiga some
/// quando passa do limite. O sinal continua a crescer e atravessa as raízes; com o dial dentro de uma,
/// a sintonia é interrompida (a sessão decide).
library;

import 'tuning_balance.dart';

/// Uma raiz: a faixa `[lo, hi]` do eixo do dial, fincada no instante [at].
class PlantRoot {
  const PlantRoot(this.at, this.center, this.halfWidth);

  final double at;
  final double center;
  final double halfWidth;

  double get lo => (center - halfWidth).clamp(0.0, 1.0);
  double get hi => (center + halfWidth).clamp(0.0, 1.0);

  bool contains(double dial) => dial >= lo && dial <= hi;
}

class PlantRoots {
  const PlantRoots(this.roots, this.maxRoots);

  /// Sem raízes: fora da Planta ou sem resistência.
  static const none = PlantRoots([], 0);

  /// [times] são os instantes dos brotos e [draws] um sorteio em `[0, 1)` por broto. [frequencyAt] é o
  /// sinal: cada raiz nasce perto da frequência dele no broto, a até `root_jitter` para cada lado.
  factory PlantRoots.build({
    required List<double> times,
    required List<double> draws,
    required PlantBalance plant,
    required double intensity,
    required double Function(double t) frequencyAt,
  }) {
    final width = lerpRange(plant.rootWidth, intensity);
    return PlantRoots([
      for (var i = 0; i < times.length; i++)
        PlantRoot(times[i], frequencyAt(times[i]) + (2 * draws[i] - 1) * plant.rootJitter, width / 2),
    ], lerpRange(plant.maxRoots, intensity).round());
  }

  /// Todas as raízes que a sintonia fincará, em ordem.
  final List<PlantRoot> roots;

  /// Quantas existem ao mesmo tempo.
  final int maxRoots;

  /// Quantas já foram fincadas em [t].
  int _plantedAt(double t) {
    var n = 0;
    while (n < roots.length && roots[n].at <= t) {
      n++;
    }
    return n;
  }

  /// As raízes vivas em [t]: as últimas [maxRoots] fincadas, da mais antiga à mais nova.
  List<PlantRoot> activeAt(double t) {
    final n = _plantedAt(t);
    return roots.sublist(n > maxRoots ? n - maxRoots : 0, n);
  }

  /// Se o dial está dentro de alguma raiz viva em [t].
  bool dialInRoot(double dial, double t) {
    final n = _plantedAt(t);
    for (var i = n > maxRoots ? n - maxRoots : 0; i < n; i++) {
      if (roots[i].contains(dial)) return true;
    }
    return false;
  }
}
