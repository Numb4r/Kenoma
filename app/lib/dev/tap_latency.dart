/// Mede o tempo do dedo encostar na tela até o primeiro quadro pronto depois dele (onde aparece o retorno do toque), para o
/// menu de debug. A meta é 100 ms. O instante do toque e o do quadro vêm do relógio monotônico do aparelho.
library;

import 'dart:ui' show FrameTiming, FramePhase;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

class TapLatency {
  TapLatency._();

  static final TapLatency instance = TapLatency._();

  /// Os últimos [maxSamples] tempos, em milissegundos.
  final List<double> samples = [];
  static const int maxSamples = 60;

  Duration? _pending;
  bool _started = false;

  /// Liga a medição (uma vez). Sem custo enquanto ninguém toca.
  void start() {
    if (_started) return;
    _started = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((e) {
      if (e is PointerDownEvent) _pending = e.timeStamp;
    });
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    final down = _pending;
    if (down == null) return;
    for (final t in timings) {
      final vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      if (vsync < down.inMicroseconds - 1000) continue; // quadro que já tinha começado antes do toque
      final ms = (t.timestampInMicroseconds(FramePhase.rasterFinish) - down.inMicroseconds) / 1000;
      _pending = null;
      if (ms >= 0 && ms < 2000) {
        samples.add(ms);
        if (samples.length > maxSamples) samples.removeAt(0);
      }
      return;
    }
  }

  double? get median {
    if (samples.isEmpty) return null;
    final s = [...samples]..sort();
    return s[s.length ~/ 2];
  }

  double? get worst => samples.isEmpty ? null : samples.reduce((a, b) => a > b ? a : b);

  void clear() => samples.clear();
}
