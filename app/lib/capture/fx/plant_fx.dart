/// Efeito da Planta: uma folha por broto na onda e raízes nas bordas da janela de alinhamento.
library;

import 'dart:math' as math;

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

/// Raiz que cresce de uma borda da janela. Ocupa a faixa de frequência de [fromF] (a borda original)
/// até [toF] (a borda de agora). [branches] são ramos: posição na faixa (0 a 1), comprimento (0 a 1)
/// e lado (-1 ou 1).
class RootFx {
  const RootFx(this.fromF, this.toF, this.branches);

  final double fromF;
  final double toF;
  final List<RootBranch> branches;
}

class RootBranch {
  const RootBranch(this.along, this.length, this.side);

  final double along;
  final double length;
  final double side;
}

class PlantFxState {
  const PlantFxState({this.leaves = const [], this.roots = const [], this.closed = 0});

  static const none = PlantFxState();

  final List<LeafFx> leaves;

  /// As duas raízes (borda de baixo e de cima da janela). Vazio enquanto a janela não fechou.
  final List<RootFx> roots;

  /// Quanto da janela já fechou, de 0 a 1 (1 = no piso).
  final double closed;
}

class PlantFx {
  PlantFx(this.signal) : _buds = [for (final c in signal.cues) if (c.kind == CueKind.plantPulse) c.at];

  final TargetSignal signal;
  final List<double> _buds;

  /// Ponto da onda do broto [i]: espalhado pela razão áurea, estável.
  static double leafU(int i) => 0.12 + 0.76 * ((i * 0.6180339887) % 1.0);

  /// [tolerance] é a tolerância de agora, com o fator da Planta já aplicado. As raízes ocupam o que
  /// a janela já perdeu, na mesma proporção em que ela fechou.
  PlantFxState at(double t, {required double target, required double tolerance}) {
    final factor = signal.toleranceFactorAt(t);
    final floor = signal.balance.signal.plant.toleranceFloor;
    final room = 1 - floor;
    final closed = room <= 0 ? 0.0 : ((1 - factor) / room).clamp(0.0, 1.0);

    final leaves = <LeafFx>[];
    var born = 0;
    while (born < _buds.length && _buds[born] <= t) {
      born++;
    }
    for (var i = math.max(0, born - plantMaxLeaves); i < born; i++) {
      leaves.add(LeafFx(leafU(i), ((t - _buds[i]) / plantLeafGrowS).clamp(0.0, 1.0), i.isEven ? 1 : -1));
    }

    final roots = <RootFx>[];
    if (closed > 0 && factor > 0) {
      final start = tolerance / factor; // a tolerância de antes de a Planta fechar a janela
      roots
        ..add(_root(0, target - start, target - tolerance, closed))
        ..add(_root(1, target + start, target + tolerance, closed));
    }
    return PlantFxState(leaves: leaves, roots: roots, closed: closed);
  }

  RootFx _root(int edge, double from, double to, double closed) {
    final n = math.max(1, (closed * plantMaxBranches).ceil());
    return RootFx(from.clamp(0.0, 1.0), to.clamp(0.0, 1.0), [
      for (var j = 0; j < n; j++)
        RootBranch((j + 0.5 + 0.4 * (hash01(edge, j) - 0.5)) / n, 0.4 + 0.6 * hash01(edge, 50 + j), hash01(edge, 90 + j) < 0.5 ? -1 : 1),
    ]);
  }
}
