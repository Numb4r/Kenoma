/// Classifica o dedo no mapa de jogo: toque curto, toque longo ou arrasto (que gira o mapa). Dart puro: a tela
/// repassa os eventos de ponteiro e um temporizador que chama [checkLongPress].
///
/// Um segundo dedo cancela o gesto (é pinça, que só dá zoom). Passado o limiar de distância [slopPx] o gesto
/// vira arrasto e deixa de poder ser toque ou toque longo.
library;

import 'dart:ui' show Offset;

class TouchGesture {
  TouchGesture({this.slopPx = 12, this.longPressMs = 500});

  /// Quanto o dedo pode andar e ainda contar como parado.
  final double slopPx;

  /// Quanto tempo parado vira toque longo; abaixo disso, soltar é um toque.
  final int longPressMs;

  int _pointers = 0;
  bool _active = false;
  bool _dragging = false;
  bool _longFired = false;
  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  int _downMs = 0;

  bool get dragging => _dragging;

  /// Se há um gesto de um dedo que ainda pode virar toque longo.
  bool get pendingLongPress => _active && !_dragging && !_longFired;

  void down(Offset pos, int tMs) {
    _pointers++;
    if (_pointers == 1) {
      _active = true;
      _dragging = false;
      _longFired = false;
      _start = _last = pos;
      _downMs = tMs;
    } else {
      _active = false; // dois dedos: pinça
    }
  }

  /// O dedo andou. Devolve o deslocamento horizontal do arrasto desde o último evento, ou 0 se ainda não é
  /// arrasto. O primeiro movimento depois do limiar conta só a partir do ponto em que o limiar foi vencido,
  /// então o mapa não dá salto.
  double move(Offset pos) {
    if (!_active) return 0;
    if (!_dragging) {
      if ((pos - _start).distance <= slopPx) return 0;
      _dragging = true;
      _last = pos;
      return 0;
    }
    final dx = pos.dx - _last.dx;
    _last = pos;
    return dx;
  }

  /// Chamado pelo temporizador: se o dedo segue parado há [longPressMs], devolve o ponto do toque longo uma vez.
  Offset? checkLongPress(int nowMs) {
    if (!pendingLongPress || nowMs - _downMs < longPressMs) return null;
    _longFired = true;
    return _start;
  }

  /// O dedo saiu. Devolve o ponto do toque se foi um toque curto.
  Offset? up(Offset pos, int tMs) {
    final tap = _active && !_dragging && !_longFired && tMs - _downMs < longPressMs ? pos : null;
    _release();
    return tap;
  }

  void cancel() => _release();

  void _release() {
    if (_pointers > 0) _pointers--;
    _active = false;
    _dragging = false;
  }
}
