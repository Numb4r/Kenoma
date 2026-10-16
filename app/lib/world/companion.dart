/// O Familiar como companheiro de caminhada (docs/GDD.md, "Familiar"): anda sempre ao lado do Conjurador, pela direita
/// de quem anda e um pouco atrás, com o mesmo cuidado do avatar: nunca pula, alcança a posição suavemente e, parado,
/// fica do lado em que estava. Não ocupa espaço no Círculo. Dart puro; o desenho é de `ui/game/`.
library;

import 'dart:math' as math;

class Companion {
  Companion({this.followTauS = 0.4, this.headingTauS = 1.8, this.snapCells = 20});

  /// Constante de tempo do seguir: em ~3× isto ele cobre 95% da distância.
  final double followTauS;

  /// Constante de tempo da direção: o lado do Familiar acompanha a curva com esta suavização.
  final double headingTauS;

  /// Acima desta distância (em células) ele aparece no lugar certo de uma vez (teleporte, troca de fonte).
  final double snapCells;

  double x = 0, y = 0;
  bool hasPosition = false;

  /// A direção em que o Conjurador anda, em radianos (x leste, y sul; horário na tela). Parado, guarda a última.
  double _theta = 0;
  double get _dx => math.cos(_theta);
  double get _dy => math.sin(_theta);

  /// A direção do último movimento e se o Familiar está andando (para animar e olhar para o lado certo).
  double get heading => _theta;
  bool moving = false;

  /// Onde o Familiar deveria estar: à direita de quem anda (a direita de quem vai a leste é o sul) e um pouco atrás.
  (double, double) _target(double ax, double ay, double offsetCells) {
    final rx = -_dy, ry = _dx; // a direita de quem anda
    return (ax + rx * offsetCells * 0.9 - _dx * offsetCells * 0.4, ay + ry * offsetCells * 0.9 - _dy * offsetCells * 0.4);
  }

  /// Avança [dt] segundos. ([ax], [ay]) é o avatar, ([vx], [vy]) a velocidade dele em células por segundo e
  /// [offsetCells] a distância ao lado dele, em células.
  void update(double dt, {required double ax, required double ay, required double vx, required double vy, required double offsetCells}) {
    if (dt <= 0) return;
    final speed = math.sqrt(vx * vx + vy * vy);
    if (speed > 0.01) {
      // A direção também é suavizada, pelo caminho mais curto: numa curva o Familiar troca de lado varrendo, não de uma vez.
      var delta = math.atan2(vy, vx) - _theta;
      delta = math.atan2(math.sin(delta), math.cos(delta));
      _theta += delta * (1 - math.exp(-dt / headingTauS));
    }
    final (tx, ty) = _target(ax, ay, offsetCells);
    if (!hasPosition || (tx - x).abs() > snapCells || (ty - y).abs() > snapCells) {
      x = tx;
      y = ty;
      hasPosition = true;
      moving = false;
      return;
    }
    final a = 1 - math.exp(-dt / followTauS);
    final px = x, py = y;
    x += (tx - x) * a;
    y += (ty - y) * a;
    moving = math.sqrt((x - px) * (x - px) + (y - py) * (y - py)) / dt > 0.004; // ~0,07 m/s
  }

  void clear() => hasPosition = false;
}
