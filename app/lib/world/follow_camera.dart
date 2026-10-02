/// Câmera de jogo: segue o Conjurador com suavização. Arrastar espia em volta e, depois de
/// [returnAfterS] segundos sem toque, a câmera volta sozinha. O zoom fica numa faixa de jogo, menor que
/// a da câmera livre do debug. Dart puro: quem dirige o tempo é [update].
library;

import 'dart:math' as math;

import 'map_camera.dart';

class FollowCamera {
  FollowCamera({
    required double x,
    required double y,
    double pixelsPerCell = defaultScale,
    this.followTauS = 0.25,
    this.returnAfterS = 3.0,
    this.returnTauS = 0.3,
    this.maxPeekCells = 40,
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

  /// Segundos sem toque até o espiar voltar.
  final double returnAfterS;

  /// Constante de tempo da volta do espiar.
  final double returnTauS;

  /// Quanto dá para espiar, em células, para cada lado.
  final double maxPeekCells;

  /// Distância (em células) acima da qual a câmera pula em vez de deslizar (teleporte).
  final double snapCells;

  double _x, _y;
  double _tx, _ty;
  double _peekX = 0, _peekY = 0;
  double _scale;
  bool _touching = false;
  double _idleS = 0;

  /// Para onde a câmera olha agora, sem o espiar.
  double get followX => _x;
  double get followY => _y;

  /// O quanto ela está espiando, em células.
  double get peekX => _peekX;
  double get peekY => _peekY;

  double get pixelsPerCell => _scale;

  /// Se está espiando (afastada do Conjurador pelo arrasto).
  bool get peeking => _peekX != 0 || _peekY != 0;

  bool get touching => _touching;

  /// A câmera de mapa que o renderizador usa.
  MapCamera get camera => MapCamera(centerX: _x + _peekX, centerY: _y + _peekY, pixelsPerCell: _scale);

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

  /// O dedo encostou: o espiar fica onde está e o relógio de volta zera.
  void touchStart() {
    _touching = true;
    _idleS = 0;
  }

  /// O dedo saiu: começa a contar [returnAfterS].
  void touchEnd() {
    _touching = false;
    _idleS = 0;
  }

  /// Arrastar o dedo [dx], [dy] pixels espia: o mapa anda junto com o dedo, então o olhar vai para o
  /// outro lado. Limitado a [maxPeekCells].
  void dragBy(double dx, double dy) {
    _idleS = 0;
    var px = _peekX - dx / _scale, py = _peekY - dy / _scale;
    final len = math.sqrt(px * px + py * py);
    if (len > maxPeekCells) {
      px *= maxPeekCells / len;
      py *= maxPeekCells / len;
    }
    _peekX = px;
    _peekY = py;
  }

  /// Muda a escala (pinça), limitada à faixa de jogo.
  void setScale(double pixelsPerCell) {
    _idleS = 0;
    _scale = pixelsPerCell.clamp(minScale, maxScale).toDouble();
  }

  /// Avança [dt] segundos: segue o alvo com suavização e, passados [returnAfterS] sem toque, traz o
  /// espiar de volta.
  void update(double dt) {
    if (dt <= 0) return;
    if ((_tx - _x).abs() > snapCells || (_ty - _y).abs() > snapCells) {
      snapToTarget();
    } else {
      final a = 1 - math.exp(-dt / followTauS);
      _x += (_tx - _x) * a;
      _y += (_ty - _y) * a;
    }
    if (!_touching) {
      _idleS += dt;
      if (_idleS >= returnAfterS && peeking) {
        final b = 1 - math.exp(-dt / returnTauS);
        _peekX -= _peekX * b;
        _peekY -= _peekY * b;
        if (_peekX.abs() < 0.005 && _peekY.abs() < 0.005) {
          _peekX = 0;
          _peekY = 0;
        }
      }
    }
  }
}
