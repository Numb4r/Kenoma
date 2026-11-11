/// Os pombos das praças (docs/GDD.md, "Simulações do mundo", bichos): cenário, local, difere entre aparelhos. Em cada praça
/// ou parque do OSM perto do jogador, um bando cisca no chão; quando o avatar chega perto, todos levantam voo e pousam
/// adiante. Bandos só nascem e somem fora da vista. Dart puro.
library;

import 'dart:math' as math;

import '../../core/pcg32.dart';
import '../../data/traffic_pack.dart';

class Bird {
  Bird(this.x, this.y, this.phase);

  /// Posição no chão (células z21) e a altura do voo (0 no chão, 1 no alto).
  double x, y, height = 0;

  /// Voando: de onde, para onde e quanto do voo já passou (0 a 1). `flight < 0`: no chão.
  double fx = 0, fy = 0, tx = 0, ty = 0, flight = -1, delay = 0;

  /// O relógio de cada um (ciscar, bater asa) e para que lado olha.
  double phase, hopIn = 0;
  bool left = false;

  bool get flying => flight >= 0;
}

class BirdFlock {
  BirdFlock(this.x, this.y, this.birds);

  /// O centro do bando agora (muda quando ele pousa em outro lugar).
  double x, y;
  final List<Bird> birds;
}

class BirdFlocks {
  BirdFlocks({required this.points, int seed = 1, this.rangeM = 220, this.scareM = 5, this.flyM = 13, this.flightS = 1.7, this.perFlock = 6}) : _rng = Pcg32(seed ^ 0xB12D5, 0x51);

  final TrafficPointSource? points;

  /// Praças a até [rangeM] do jogador têm bando; o avatar a menos de [scareM] de um pombo espanta o bando, que voa uns
  /// [flyM] metros em [flightS] segundos.
  final double rangeM, scareM, flyM, flightS;
  final int perFlock;
  final Pcg32 _rng;
  final Map<(int, int), BirdFlock> flocks = {};

  /// Quantas vezes um bando levantou voo (testes e debug).
  int takeoffs = 0;

  double _u() => _rng.nextFloat();

  /// Avança [dt] segundos com o avatar em ([px], [py], células z21). [inView] diz se um ponto está na tela (com folga).
  void update(double dt, double px, double py, double mpc, bool Function(double x, double y) inView) {
    final src = points;
    if (src == null) return;
    final r = rangeM / mpc;
    // Bandos novos nas praças que entraram no alcance, fora da vista; os que ficaram longe somem.
    for (final p in src.pointsIn(px - r, py - r, px + r, py + r)) {
      if (p.kind != TrafficPointKind.square) continue;
      final key = ((p.x * 64).round(), (p.y * 64).round());
      if (flocks.containsKey(key) || (_started && inView(p.x, p.y))) continue;
      flocks[key] = BirdFlock(p.x, p.y, [
        for (var i = 0; i < perFlock - 2 + _rng.nextInt(5); i++) Bird(p.x + (_u() - 0.5) * 6 / mpc, p.y + (_u() - 0.5) * 6 / mpc, _u() * 10)..left = _u() < 0.5,
      ]);
    }
    _started = true;
    flocks.removeWhere((_, f) => ((f.x - px).abs() > r * 1.3 || (f.y - py).abs() > r * 1.3) && !inView(f.x, f.y));
    final scare = scareM / mpc;
    for (final f in flocks.values) {
      final scared = f.birds.any((b) => !b.flying && (b.x - px) * (b.x - px) + (b.y - py) * (b.y - py) < scare * scare);
      if (scared) {
        takeoffs++;
        // Todos para o mesmo lado, para longe do avatar, cada um com o seu atraso e o seu canto.
        final away = math.atan2(f.y - py, f.x - px) + (_u() - 0.5) * 1.2, d = flyM * (0.8 + 0.5 * _u()) / mpc;
        f.x += math.cos(away) * d;
        f.y += math.sin(away) * d;
        for (final b in f.birds) {
          if (b.flying) continue;
          b
            ..fx = b.x
            ..fy = b.y
            ..tx = f.x + (_u() - 0.5) * 5 / mpc
            ..ty = f.y + (_u() - 0.5) * 5 / mpc
            ..flight = 0
            ..delay = _u() * 0.35
            ..left = b.tx < b.x;
        }
      }
      for (final b in f.birds) {
        b.phase += dt;
        if (b.flying) {
          if (b.delay > 0) {
            b.delay -= dt;
            continue;
          }
          b.flight += dt / flightS;
          final t = b.flight.clamp(0.0, 1.0), e = t * t * (3 - 2 * t);
          b
            ..x = b.fx + (b.tx - b.fx) * e
            ..y = b.fy + (b.ty - b.fy) * e
            ..height = math.sin(t * math.pi);
          if (b.flight >= 1) {
            b
              ..flight = -1
              ..height = 0
              ..hopIn = 0.5 + _u();
          }
        } else {
          // Ciscando: de vez em quando um pulinho.
          b.hopIn -= dt;
          if (b.hopIn <= 0) {
            b.hopIn = 0.8 + _u() * 2.5;
            final a = _u() * 2 * math.pi, d = 0.35 / mpc;
            if ((b.x + math.cos(a) * d - f.x).abs() < 4 / mpc && (b.y + math.sin(a) * d - f.y).abs() < 4 / mpc) {
              b
                ..x += math.cos(a) * d
                ..y += math.sin(a) * d
                ..left = math.cos(a) < 0;
            }
          }
        }
      }
    }
  }

  bool _started = false;
}
