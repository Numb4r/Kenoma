import 'package:flutter/foundation.dart' show debugPrint;

import '../../capture/eco_type.dart';
import '../../capture/session_record.dart';
import '../../capture/tuning_balance.dart';
import '../../data/session_log_store.dart';
import 'tuning_game.dart';

/// Decide com que dados cada sintonia entra no registro. Grava assim que ela termina.
///
/// No modo oculto, o jogador dá o palpite do tipo antes de a sintonia começar ([guessed]). Ao
/// terminar, o registro leva se o palpite bateu com o tipo real. Sintonia que não terminou não é gravada.
class RunLogger {
  RunLogger({required this.store, required this.balance, required this.hidden, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SessionLogStore store;
  final TuningBalance balance;
  final bool hidden;
  final DateTime Function() _clock;
  EcoType? _guess;

  /// Palpite da sintonia que vai começar, no modo oculto.
  void guessed(EcoType type) => _guess = type;

  Future<void> finished(TuningRun run) async {
    final guess = _guess;
    _guess = null;
    try {
      await store.append(SessionRecord.of(
        setup: run.setup,
        session: run.session,
        balance: balance,
        at: _clock(),
        hiddenType: hidden,
        guessCorrect: hidden && guess != null ? guess == run.setup.type : null,
      ));
    } catch (e) {
      debugPrint('Registro falhou: $e');
    }
  }
}
