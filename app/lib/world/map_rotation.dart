/// A rotação do mapa de jogo: o arrasto de um dedo, a volta ao norte e o modo "seguir direção", que gira o
/// mapa com a bússola do celular. Dart puro: quem dirige o tempo é [update] e quem lê a bússola chama
/// [setHeading].
///
/// Ângulos em radianos, no sentido horário na tela. 0 é o norte para cima. Girar o mapa em `a` leva o norte
/// para `a` radianos à direita do alto da tela, então a bússola desenha a agulha em `a`.
library;

import 'dart:math' as math;

/// Leva [a] para `(-pi, pi]`.
double normalizeAngle(double a) {
  var x = a % (2 * math.pi);
  if (x > math.pi) x -= 2 * math.pi;
  if (x <= -math.pi) x += 2 * math.pi;
  return x;
}

/// O menor giro, com sinal, que leva [from] a [to].
double shortestDelta(double from, double to) => normalizeAngle(to - from);

/// Avança [current] em direção a [target] pelo caminho curto, com suavização exponencial de constante de
/// tempo [tauS] (em ~3 × [tauS] cobre 95% do caminho).
double smoothAngle(double current, double target, double dt, double tauS) =>
    normalizeAngle(current + shortestDelta(current, target) * (1 - math.exp(-dt / tauS)));

/// A rotação do mapa que põe a frente do celular, voltada para [headingDeg] (graus a partir do norte,
/// no sentido horário), para cima na tela.
double rotationForHeading(double headingDeg) => normalizeAngle(-headingDeg * math.pi / 180);

class MapRotation {
  MapRotation({this.northTauS = 0.15, this.headingTauS = 0.35});

  final double northTauS;
  final double headingTauS;

  double _angle = 0;
  double _target = 0;
  double _tau = 0.15;

  /// Se o modo "seguir direção" está ligado.
  bool followHeading = false;

  /// A rotação de agora.
  double get angle => _angle;

  /// A bússola aparece quando o mapa não está com o norte para cima, ou no modo "seguir direção" (para dar
  /// como desligar).
  bool get showCompass => _angle.abs() > 0.0087 || followHeading; // 0,5 grau

  /// O dedo girou o mapa em [radians] (sentido horário positivo): o mapa vai junto, direto, sem suavização
  /// (já está no dedo). Girar com a mão desliga o "seguir direção".
  void rotateBy(double radians) {
    if (radians == 0) return;
    followHeading = false;
    _target = normalizeAngle(_target + radians);
    _angle = _target;
  }

  /// Volta ao norte, desligando o "seguir direção".
  void goNorth() {
    followHeading = false;
    _target = 0;
    _tau = northTauS;
  }

  /// Liga ou desliga o "seguir direção". Desligado, o mapa fica onde está.
  void toggleFollowHeading() {
    followHeading = !followHeading;
    if (followHeading) {
      _tau = headingTauS;
      if (_heading != null) _target = rotationForHeading(_heading!);
    } else {
      _target = _angle;
    }
  }

  double? _heading;

  /// A bússola do celular leu [headingDeg]. No modo "seguir direção" o mapa gira para ela, com suavização.
  void setHeading(double headingDeg) {
    _heading = headingDeg;
    if (followHeading) _target = rotationForHeading(headingDeg);
  }

  /// Avança [dt] segundos, suavizando até o alvo.
  void update(double dt) {
    if (dt <= 0) return;
    _angle = smoothAngle(_angle, _target, dt, _tau);
    if (shortestDelta(_angle, _target).abs() < 1e-4) _angle = _target;
  }

  /// Zera tudo: norte para cima, sem seguir direção.
  void reset() {
    _angle = _target = 0;
    followHeading = false;
  }
}
