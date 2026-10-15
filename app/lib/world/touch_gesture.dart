/// Classifica o dedo no mapa de jogo: toque curto, toque longo ou arrasto (que gira o mapa). Dart puro: a tela
/// repassa os eventos de ponteiro e um temporizador que chama [longPress].
///
/// Um segundo dedo cancela o gesto (é pinça, que só dá zoom). Passado o limiar de distância [slopPx] o gesto
/// vira arrasto e deixa de poder ser toque ou toque longo.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

class TouchGesture {
  TouchGesture({this.slopPx = 12, this.longPressMs = 500, this.minRadiusPx = 40});

  /// Quanto o dedo pode andar e ainda contar como parado.
  final double slopPx;

  /// Distância mínima do dedo ao centro para o giro valer.
  final double minRadiusPx;

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

  /// O dedo andou. Devolve o quanto o mapa deve girar, em radianos (positivo = sentido horário na tela), ou 0 se
  /// ainda não é arrasto. O mapa gira em torno de [center] (o Conjurador, no centro da tela) e acompanha o dedo:
  /// o ponto do mapa que está sob o dedo continua sob ele, de qualquer lado da tela. Perto demais do centro o
  /// ângulo do dedo não é confiável e o giro espera. O primeiro movimento depois do limiar conta desde o ponto
  /// onde o dedo desceu, então o mapa não fica para trás do dedo.
  double move(Offset pos, {required Offset center}) {
    if (!_active) return 0;
    if (!_dragging) {
      if ((pos - _start).distance <= slopPx) return 0;
      _dragging = true;
      return _turn(_start, pos, center);
    }
    final turn = _turn(_last, pos, center);
    _last = pos;
    return turn;
  }

  double _turn(Offset from, Offset to, Offset center) {
    _last = to;
    final a = from - center, b = to - center;
    if (a.distance < minRadiusPx || b.distance < minRadiusPx) return 0;
    var d = math.atan2(b.dy, b.dx) - math.atan2(a.dy, a.dx);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  /// Chamado pelo temporizador de [longPressMs], armado quando o dedo desce: se o dedo segue parado, devolve
  /// o ponto do toque longo, uma vez. Arrastar, soltar ou um segundo dedo cancelam o temporizador e o gesto.
  Offset? longPress() {
    if (!pendingLongPress) return null;
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
