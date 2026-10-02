/// O Conjurador no mapa: a posição que se desenha, suavizada entre uma leitura do GPS e outra, para o
/// marcador deslizar em vez de pular. Dart puro.
library;

import 'dart:math' as math;

class PlayerAvatar {
  PlayerAvatar({this.tauS = 0.15, this.snapCells = 200});

  /// Constante de tempo do deslizar.
  final double tauS;

  /// Distância (em células) acima da qual o marcador pula (teleporte).
  final double snapCells;

  double _x = 0, _y = 0, _tx = 0, _ty = 0;
  bool _has = false;

  /// Se já há uma posição para desenhar.
  bool get hasPosition => _has;

  /// Onde desenhar, em células z21 fracionárias.
  double get x => _x;
  double get y => _y;

  /// Para onde o marcador vai. A primeira posição aparece direto.
  void setTarget(double x, double y) {
    _tx = x;
    _ty = y;
    if (!_has) {
      _x = x;
      _y = y;
      _has = true;
    }
  }

  /// Esquece a posição: o marcador some até a próxima [setTarget].
  void clear() {
    _has = false;
  }

  void update(double dt) {
    if (!_has || dt <= 0) return;
    if ((_tx - _x).abs() > snapCells || (_ty - _y).abs() > snapCells) {
      _x = _tx;
      _y = _ty;
      return;
    }
    final a = 1 - math.exp(-dt / tauS);
    _x += (_tx - _x) * a;
    _y += (_ty - _y) * a;
  }
}
