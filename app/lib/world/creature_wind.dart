/// O vento nas criaturas do mapa (Vento, Vendaval, Tornado, Furacão; força em `clima.json`, `wind_force`): Ecos e Fagulhas
/// se inclinam e balançam na direção do vento, os leves (Fagulhas e Ecos de nível baixo) são empurrados alguns metros e
/// voltam devagar quando o vento cai, e partículas soltas do sprite saem com o vento. Só desenho: o ponto de coleta, a
/// distância da Aura e o spawn não mudam (a deriva das Fagulhas que muda o mundo é a do `movement` da época). Dart puro.
library;

import 'dart:math' as math;

import '../core/species_ids.dart';
import 'spawn_field.dart';

/// Os números do vento nas criaturas (`balance.json`, `climate.creature_wind`): valem por aparelho, não mudam o mundo.
class CreatureWindBalance {
  const CreatureWindBalance({this.leanDeg = 16, this.pushM = 4, this.lightLevel = 5, this.riseS = 4, this.fallS = 90, this.motes = 3});

  factory CreatureWindBalance.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const CreatureWindBalance();
    double d(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    return CreatureWindBalance(
      leanDeg: d('lean_deg', 16),
      pushM: d('push_m', 4),
      lightLevel: (j['light_level'] as num?)?.toInt() ?? 5,
      riseS: d('rise_s', 4),
      fallS: d('fall_s', 90),
      motes: (j['motes'] as num?)?.toInt() ?? 3,
    );
  }

  /// Inclinação máxima (força 1), em graus.
  final double leanDeg;

  /// Quanto o vento de força 1 empurra os leves, em metros.
  final double pushM;

  /// Ecos até este nível contam como leves.
  final int lightLevel;

  /// Quanto o vento leva para chegar (constante de tempo ao subir) e para cair, em segundos: os empurrados voltam devagar.
  final double riseS;
  final double fallS;

  /// Partículas soltas por criatura na força 1.
  final int motes;
}

/// Uma partícula solta do sprite: [along] de 0 a 1 é quanto ela já andou com o vento, [side] de -1 a 1 é o desvio para o lado
/// e [alpha] some no fim.
typedef WindMote = ({double along, double side, double alpha});

class CreatureWind {
  CreatureWind([this.balance = const CreatureWindBalance()]);

  final CreatureWindBalance balance;

  /// A força de agora, de 0 a 1: segue o clima subindo depressa e caindo devagar.
  double force = 0;

  /// Avança [dt] segundos com o clima pedindo [target] (0 sem vento).
  void update(double dt, double target) {
    if (dt <= 0) return;
    final tau = target > force ? balance.riseS : balance.fallS;
    force += (target - force) * (1 - math.exp(-dt / math.max(0.01, tau)));
    if (force < 1e-3 && target == 0) force = 0;
  }

  bool get calm => force <= 0;

  /// O spawn é leve: Fagulha, ou Eco (só a camada Eco) de nível até `light_level`.
  bool isLight(WorldSpawn s) => s.isSpark || (s.isEco && tierOfId(s.entryId) == SpeciesTier.eco && (s.level ?? 0) <= balance.lightLevel);

  /// A inclinação de [uid] em [time] (segundos de jogo), em radianos, para o lado do vento: firme com a força e balançando
  /// em rajadas (cada criatura no seu tempo).
  double lean(int uid, double time) {
    if (calm) return 0;
    final gust = 0.7 + 0.3 * math.sin(time * (2.2 + 2.5 * force) + (uid % 23));
    return force * gust * balance.leanDeg * math.pi / 180;
  }

  /// Quantos metros o vento empurra o spawn [s] agora: só os leves, oscilando de leve com as rajadas.
  double pushM(WorldSpawn s, double time) {
    if (calm || s.isMaterial || !isLight(s)) return 0;
    return force * balance.pushM * (0.85 + 0.15 * math.sin(time * 1.3 + (s.uid % 11)));
  }

  /// As partículas soltas de [uid] em [time]: até `motes` com a força 1, cada uma saindo do sprite e indo com o vento em
  /// ciclos de 1 a 2 s. Posição só do tempo e do uid: nada a guardar entre quadros.
  List<WindMote> motes(int uid, double time) {
    final n = (balance.motes * force).ceil();
    if (calm || n <= 0) return const [];
    return [
      for (var i = 0; i < n; i++)
        () {
          final h = ((uid >>> (i * 5)) & 0x3ff) / 1024; // 0 a 1, fixo por partícula
          final period = 1 + h;
          final u = ((time + h * 7) / period) % 1;
          return (along: u, side: math.sin(u * math.pi * 2 + h * 9) * (0.3 + h * 0.7), alpha: (1 - u) * (0.5 + 0.5 * force));
        }(),
    ];
  }
}
