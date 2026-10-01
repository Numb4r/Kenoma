/// Efeito da Água na onda: espuma na crista quando o aviso de virada toca.
library;

import '../signal.dart';
import 'fx_params.dart';
import 'particle.dart';
import 'wave_geometry.dart';

/// Espuma sobre a crista [u]. [amplitude] (a maré, vezes o quanto falta assentar) escala a altura
/// das partículas, em unidades da amplitude da onda.
class FoamFx {
  const FoamFx(this.u, this.amplitude, this.particles);

  final double u;
  final double amplitude;
  final List<FxParticle> particles;
}

class WaterFx {
  WaterFx(this.signal) : _swells = [for (final c in signal.cues) if (c.kind == CueKind.waterSwell) c.at];

  final TargetSignal signal;
  final List<double> _swells;

  /// A espuma ativa no instante [t]. [scroll] é a rolagem da onda na tela (`waveScroll`): a espuma
  /// fica na crista, que anda junto com a rolagem.
  List<FoamFx> at(double t, double scroll) {
    final out = <FoamFx>[];
    for (var i = 0; i < _swells.length; i++) {
      final age = t - _swells[i];
      if (age < 0) break;
      if (age >= waterFoamS) continue;
      final crests = crestUs(signal.frequencyAt(t), scroll);
      if (crests.isEmpty) continue;
      final u = nearestTo(crests, 0.25 + 0.5 * hash01(i, 11));
      final p = age / waterFoamS;
      final settle = 1 - p;
      final tide = signal.tideAt(t);
      out.add(FoamFx(u, tide * settle, [
        for (var j = 0; j < waterFoamCount; j++)
          FxParticle(
            (hash01(i, 40 + j) - 0.5) * 0.07 * (0.5 + p),
            (0.1 + 0.4 * hash01(i, 80 + j)) * tide * settle,
            0.4 + 0.6 * hash01(i, 120 + j),
            settle,
          ),
      ]));
    }
    return out;
  }
}
