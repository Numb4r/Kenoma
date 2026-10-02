/// Ferramentas de dev reunidas: a fonte de posição trocável (GPS real ou simulador) e o relógio com
/// override. Mora no menu de debug, que fica em todas as builds de teste (CLAUDE.md).
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../world/places.dart';
import '../world/position_source.dart';
import 'game_clock.dart';
import 'gps_simulator.dart';

class DevTools extends ChangeNotifier {
  DevTools({required PositionSource realSource, SimulatedPositionSource? simulator, GameClock? clock})
      : simulator = simulator ?? SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2),
        clock = clock ?? GameClock(),
        _real = realSource {
    source = SwitchablePositionSource(realSource);
  }

  final PositionSource _real;

  /// O simulador. Sempre existe: usá-lo ou não é o [useSimulator].
  final SimulatedPositionSource simulator;
  final GameClock clock;

  /// A fonte que o jogo ouve. Troca entre o GPS real e o simulador sem o jogo perceber.
  late final SwitchablePositionSource source;

  bool _useSimulator = false;

  bool get useSimulator => _useSimulator;

  Future<void> setUseSimulator(bool value) async {
    if (value == _useSimulator) return;
    _useSimulator = value;
    await source.switchTo(value ? simulator : _real);
    notifyListeners();
  }
}
