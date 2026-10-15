/// O estado do jogador ligado ao disco: carrega o save ao abrir (ou começa um jogo novo) e grava a cada
/// mudança. Dart puro, sem Flutter além do `ChangeNotifier`.
library;

import 'dart:async';

import '../core/seed.dart';
import '../save/migrations.dart';
import '../save/save_store.dart';
import 'game_state.dart';
import 'progress_balance.dart';

class GameSession {
  GameSession._(this.state, this._store, this._nowUtc) {
    state.addListener(_changed);
  }

  /// Abre o save. Sem save, cria um jogo novo com a seed sorteada por [nextInt] e o inventário inicial.
  static Future<GameSession> open({
    required SaveStore store,
    required Map<String, int> startInventory,
    required ProgressBalance balance,
    required int Function() nowUtc,
    required int Function(int n) nextInt,
  }) async {
    final raw = await store.read();
    final json = raw == null ? null : migrateSave(raw);
    // O menu de debug pode ter gravado só o override de nível antes de existir um jogo: aí o jogo nasce com ele.
    final hasGame = json?['group_code'] != null;
    final state = hasGame
        ? GameState.fromJson(json!, balance)
        : (GameState.fresh(groupCode: generateGroupCode(nextInt), startInventory: startInventory, balance: balance)
          ..levelOverride = json?['level_override'] as int?);
    final session = GameSession._(state, store, nowUtc);
    if (!hasGame || (raw?['schema_version'] ?? 1) != saveSchemaVersion) await session.save();
    return session;
  }

  final GameState state;
  final SaveStore _store;
  final int Function() _nowUtc;
  Future<void> _last = Future.value();

  void _changed() => unawaited(save());

  /// Grava o estado de agora. As gravações saem em fila, uma de cada vez.
  Future<void> save() => _last = _last.then((_) => _store.write(state.toJson(_nowUtc())));

  /// Espera as gravações pendentes.
  Future<void> flush() => _last;

  void dispose() => state.removeListener(_changed);
}
