/// Modo bolso (opcional): com o sensor de proximidade coberto a tela escurece quase toda. Este é o estado
/// coberto/descoberto, com debounce de 300 ms para o sensor não piscar a tela. A sobreposição fica em
/// `ui/game/pocket_overlay.dart`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class PocketMode extends ChangeNotifier {
  PocketMode({this.debounce = const Duration(milliseconds: 300)});

  final Duration debounce;
  bool _covered = false;
  Timer? _timer;

  /// Coberto de forma estável (a leitura bruta durou ao menos [debounce]).
  bool get covered => _covered;

  /// Uma leitura bruta do sensor. Só vira estado se não mudar de novo dentro do [debounce].
  void onProximity(bool raw) {
    _timer?.cancel();
    _timer = null;
    if (raw == _covered) return;
    _timer = Timer(debounce, () {
      _timer = null;
      _covered = raw;
      notifyListeners();
    });
  }

  /// Volta ao normal (modo desligado ou tela fechada).
  void reset() {
    _timer?.cancel();
    _timer = null;
    if (!_covered) return;
    _covered = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A vibração do aviso só toca com o modo ligado e o sensor coberto.
bool shouldBuzz({required bool enabled, required bool covered}) => enabled && covered;
