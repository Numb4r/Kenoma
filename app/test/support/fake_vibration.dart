import 'package:kenoma/capture/vibe.dart';
import 'package:kenoma/ui/tuning/vibration_driver.dart';

/// Guarda o que teria vibrado.
class FakeVibration implements VibrationPlayer {
  final played = <VibePattern>[];
  int cancels = 0;

  @override
  Future<void> play(VibePattern pattern) async => played.add(pattern);

  @override
  Future<void> cancel() async => cancels++;
}
