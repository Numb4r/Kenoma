/// Os três testes de escola do nível 3 (docs/GDD.md, "Tutorial e primeiros níveis"). Cenas roteirizadas, sem gadget nem
/// sigilo completos: cada uma tem uma regra de nota de 0 a 100, determinística a partir do que o jogador fez. Dart puro;
/// as cenas em `ui/school/` só desenham e repassam o dedo. Os números vêm do bloco `school_tests` do `balance.json`.
library;

import 'dart:math' as math;

double _d(Object? m, String k) => ((m as Map<String, dynamic>)[k] as num).toDouble();
int _i(Object? m, String k) => ((m as Map<String, dynamic>)[k] as num).toInt();

class SchoolTestsBalance {
  SchoolTestsBalance(Map<String, dynamic> b)
      : techno = TechnoBalance(b['techno']),
        shaman = ShamanBalance(b['shaman']),
        sealer = SealerBalance(b['sealer']);

  final TechnoBalance techno;
  final ShamanBalance shaman;
  final SealerBalance sealer;
}

class TechnoBalance {
  TechnoBalance(Object? m)
      : durationS = _d(m, 'duration_s'),
        band = _d(m, 'band'),
        wanderAmp = _d(m, 'wander_amp'),
        wanderPeriodS = _d(m, 'wander_period_s'),
        noiseAmp = _d(m, 'noise_amp'),
        noisePeriodS = _d(m, 'noise_period_s'),
        stabilizeS = _d(m, 'stabilize_s'),
        stabilizeCooldownS = _d(m, 'stabilize_cooldown_s'),
        stabilizeCharges = _i(m, 'stabilize_charges');

  final double durationS, band, wanderAmp, wanderPeriodS, noiseAmp, noisePeriodS, stabilizeS, stabilizeCooldownS;
  final int stabilizeCharges;
}

class ShamanBalance {
  ShamanBalance(Object? m)
      : startM = _d(m, 'start_m'),
        stopM = _d(m, 'stop_m'),
        maxSpeedMps = _d(m, 'max_speed_mps'),
        calmSpeedMps = _d(m, 'calm_speed_mps'),
        spookJumpM = _d(m, 'spook_jump_m'),
        spookCooldownS = _d(m, 'spook_cooldown_s'),
        parS = _d(m, 'par_s'),
        timeoutS = _d(m, 'timeout_s'),
        spookPenalty = _d(m, 'spook_penalty'),
        timePenaltyPerS = _d(m, 'time_penalty_per_s'),
        timeoutCap = _d(m, 'timeout_cap');

  final double startM, stopM, maxSpeedMps, calmSpeedMps, spookJumpM, spookCooldownS, parS, timeoutS, spookPenalty, timePenaltyPerS, timeoutCap;
}

class SealerBalance {
  SealerBalance(Object? m)
      : minPoints = _i(m, 'min_points'),
        smoothWindow = _i(m, 'smooth_window'),
        minSweepTurns = _d(m, 'min_sweep_turns'),
        maxCv = _d(m, 'max_cv'),
        closureFull = _d(m, 'closure_full'),
        closureZero = _d(m, 'closure_zero'),
        sizeMin = _d(m, 'size_min'),
        sizeMax = _d(m, 'size_max'),
        sizeOkMin = _d(m, 'size_ok_min'),
        sizeOkMax = _d(m, 'size_ok_max');

  final int minPoints, smoothWindow;
  final double minSweepTurns, maxCv, closureFull, closureZero, sizeMin, sizeMax, sizeOkMin, sizeOkMax;
}

/// Tecnomante: um sinal com ruído extra, que o jogador segue com o dial. O botão de estabilizar zera o ruído por
/// [TechnoBalance.stabilizeS] segundos (poucas cargas, com espera). Nota = fração do tempo com o dial dentro da faixa.
class TechnoTest {
  TechnoTest(this.b) : charges = b.stabilizeCharges;

  final TechnoBalance b;
  double t = 0;
  double inBandS = 0;
  int charges;
  double _stabilizedLeft = 0;
  double _cooldownLeft = 0;

  /// Quanto do ruído ainda vale (0 estabilizado, 1 solto); muda em rampa para o sinal não dar um salto.
  double noise = 1;

  bool get done => t >= b.durationS;
  bool get stabilized => _stabilizedLeft > 0;
  bool get canStabilize => !done && charges > 0 && _cooldownLeft <= 0;

  /// O valor (0 a 1) que o sinal tem agora. Soma de senos: o mesmo [t] dá sempre o mesmo valor.
  double get target {
    final w = b.wanderAmp * math.sin(2 * math.pi * t / b.wanderPeriodS);
    final n = b.noiseAmp * (0.6 * math.sin(2 * math.pi * t / b.noisePeriodS) + 0.4 * math.sin(2 * math.pi * t * 2.7 / b.noisePeriodS + 1.3));
    return (0.5 + w + n * noise).clamp(0.0, 1.0);
  }

  bool stabilize() {
    if (!canStabilize) return false;
    charges--;
    _stabilizedLeft = b.stabilizeS;
    _cooldownLeft = b.stabilizeS + b.stabilizeCooldownS;
    return true;
  }

  void step(double dt, double dial) {
    if (done) return;
    final left = b.durationS - t;
    final d = math.min(dt, left);
    t += d;
    if (_stabilizedLeft > 0) _stabilizedLeft = math.max(0, _stabilizedLeft - d);
    if (_cooldownLeft > 0) _cooldownLeft = math.max(0, _cooldownLeft - d);
    noise = (noise + (stabilized ? -1 : 1) * 4 * d).clamp(0.0, 1.0);
    if ((dial - target).abs() <= b.band) inBandS += d;
  }

  int get score => (100 * inBandS / b.durationS).round().clamp(0, 100);
}

/// Xamã Urbano: aproximar-se devagar de um Eco arisco. Acima da velocidade calma o Eco se assusta e foge um salto; o teste
/// acaba quando ele para (a distância chega em [ShamanBalance.stopM]) ou no tempo limite.
class ShamanTest {
  ShamanTest(this.b) : distanceM = b.startM;

  final ShamanBalance b;
  double t = 0;
  double distanceM;
  int spooks = 0;
  bool stopped = false;
  double _cooldown = 0;

  bool get done => stopped || t >= b.timeoutS;

  /// [speed01] (0 a 1) é a fração da velocidade máxima; o dedo mais alto anda mais rápido.
  void step(double dt, double speed01) {
    if (done) return;
    t += dt;
    if (_cooldown > 0) _cooldown -= dt;
    final speed = speed01.clamp(0.0, 1.0) * b.maxSpeedMps;
    if (speed > b.calmSpeedMps && _cooldown <= 0) {
      spooks++;
      _cooldown = b.spookCooldownS;
      distanceM += b.spookJumpM;
    }
    distanceM = (distanceM - speed * dt).clamp(0.0, b.startM * 1.5);
    if (distanceM <= b.stopM) stopped = true;
  }

  int get score {
    if (!stopped) return math.min(b.timeoutCap, 100 * (1 - distanceM / b.startM)).round().clamp(0, 100);
    final s = 100 - spooks * b.spookPenalty - math.max(0, t - b.parS) * b.timePenaltyPerS;
    return s.round().clamp(0, 100);
  }
}

/// Selador: o traço do dedo em volta do Eco. [points] estão no referencial do Eco (origem nele), na unidade do raio de
/// referência da cena (1,0 é o círculo ideal). Vale quem fecha um círculo mais ou menos redondo, do tamanho certo, em
/// volta do Eco; a mão tremida passa por uma média móvel antes de medir.
int sealerScore(List<(double, double)> points, SealerBalance b) {
  if (points.length < b.minPoints) return 0;
  final p = _smooth(points, b.smoothWindow);
  final r = [for (final q in p) math.sqrt(q.$1 * q.$1 + q.$2 * q.$2)];
  final mean = r.reduce((a, c) => a + c) / r.length;
  if (mean < 1e-6) return 0;
  final variance = r.map((v) => (v - mean) * (v - mean)).reduce((a, c) => a + c) / r.length;
  final roundness = (1 - math.sqrt(variance) / mean / b.maxCv).clamp(0.0, 1.0);

  var sweep = 0.0;
  for (var i = 1; i < p.length; i++) {
    var d = math.atan2(p[i].$2, p[i].$1) - math.atan2(p[i - 1].$2, p[i - 1].$1);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    sweep += d;
  }
  final coverage = (sweep.abs() / (2 * math.pi) / b.minSweepTurns).clamp(0.0, 1.0);

  final gap = math.sqrt(math.pow(p.first.$1 - p.last.$1, 2) + math.pow(p.first.$2 - p.last.$2, 2)) / mean;
  final closure = ((b.closureZero - gap) / (b.closureZero - b.closureFull)).clamp(0.0, 1.0);

  final size = mean < b.sizeOkMin
      ? ((mean - b.sizeMin) / (b.sizeOkMin - b.sizeMin)).clamp(0.0, 1.0)
      : mean > b.sizeOkMax
          ? ((b.sizeMax - mean) / (b.sizeMax - b.sizeOkMax)).clamp(0.0, 1.0)
          : 1.0;
  return (100 * roundness * coverage * closure * size).round().clamp(0, 100);
}

List<(double, double)> _smooth(List<(double, double)> pts, int window) {
  final h = window ~/ 2;
  return [
    for (var i = 0; i < pts.length; i++)
      () {
        final lo = math.max(0, i - h), hi = math.min(pts.length - 1, i + h);
        var x = 0.0, y = 0.0;
        for (var j = lo; j <= hi; j++) {
          x += pts[j].$1;
          y += pts[j].$2;
        }
        final n = hi - lo + 1;
        return (x / n, y / n);
      }(),
  ];
}
