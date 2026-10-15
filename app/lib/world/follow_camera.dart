/// Câmera de jogo: presa ao Conjurador, que fica sempre no centro, com suavização. Não há espiar: o dedo gira
/// o mapa em torno dele. O zoom fica numa faixa de jogo, menor que a da câmera livre do debug. Dart puro: quem
/// dirige o tempo é [update].
library;

import 'dart:math' as math;

import 'map_camera.dart';

class FollowCamera {
  FollowCamera({
    required double x,
    required double y,
    double pixelsPerCell = defaultScale,
    this.followTauS = 0.25,
    this.snapCells = 200,
  })  : _x = x,
        _y = y,
        _tx = x,
        _ty = y,
        _scale = pixelsPerCell.clamp(minScale, maxScale).toDouble();

  /// A faixa de zoom do jogo, em pixels lógicos por célula: menor que a do debug (1 a 32).
  static const double minScale = 8;
  static const double maxScale = 24;
  static const double defaultScale = 16;

  /// Constante de tempo do seguir: em ~3x isto a câmera cobre 95% da distância.
  final double followTauS;

  /// Distância (em células) acima da qual a câmera pula em vez de deslizar (teleporte).
  final double snapCells;

  /// Limites de escala em vigor. Começam na faixa fixa; o mapa de jogo os troca pelos de [minWidthM] a
  /// [maxWidthM] convertidos em pixels por célula.
  double scaleMin = minScale;
  double scaleMax = maxScale;

  double _x, _y;
  double _tx, _ty;
  double _rotation = 0;
  double _scale;
  bool _touching = false;

  /// Para onde a câmera olha agora, sem o espiar.
  double get followX => _x;
  double get followY => _y;

  double get pixelsPerCell => _scale;

  /// Rotação do mapa, em radianos, no sentido horário na tela. 0 é o norte para cima.
  double get rotation => _rotation;

  bool get touching => _touching;

  /// A câmera de mapa que o renderizador usa.
  MapCamera get camera => MapCamera(centerX: _x, centerY: _y, pixelsPerCell: _scale, rotation: _rotation);

  /// Para onde seguir (a posição do Conjurador), em células z21 fracionárias.
  void setTarget(double x, double y) {
    _tx = x;
    _ty = y;
  }

  /// Vai para o alvo de uma vez, sem deslizar (a primeira posição, ou um teleporte).
  void snapToTarget() {
    _x = _tx;
    _y = _ty;
  }

  /// O dedo encostou ou saiu: só marca [touching], que o mapa usa para rasterizar mais grosso no gesto.
  void touchStart() => _touching = true;
  void touchEnd() => _touching = false;

  /// Gira o mapa para [radians] em torno do Conjurador, que não sai do centro.
  void setRotation(double radians) => _rotation = radians;

  /// Muda a escala (pinça), limitada à faixa de jogo.
  void setScale(double pixelsPerCell) {
    _scale = pixelsPerCell.clamp(scaleMin, scaleMax).toDouble();
  }

  /// Troca a faixa de escala e reaplica a atual dentro dela.
  void limitScale(double min, double max) {
    scaleMin = min;
    scaleMax = max;
    _scale = _scale.clamp(min, max).toDouble();
  }

  /// Avança [dt] segundos, seguindo o alvo com suavização.
  void update(double dt) {
    if (dt <= 0) return;
    if ((_tx - _x).abs() > snapCells || (_ty - _y).abs() > snapCells) {
      snapToTarget();
    } else {
      final a = 1 - math.exp(-dt / followTauS);
      _x += (_tx - _x) * a;
      _y += (_ty - _y) * a;
    }
  }
}
