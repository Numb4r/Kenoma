import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vibration/vibration.dart';

import '../../capture/vibe.dart';

/// Quem toca os padrões de vibração. A tela conversa só com esta interface.
abstract class VibrationPlayer {
  Future<void> play(VibePattern pattern);
  Future<void> cancel();
}

/// Vibra o aparelho com o pacote `vibration` (o `HapticFeedback` não faz padrão).
/// Sem controle de amplitude (o moto g54 não tem), simula a intensidade com [VibePattern.toOnOff].
class DeviceVibration implements VibrationPlayer {
  bool? _hasVibrator;
  bool? _hasAmplitude;

  @override
  Future<void> play(VibePattern pattern) async {
    try {
      _hasVibrator ??= await Vibration.hasVibrator();
      if (!_hasVibrator!) return;
      _hasAmplitude ??= await Vibration.hasAmplitudeControl();
      if (_hasAmplitude!) {
        await Vibration.vibrate(pattern: pattern.pattern, intensities: pattern.intensities);
      } else {
        // Sem controle de amplitude a intensidade vira liga e desliga rápido.
        await Vibration.vibrate(pattern: pattern.toOnOff().pattern);
      }
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
