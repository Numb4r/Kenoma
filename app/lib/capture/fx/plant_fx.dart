/// Efeito da Planta: uma folha por broto na onda e as raízes fincadas no dial.
library;

import 'dart:math' as math;

import '../plant_roots.dart';
import '../signal.dart';
import 'fx_params.dart';
import 'wave_geometry.dart';

/// Folha nascida num broto, no ponto [u] da onda. [size] cresce de 0 a 1. [side] é -1 ou 1.
class LeafFx {
  const LeafFx(this.u, this.size, this.side);

  final double u;
  final double size;
  final double side;
}

/// Raiz fincada na faixa `[lo, hi]` do eixo do dial. [growth] vai de 0 a 1 logo depois de fincada.
/// [branches] são ramos: posição na faixa (0 a 1), comprimento (0 a 1) e lado (-1 ou 1).
class RootFx {
  const RootFx(this.lo, this.hi, this.growth, this.branches);

  final double lo;
  final double hi;
  final double growth;
  final List<RootBranch> branches;
}

class RootBranch {
  const RootBranch(this.along, this.length, this.side);

  final double along;
  final double length;
  final double side;
}

class PlantFxState {
  const PlantFxState({this.leaves = const [], this.roots = const []});

  static const none = PlantFxState();

  final List<LeafFx> leaves;

  /// As raízes vivas, da mais antiga à mais nova.
  final List<RootFx> roots;
}

class PlantFx {
  PlantFx(this.signal) : _buds = [for (final c in signal.cues) if (c.kind == CueKind.plantPulse) c.at];

  final TargetSignal signal;
  final List<double> _buds;

  /// Ponto da onda do broto [i]: espalhado pela razão áurea, estável.
  static double leafU(int i) => 0.12 + 0.76 * ((i * 0.6180339887) % 1.0);

  PlantFxState at(double t) {
    final leaves = <LeafFx>[];
    var born = 0;
    while (born < _buds.length && _buds[born] <= t) {
      born++;
    }
    for (var i = math.max(0, born - plantMaxLeaves); i < born; i++) {
      leaves.add(LeafFx(leafU(i), ((t - _buds[i]) / plantLeafGrowS).clamp(0.0, 1.0), i.isEven ? 1 : -1));
    }
    return PlantFxState(leaves: leaves, roots: [for (final r in signal.rootsAt(t)) _root(r, t)]);
  }

  RootFx _root(PlantRoot r, double t) {
    final id = (r.at * 1000).round(); // estável enquanto a raiz existe
    final n = math.max(2, ((r.hi - r.lo) * 60).ceil());
    return RootFx(r.lo, r.hi, ((t - r.at) / plantRootGrowS).clamp(0.0, 1.0), [
      for (var j = 0; j < n; j++)
        RootBranch((j + 0.5 + 0.4 * (hash01(id, j) - 0.5)) / n, 0.4 + 0.6 * hash01(id, 50 + j), hash01(id, 90 + j) < 0.5 ? -1 : 1),
    ]);
  }
}
