/// Efeito do Fogo na onda: brasa no aviso, chama no pico e cinzas. A fronteira da queima e os
/// trechos (real à direita, iscas cinza à esquerda) vêm de `TargetSignal.fireSplitAt`. Os efeitos
/// rolam para a esquerda com a onda, na velocidade da fronteira.
/// Sabe onde e quando; quem desenha só pinta o que vem daqui.
library;

import 'dart:math' as math;

import '../fire_wave.dart';
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
      : _lead = signal.fireWarningLeadS,
        _speed = signal.balance.signal.fire.boundaryUPerS;

  final TargetSignal signal;
  final double _lead;
  final double _speed;

  /// O que desenhar no instante [t] da sintonia.
  FireFxState at(double t) {
    final embers = <EmberFx>[];
    final flames = <FlameFx>[];
    final ashes = <AshFx>[];
    final halfW = lerpPair(fireFlameHalfWidth, signal.intensity);
    final kicks = signal.fire.kicks;
    for (var i = 0; i < kicks.length; i++) {
      final age = t - kicks[i].at;
      if (age > fireBurnS + fireAshS) continue;
      if (age < -_lead) break; // os picos vêm em ordem
      if (age < 0) {
        // A brasa fica no ponto da onda que chegará à queima, e rola com ela.
        embers.add(EmberFx(kicks[i].burnU + _speed * (-age), (1 + age / _lead).clamp(0.0, 1.0)));
        continue;
      }
      final u = signal.fireBoundaryUAt(i, t);
      if (u <= 0) continue; // já saiu da tela
      if (age < fireBurnS) {
        final p = age / fireBurnS;
        // A chama sobe depressa e baixa devagar. A intensidade manda no tamanho.
        final h = lerpPair(fireFlameHeight, signal.intensity) * math.pow(math.sin(math.pi * math.pow(p, 0.6)), 0.8);
        flames.add(FlameFx(u, h.toDouble(), halfW));
      }
      final p = (age / (fireBurnS + fireAshS)).clamp(0.0, 1.0);
      ashes.add(AshFx(u, _ash(i, p, halfW)));
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
