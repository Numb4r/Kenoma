import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vibration/vibration.dart';

import '../../capture/vibe.dart';

/// Quem toca os padrões de vibração. A tela conversa só com esta interface.
abstract class VibrationPlayer {
  Future<void> play(VibePattern pattern);
  Future<void> cancel();
}

/// Vibra o aparelho com o pacote `vibration` (o `HapticFeedback` não faz padrão).
/// Sem motor ou sem controle de amplitude, degrada para liga e desliga com a mesma duração.
class DeviceVibration implements VibrationPlayer {
  bool? _hasVibrator;
  bool? _hasAmplitude;

  @override
  Future<void> play(VibePattern pattern) async {
    try {
      _hasVibrator ??= await Vibration.hasVibrator();
      if (!_hasVibrator!) return;
      _hasAmplitude ??= await Vibration.hasAmplitudeControl();
      await Vibration.vibrate(
        pattern: pattern.pattern,
        intensities: _hasAmplitude! ? pattern.intensities : const [],
      );
    } catch (e) {
      debugPrint('Vibração falhou: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Vibração falhou ao cancelar: $e');
    }
  }
}
