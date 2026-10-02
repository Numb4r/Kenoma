/// O relógio UTC do jogo, com override para testar épocas, janelas e o mundo desatualizado sem mexer
/// no relógio do aparelho. Sem override é o relógio real. Tempo do jogo é sempre UTC (CLAUDE.md, regra 3).
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

class GameClock extends ChangeNotifier {
  GameClock({int Function()? realNowMs}) : _realNowMs = realNowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _realNowMs;
  int? _offsetMs;

  /// Se o relógio está sobreposto.
  bool get overridden => _offsetMs != null;

  /// Agora, em milissegundos UTC desde a época Unix.
  int get nowMs => _realNowMs() + (_offsetMs ?? 0);

  /// Agora, em segundos UTC: a unidade das janelas e das épocas.
  int get nowUtc => nowMs ~/ 1000;

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);

  /// Faz o relógio marcar [utcSeconds] agora e continuar andando a partir daí.
  void setUtc(int utcSeconds) {
    _offsetMs = utcSeconds * 1000 - _realNowMs();
    notifyListeners();
  }

  /// Volta ao relógio real.
  void clear() {
    if (_offsetMs == null) return;
    _offsetMs = null;
    notifyListeners();
  }
}
