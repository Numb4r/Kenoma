import 'package:flutter/foundation.dart' show debugPrint;

import '../../capture/session_record.dart';
import '../../capture/tuning_balance.dart';
import '../../data/session_log_store.dart';
import 'tuning_game.dart';

/// Decide quando e com que dados cada sintonia entra no registro.
///
/// Fora do modo oculto, grava assim que a sintonia termina. No modo oculto, espera o jogador marcar
/// se acertou o tipo; se ele sair sem marcar, grava com o acerto em branco.
class RunLogger {
  RunLogger({required this.store, required this.balance, required this.hidden, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SessionLogStore store;
  final TuningBalance balance;
  final bool hidden;
  final DateTime Function() _clock;
  TuningRun? _pending;

  bool get hasPending => _pending != null;

  Future<void> finished(TuningRun run) async {
    await flush(); // uma sintonia oculta anterior sem marcação não se perde
    if (hidden) {
      _pending = run;
    } else {
      await _write(run, null);
    }
  }

  /// O jogador marcou se acertou o tipo da sintonia oculta que espera.
  Future<void> guess(bool correct) async {
    final run = _pending;
    if (run == null) return;
    _pending = null;
    await _write(run, correct);
  }

  /// Grava a sintonia oculta que ficou sem marcação, com o acerto em branco.
  Future<void> flush() async {
    final run = _pending;
    if (run == null) return;
    _pending = null;
    await _write(run, null);
  }

  Future<void> _write(TuningRun run, bool? guessCorrect) async {
    try {
      await store.append(SessionRecord.of(
        setup: run.setup,
        session: run.session,
        balance: balance,
        at: _clock(),
        hiddenType: hidden,
        guessCorrect: guessCorrect,
      ));
    } catch (e) {
      debugPrint('Registro falhou: $e');
    }
  }
}
