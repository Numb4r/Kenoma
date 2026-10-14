/// A rotação do mapa de jogo: o gesto de dois dedos, a volta ao norte e o modo "seguir direção", que gira o
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
  MapRotation({this.slopRad = 0.12, this.snapNorthRad = 0.12, this.northTauS = 0.15, this.headingTauS = 0.35});

  /// Quanto os dedos precisam girar antes de o mapa girar: dá para fazer pinça sem girar sem querer.
  final double slopRad;

  /// Ao soltar a menos que isto do norte, o mapa assenta no norte.
  final double snapNorthRad;
  final double northTauS;
  final double headingTauS;

  double _angle = 0;
  double _target = 0;
  double _tau = 0.15;
  double _base = 0;
  double _offset = 0;
  bool _gesturing = false;

  /// Se o modo "seguir direção" está ligado.
  bool followHeading = false;

  /// A rotação de agora.
  double get angle => _angle;

  /// A bússola aparece quando o mapa não está com o norte para cima, ou no modo "seguir direção" (para dar
  /// como desligar).
  bool get showCompass => _angle.abs() > 0.0087 || followHeading; // 0,5 grau

  /// Os dedos começaram um gesto: guarda de onde girar.
  void gestureStart() {
    _base = _target;
    _offset = 0;
    _gesturing = false;
  }

  /// Giro acumulado dos dedos desde o início do gesto, em radianos. Só vale depois de passar de [slopRad], e
  /// aí o mapa acompanha os dedos sem salto. Girar com a mão desliga o "seguir direção".
  void gestureRotate(double cumulative) {
    if (!_gesturing) {
      if (cumulative.abs() < slopRad) return;
      _gesturing = true;
      _offset = cumulative;
      followHeading = false;
    }
    _target = normalizeAngle(_base + cumulative - _offset);
    _angle = _target;
  }

  void gestureEnd() {
    if (_gesturing && _target.abs() < snapNorthRad) goNorth();
    _gesturing = false;
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

  /// Avança [dt] segundos. Durante o gesto o mapa já está nos dedos; fora dele, suaviza até o alvo.
  void update(double dt) {
    if (dt <= 0 || _gesturing) return;
    _angle = smoothAngle(_angle, _target, dt, _tau);
    if (shortestDelta(_angle, _target).abs() < 1e-4) _angle = _target;
  }

  /// Zera tudo: norte para cima, sem seguir direção.
  void reset() {
    _angle = _target = 0;
    followHeading = false;
    _gesturing = false;
  }
}
