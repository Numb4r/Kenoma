/// Os ciclistas nas ciclovias (docs/GDD.md, "Simulações do mundo", vida urbana): cenário local. Em cada ciclovia ou
/// ciclofaixa do OSM perto do jogador pedalam alguns ciclistas, de uma ponta à outra, cada um pela direita. Só nascem fora
/// da vista; no fim da ciclovia, somem se a ponta está fora da tela ou dão meia-volta se está à vista. Dart puro.
library;

import 'dart:math' as math;

import '../../core/pcg32.dart';
import '../../data/cycle_pack.dart';

class Rider {
  Rider(this.id, this.line, this.cum, this.s, this.dir, this.speed, this.palette);

  final int id;
  final CycleLine line;

  /// Metros acumulados até cada vértice da ciclovia.
  final List<double> cum;
  double s;
  int dir;
  final double speed;
  final int palette;
  double x = 0, y = 0, heading = 0, odo = 0;
  bool gone = false;
}

class Cyclists {
  Cyclists({required this.pack, int seed = 3, this.rangeM = 260, this.per100m = 0.5, this.max = 40}) : _rng = Pcg32(seed ^ 0xC1C1E, 0x33);

  final CyclePack? pack;

  /// Ciclovias a até [rangeM] do jogador têm ciclistas: [per100m] a cada 100 m com a densidade em 1, no máximo [max].
  final double rangeM, per100m;
  final int max;
  final Pcg32 _rng;
  final List<Rider> riders = [];
  final Map<CycleLine, int> _count = {};
  int _nextId = 1;
  bool _started = false;

  /// Quantos nasceram e sumiram dentro da vista (tem de ficar em zero).
  int bornInView = 0, goneInView = 0;

  double _u() => _rng.nextFloat();

  void _place(Rider r, double mpc) {
    final xy = r.line.xy, n = r.cum.length;
    var i = 0;
    while (i < n - 2 && r.cum[i + 1] < r.s) {
      i++;
    }
    final seg = r.cum[i + 1] - r.cum[i], t = seg <= 0 ? 0.0 : ((r.s - r.cum[i]) / seg).clamp(0.0, 1.0);
    final dx = xy[2 * i + 2] - xy[2 * i], dy = xy[2 * i + 3] - xy[2 * i + 1], len = math.sqrt(dx * dx + dy * dy);
    final ux = len <= 0 ? 1.0 : dx / len * r.dir, uy = len <= 0 ? 0.0 : dy / len * r.dir;
    // Pela direita de quem pedala: na ciclofaixa, encostado na borda da rua.
    final off = (r.line.onRoad ? 2.6 : 0.7) / mpc;
    r
      ..x = xy[2 * i] + dx * t - uy * off
      ..y = xy[2 * i + 1] + dy * t + ux * off
      ..heading = math.atan2(uy, ux);
  }

  /// Avança [dt] segundos com o jogador em ([px], [py], células z21). [density] vai de 0 a 1 (a hora e o clima).
  void update(double dt, double px, double py, double mpc, double density, bool Function(double x, double y) inView) {
    final p = pack;
    if (p == null) return;
    final r = rangeM / mpc;
    for (final line in p.linesIn(px - r, py - r, px + r, py + r)) {
      final cum = <double>[0];
      for (var i = 2; i < line.xy.length; i += 2) {
        final dx = line.xy[i] - line.xy[i - 2], dy = line.xy[i + 1] - line.xy[i - 1];
        cum.add(cum.last + math.sqrt(dx * dx + dy * dy) * mpc);
      }
      final want = math.min(6, (cum.last / 100 * per100m * density).round());
      var have = _count[line] ?? 0;
      while (have < want && riders.length < max) {
        // Na primeira leva, espalhados; depois, só por uma ponta que esteja fora da vista.
        final dir = _u() < 0.5 ? 1 : -1;
        final rider = Rider(_nextId++, line, cum, _started ? (dir > 0 ? 0 : cum.last) : _u() * cum.last, dir, 3.8 + _u() * 1.8, _rng.nextInt(4));
        _place(rider, mpc);
        if (_started && inView(rider.x, rider.y)) break;
        riders.add(rider);
        have++;
      }
      _count[line] = have;
    }
    _started = true;
    for (final rd in riders) {
      rd.s += rd.dir * rd.speed * dt;
      rd.odo += rd.speed * dt;
      final end = rd.cum.last;
      if (rd.s < 0 || rd.s > end) {
        rd.s = rd.s.clamp(0.0, end);
        _place(rd, mpc);
        if (inView(rd.x, rd.y)) {
          rd.dir = -rd.dir; // a ponta está na tela: dá meia-volta
        } else {
          rd.gone = true;
        }
      }
      _place(rd, mpc);
      // Longe do jogador e fora da vista: some.
      if (!rd.gone && ((rd.x - px).abs() > r * 1.4 || (rd.y - py).abs() > r * 1.4) && !inView(rd.x, rd.y)) rd.gone = true;
      if (rd.gone) _count[rd.line] = (_count[rd.line] ?? 1) - 1;
    }
    riders.removeWhere((rd) => rd.gone);
  }
}
