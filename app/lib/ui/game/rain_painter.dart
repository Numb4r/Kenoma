/// Chuva leve sobre o mapa, em pixels: riscos finos que caem inclinados, na cor do texto com pouca opacidade. A
/// quantidade acompanha o clima (chuva ou tempestade) e sobe e desce devagar, sem corte. Só visual e desligável.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../colors.dart';

class _Drop {
  _Drop(this.x, this.y, this.speed);

  double x, y;
  final double speed;
}

class RainPainter {
  RainPainter({this.maxDrops = 70});

  /// Quantas gotas há com chuva normal; a tempestade pede 1,6 vezes mais.
  final int maxDrops;

  final _drops = <_Drop>[];
  double _level = 0;
  int _seed = 12345;
  final ui.Paint _paint = ui.Paint()..strokeWidth = 2..strokeCap = ui.StrokeCap.butt..isAntiAlias = false;

  /// Gotas na tela agora.
  int get count => _drops.length;

  double _next() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff; // só a posição das gotas na tela, nada do mundo
    return _seed / 0x7fffffff;
  }

  /// Avança [dt] segundos. [target] é 0 sem chuva, 1 com chuva e 1,6 com tempestade.
  void update(double dt, ui.Size view, double target) {
    _level += (target - _level) * (1 - math.exp(-dt / 1.2));
    if (_level < 0.02 && target == 0) {
      _drops.clear();
      return;
    }
    final want = (maxDrops * _level).round();
    while (_drops.length < want) {
      _drops.add(_Drop(_next() * view.width, -_next() * view.height * 0.3, 380 + _next() * 220));
    }
    if (_drops.length > want + 6) _drops.removeRange(want, _drops.length);
    for (final d in _drops) {
      d.y += d.speed * dt;
      d.x -= d.speed * 0.28 * dt;
      if (d.y > view.height || d.x < -10) {
        d.y = -_next() * 40;
        d.x = _next() * (view.width + 60);
      }
    }
  }

  void paint(ui.Canvas canvas) {
    if (_drops.isEmpty) return;
    _paint.color = kText.withValues(alpha: 0.34);
    for (final d in _drops) {
      canvas.drawLine(ui.Offset(d.x, d.y), ui.Offset(d.x - 2.5, d.y + 9), _paint);
    }
  }
}
