/// O relógio UTC do jogo, com override para testar épocas, janelas e o mundo desatualizado sem mexer
/// no relógio do aparelho. Sem override é o relógio real. Tempo do jogo é sempre UTC (CLAUDE.md, regra 3).
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

class GameClock extends ChangeNotifier {
  GameClock({int Function()? realNowMs}) : _realNowMs = realNowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _realNowMs;
  int? _offsetMs;
  int _floorMs = 0;

  /// Se o relógio está sobreposto.
  bool get overridden => _offsetMs != null;

  /// Agora, em milissegundos UTC desde a época Unix.
  int get nowMs => _offsetMs != null ? _realNowMs() + _offsetMs! : _floorMs > _realNowMs() ? _floorMs : _realNowMs();

  /// O relógio real, sem override nem piso.
  int get realNowUtc => _realNowMs() ~/ 1000;

  /// Piso do relógio: se o relógio do aparelho voltar para antes de [lastSeenUtc], o jogo usa [lastSeenUtc]
  /// (docs/fase0-spec.md, seção 10). O override do debug passa por cima.
  void raiseFloor(int lastSeenUtc) {
    if (lastSeenUtc * 1000 > _floorMs) _floorMs = lastSeenUtc * 1000;
  }

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
