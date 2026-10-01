/// Efeito do Fogo na onda: brasa no aviso, chama no pico e cinzas. A fronteira da queima e as duas
/// ondas (real à direita, isca à esquerda) vêm de `TargetSignal.fireSplitAt`.
/// Sabe onde e quando; quem desenha só pinta o que vem daqui.
library;

import 'dart:math' as math;

import '../signal.dart';
import 'fx_params.dart';
import 'particle.dart';
import 'wave_geometry.dart';

/// Brasa acesa no ponto [u] da onda. [glow] sobe de 0 a 1 até o pico.
class EmberFx {
  const EmberFx(this.u, this.glow);

  final double u;
  final double glow;
}

/// Chama queimando o ponto [u]. [height] em unidades da amplitude da onda.
class FlameFx {
  const FlameFx(this.u, this.height, this.halfWidth);

  final double u;
  final double height;
  final double halfWidth;
}

/// Cinzas de um pico, ancoradas em [u].
class AshFx {
  const AshFx(this.u, this.particles);

  final double u;
  final List<FxParticle> particles;
}

class FireFxState {
  const FireFxState({this.embers = const [], this.flames = const [], this.ashes = const [], this.split});

  static const none = FireFxState();

  final List<EmberFx> embers;
  final List<FlameFx> flames;
  final List<AshFx> ashes;

  /// A onda partida em duas. `null` antes do primeiro pico.
  final FireSplit? split;

  bool get isEmpty => embers.isEmpty && flames.isEmpty && ashes.isEmpty && split == null;
}

class FireFx {
  FireFx(this.signal)
      : _kicks = signal.kickTimes,
        _burns = signal.burnUs,
        _lead = signal.fireWarningLeadS;

  final TargetSignal signal;
  final List<double> _kicks;
  final List<double> _burns;
  final double _lead;

  /// O que desenhar no instante [t] da sintonia.
  FireFxState at(double t) {
    final embers = <EmberFx>[];
    final flames = <FlameFx>[];
    final ashes = <AshFx>[];
    final halfW = lerpPair(fireFlameHalfWidth, signal.intensity);
    for (var i = 0; i < _kicks.length; i++) {
      final age = t - _kicks[i];
      if (age > fireBurnS + fireAshS) continue;
      if (age < -_lead) break; // os picos vêm em ordem
      final u = _burns[i];
      if (age < 0) {
        embers.add(EmberFx(u, (1 + age / _lead).clamp(0.0, 1.0)));
      } else {
        if (age < fireBurnS) {
          final p = age / fireBurnS;
          // A chama sobe depressa e baixa devagar. A intensidade manda no tamanho.
          final h = lerpPair(fireFlameHeight, signal.intensity) * math.pow(math.sin(math.pi * math.pow(p, 0.6)), 0.8);
          flames.add(FlameFx(u, h.toDouble(), halfW));
        }
        final p = (age / (fireBurnS + fireAshS)).clamp(0.0, 1.0);
        ashes.add(AshFx(u, _ash(i, p, halfW)));
      }
    }
    return FireFxState(embers: embers, flames: flames, ashes: ashes, split: signal.fireSplitAt(t));
  }

  List<FxParticle> _ash(int index, double p, double halfW) => [
        for (var j = 0; j < fireAshCount; j++)
          FxParticle(
            (hash01(index, 100 + j) - 0.5) * 2 * halfW * 1.4,
            p * (0.25 + 0.5 * hash01(index, 200 + j)),
            0.4 + 0.6 * hash01(index, 300 + j),
            1 - p,
          ),
      ];
}
