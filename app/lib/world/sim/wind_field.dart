/// O vento local (docs/GDD.md, "Simulações do mundo"): a direção e a força do clima, canalizadas pelas ruas (acelera ao
/// longo delas, quase para nas ruas de través), mais fraco atrás dos quarteirões, com rajadas. Aqui é cenário: leva as
/// folhas e os papéis do chão. A deriva das Fagulhas, que é mundo, continua em `ClimateWorld.adjustSpark`. Dart puro.
library;

import 'dart:math' as math;

import '../../core/pcg32.dart';
import 'lane_graph.dart';

/// O vento (m/s, x leste e y sul) em ([x], [y], células z21): [headingRad] é para onde ele sopra (a partir do norte,
/// horário) e [speed] a força do clima. [streets] dá a direção da rua no lugar.
(double, double) localWind(LaneGraph? streets, double x, double y, double headingRad, double speed, double t) {
  final bx = math.sin(headingRad) * speed, by = -math.cos(headingRad) * speed;
  // Rajadas: sobem e descem devagar, defasadas de quarteirão para quarteirão.
  final gust = 0.75 + 0.45 * math.sin(t / 3.1 + (x / 9).floor() * 1.7 + (y / 9).floor() * 2.3) * math.sin(t / 7.3 + 1.1);
  final d = streets?.streetDir(x, y);
  if (d == null) return (bx * 0.5 * gust, by * 0.5 * gust); // atrás das quadras: abrigado
  final along = bx * d.$1 + by * d.$2;
  // Na rua: o que sopra ao longo dela acelera; o que vem de través quase some.
  return ((d.$1 * along * 1.35 + bx * 0.15) * gust, (d.$2 * along * 1.35 + by * 0.15) * gust);
}

class Leaf {
  double x = 0, y = 0, life = 0, spin = 0;
  int kind = 0;
}

/// As folhas e os papéis que o vento leva pelo chão, em volta da vista. Nascem do lado de onde o vento vem, fora da tela.
class WindLeaves {
  WindLeaves({this.count = 40, int seed = 7}) : _rng = Pcg32(seed ^ 0x1EAF, 0x77);

  final int count;
  final Pcg32 _rng;
  final List<Leaf> leaves = [];

  double _u() => _rng.nextFloat();

  /// O que o vento leva agora: `leaf` (folhas e papéis), `smoke` (fumaça), `soot` (fuligem, que nasce nas avenidas) ou
  /// `sand` (areia).
  String style = 'leaf';

  void update(double dt, LaneGraph? streets, double headingRad, double speed, double t, double mpc, double l, double top, double r, double b) {
    if (speed <= 0) {
      leaves.clear();
      return;
    }
    final w = r - l, h = b - top, m = 1.5;
    while (leaves.length < count) {
      // A primeira leva já espalhada (o vento já soprava); depois, só pela borda de onde ele vem.
      final first = leaves.length < count && t - _since < 0.5;
      final lf = Leaf()
        ..kind = _rng.nextInt(4)
        ..life = 6 + _u() * 10;
      if (style == 'soot' && streets != null) {
        // A fuligem nasce nas avenidas (até seis tentativas de achar uma na tela) e o vento a leva.
        lf
          ..x = l + _u() * w
          ..y = top + _u() * h;
        for (var k = 0; k < 6 && streets.streetRank(lf.x, lf.y) < 2; k++) {
          lf
            ..x = l + _u() * w
            ..y = top + _u() * h;
        }
        lf.life = 3 + _u() * 5;
      } else if (first) {
        lf
          ..x = l + _u() * w
          ..y = top + _u() * h;
      } else {
        final ux = -math.sin(headingRad), uy = math.cos(headingRad); // de onde o vento vem
        final side = _u();
        lf
          ..x = (l + r) / 2 + ux * (w / 2 + m) + -uy * (side - 0.5) * (w + h)
          ..y = (top + b) / 2 + uy * (h / 2 + m) + ux * (side - 0.5) * (w + h);
      }
      leaves.add(lf);
    }
    for (var i = leaves.length - 1; i >= 0; i--) {
      final lf = leaves[i];
      final (vx, vy) = localWind(streets, lf.x, lf.y, headingRad, speed, t);
      lf
        ..x += vx * dt / mpc
        ..y += vy * dt / mpc
        ..spin += dt * (2 + math.sqrt(vx * vx + vy * vy))
        ..life -= dt;
      if (lf.life <= 0 || lf.x < l - 3 * m || lf.x > r + 3 * m || lf.y < top - 3 * m || lf.y > b + 3 * m) leaves.removeAt(i);
    }
  }

  double _since = 0;

  /// O vento começou agora (a primeira leva nasce espalhada).
  void start(double t) => _since = t;
}
