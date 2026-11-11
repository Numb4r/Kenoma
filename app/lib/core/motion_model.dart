/// O movimento próprio de Ecos e Fagulhas (`epochs.json`, `motion`, da época 9 em diante): **é mundo**. Tudo é função
/// fechada da seed, da identidade de quem se move e do tempo, sem estado e sem reagir à simulação local: dois aparelhos
/// calculam a mesma posição no mesmo instante, e o alcance de toque e a Aura são medidos contra ela. Dart puro.
library;

import 'dart:math' as math;

import 'fnv.dart';

final int _saltWander = salt('WAND'), _saltVortex = salt('VORT'), _saltOrbit = salt('ORBT');

double _u(int h) => (h >>> 32) / 4294967296.0;

class MotionModel {
  const MotionModel({
    this.wanderM = 3.5,
    this.wanderPeriodS = 80,
    this.waterOrbitM = 4,
    this.waterOrbitPeriodS = 55,
    this.waterSeekM = 40,
    this.currentMps = 0.04,
    this.currentMaxM = 60,
    this.vortexShare = 0.9,
    this.vortexOrbitM = 1.5,
    this.vortexPeriodS = 40,
  });

  factory MotionModel.fromJson(Map<String, dynamic> j) {
    const d = MotionModel();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    return MotionModel(
      wanderM: n('wander_m', d.wanderM),
      wanderPeriodS: n('wander_period_s', d.wanderPeriodS),
      waterOrbitM: n('water_orbit_m', d.waterOrbitM),
      waterOrbitPeriodS: n('water_orbit_period_s', d.waterOrbitPeriodS),
      waterSeekM: n('water_seek_m', d.waterSeekM),
      currentMps: n('current_mps', d.currentMps),
      currentMaxM: n('current_max_m', d.currentMaxM),
      vortexShare: n('vortex_share', d.vortexShare),
      vortexOrbitM: n('vortex_orbit_m', d.vortexOrbitM),
      vortexPeriodS: n('vortex_period_s', d.vortexPeriodS),
    );
  }

  /// Ecos Passivos: andam devagar dentro deste raio (m), numa volta que leva em torno de [wanderPeriodS].
  final double wanderM, wanderPeriodS;

  /// Ecos de Água: rondam a poça mais próxima (a até [waterSeekM]) neste raio, uma volta a cada [waterOrbitPeriodS].
  final double waterOrbitM, waterOrbitPeriodS, waterSeekM;

  /// Correntes do Véu: as Fagulhas deslizam a [currentMps] até o redemoinho da vizinhança (no máximo [currentMaxM]) e giram
  /// em volta dele. [vortexShare] das células z18 têm um redemoinho.
  final double currentMps, currentMaxM, vortexShare, vortexOrbitM, vortexPeriodS;

  /// O deslocamento (metros, x leste e y sul) do Eco Passivo [uid] no instante [t] (segundos UTC): duas ondas de períodos
  /// diferentes, com fase e sentido do próprio Eco. Nunca passa de [wanderM].
  (double, double) wander(int uid, double t) {
    final a = _u(fnv1a64([uid, _saltWander, 1])), b = _u(fnv1a64([uid, _saltWander, 2])), c = _u(fnv1a64([uid, _saltWander, 3]));
    final w = 2 * math.pi / (wanderPeriodS * (0.8 + 0.4 * c)), r = wanderM * 0.7071;
    return (r * math.sin(w * t + a * 2 * math.pi), r * math.sin(w * 1.37 * t + b * 2 * math.pi));
  }

  /// O deslocamento (metros) do Eco de Água [uid] em volta do centro da poça: um círculo de raio [waterOrbitM], com a fase e
  /// o sentido do Eco.
  (double, double) orbit(int uid, double t) {
    final h = fnv1a64([uid, _saltOrbit]);
    final dir = (h & 1) == 0 ? 1.0 : -1.0, a = _u(h) * 2 * math.pi + dir * 2 * math.pi * t / waterOrbitPeriodS;
    return (waterOrbitM * math.cos(a), waterOrbitM * math.sin(a));
  }

  /// O redemoinho da célula z18 ([cx18], [cy18]), em células z21, ou `null` se ela não tem.
  (double, double)? vortexOf(int seed, int epochId, int cx18, int cy18) {
    final h = fnv1a64([seed, epochId, cx18, cy18, _saltVortex]);
    if (_u(h) >= vortexShare) return null;
    return ((cx18 + _u(fnv1a64([h, 1]))) * 8, (cy18 + _u(fnv1a64([h, 2]))) * 8);
  }

  /// O redemoinho para onde corre a Fagulha que nasceu em ([x], [y], células z21): o mais perto entre o da célula z18 dela
  /// e os das oito vizinhas, a até [currentMaxM]. `null`: nenhum (a Fagulha fica parada).
  (double, double)? vortexFor(int seed, int epochId, double x, double y, double mpc) {
    final cx = x.floor() >>> 3, cy = y.floor() >>> 3;
    (double, double)? best;
    var bd = currentMaxM * currentMaxM;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final v = vortexOf(seed, epochId, cx + dx, cy + dy);
        if (v == null) continue;
        final ex = (v.$1 - x) * mpc, ey = (v.$2 - y) * mpc, d = ex * ex + ey * ey;
        if (d < bd) {
          bd = d;
          best = v;
        }
      }
    }
    return best;
  }

  /// Onde está, [age] segundos depois de nascer, a Fagulha [uid] que nasceu em ([x], [y]) e corre para o redemoinho
  /// [vortex] (células z21): desliza em linha reta até a borda dele e depois gira em volta, sem salto na chegada.
  (double, double) current(int uid, double x, double y, (double, double) vortex, double age, double mpc) {
    final ex = (vortex.$1 - x) * mpc, ey = (vortex.$2 - y) * mpc, dist = math.sqrt(ex * ex + ey * ey);
    final reach = math.max(0.0, dist - vortexOrbitM), gone = currentMps * math.max(0.0, age);
    if (dist < 1e-6 || gone <= reach) {
      final k = dist < 1e-6 ? 0.0 : gone / dist;
      return (x + ex * k / mpc, y + ey * k / mpc);
    }
    // Chegou: gira a partir do ângulo por onde entrou.
    final r = math.min(vortexOrbitM, dist), dir = (uid & 1) == 0 ? 1.0 : -1.0;
    final a = math.atan2(-ey, -ex) + dir * 2 * math.pi * (gone - reach) / currentMps / vortexPeriodS;
    return (vortex.$1 + r * math.cos(a) / mpc, vortex.$2 + r * math.sin(a) / mpc);
  }
}
