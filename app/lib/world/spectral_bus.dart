/// O Ônibus Espectral passando de verdade pelos pontos (0.24.5, docs/GDD.md, "Ônibus nos pontos"): chega no horário de
/// cada ponto que a 0.24.2 já calcula ([spectralBusNext]), para, deixa ou leva um passageiro espectral que some na
/// calçada, e segue. Igual para o grupo (só a seed, o ponto e o tempo), sem recompensa e sem levar o jogador. Dart puro.
library;

import '../core/fnv.dart';
import 'map_touch.dart';

enum SpectralPhase { arriving, stopped, leaving }

/// O passageiro da parada: desce (aparece na porta e anda até a calçada) ou embarca (aparece na calçada e entra).
enum SpectralRider { alights, boards }

/// Uma passagem: quando chega ([arriveUtc]), a fase, onde o ônibus está ao longo da rua em metros (negativo antes do ponto,
/// zero parado nele, positivo depois) e o passageiro desta parada.
typedef SpectralPass = ({int arriveUtc, SpectralPhase phase, double alongM, SpectralRider rider});

/// A passagem do Ônibus Espectral pelo ponto [stopKey] no instante [t] (segundos UTC, com fração), ou `null` se ele não
/// está à vista ali agora. Freia até o ponto, fica [TouchBalance.busDwellS] parado e acelera para longe.
SpectralPass? spectralBusAt({required int seed, required int stopKey, required double t, required TouchBalance b}) {
  final after = (t - b.busDwellS - b.busLeaveS).floor();
  final a = spectralBusNext(seed: seed, stopKey: stopKey, t: after, b: b, localHourOf: (_) => 12).utc;
  final rider = (fnv1a64([seed, stopKey, a, 0x70]) >>> 32).isEven ? SpectralRider.alights : SpectralRider.boards;
  final dt = t - a;
  if (dt < -b.busApproachS) return null;
  if (dt < 0) {
    final u = 1 + dt / b.busApproachS; // 0 longe, 1 no ponto
    return (arriveUtc: a, phase: SpectralPhase.arriving, alongM: -b.busRunM * (1 - u) * (1 - u), rider: rider);
  }
  if (dt <= b.busDwellS) return (arriveUtc: a, phase: SpectralPhase.stopped, alongM: 0, rider: rider);
  final v = (dt - b.busDwellS) / b.busLeaveS;
  if (v > 1) return null;
  return (arriveUtc: a, phase: SpectralPhase.leaving, alongM: b.busRunM * v * v, rider: rider);
}

/// O passageiro espectral [dt] segundos depois da chegada: o quanto já andou entre a porta (0) e a calçada (1), e a
/// opacidade. `null`: não está à vista. Quem desce sai da porta logo depois de parar e some na calçada; quem embarca
/// aparece na calçada antes da chegada e some na porta.
({double t, double alpha})? spectralRiderAt(SpectralRider r, double dt, TouchBalance b) {
  switch (r) {
    case SpectralRider.alights:
      if (dt < 1 || dt > 6) return null;
      final walk = ((dt - 1) / 2.5).clamp(0.0, 1.0);
      return (t: walk, alpha: dt < 3.5 ? 1 : 1 - (dt - 3.5) / 2.5);
    case SpectralRider.boards:
      if (dt < -4 || dt > b.busDwellS - 3) return null;
      final walk = ((dt + 1) / 3).clamp(0.0, 1.0);
      return (t: 1 - walk, alpha: dt < -2 ? (dt + 4) / 2 : (dt < 2 ? 1 : 0));
  }
}
