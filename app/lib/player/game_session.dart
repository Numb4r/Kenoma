/// O estado do jogador ligado ao disco: carrega o save ao abrir (ou começa um jogo novo) e grava a cada
/// mudança. Dart puro, sem Flutter além do `ChangeNotifier`.
library;

import 'dart:async';

import 'dart:math' as math;

import '../core/seed.dart';
import '../save/founder.dart';
import '../save/migrations.dart';
import '../save/save_store.dart';
import 'game_state.dart';
import 'progress_balance.dart';

class GameSession {
  GameSession._(this.state, this._store, this._nowUtc, this._seenUtc, this._epochOf) {
    state.addListener(_changed);
  }

  /// Onde o jogo mora em disco.
  SaveStore get store => _store;

  /// Aviso da abertura para o jogador (cópia corrompida, save antigo migrado), ou `null`.
  String? loadNote;

  /// Chamado a cada gravação com o `last_seen_utc`: o relógio do jogo não volta para antes dele.
  void Function(int lastSeenUtc)? onSeen;
  final int Function(int nowUtc)? _epochOf;

  /// O relógio real, sem o override do debug: é ele que marca `last_seen_utc` e o registro de fundador.
  final int Function() _seenUtc;

  /// Abre o save. Sem save, cria um jogo novo com a seed sorteada por [nextInt] e o inventário inicial.
  static Future<GameSession> open({
    required SaveStore store,
    required Map<String, int> startInventory,
    required ProgressBalance balance,
    required int Function() nowUtc,
    required int Function(int n) nextInt,
    String appVersion = '',
    int Function(int nowUtc)? epochOf,
    int Function()? seenUtc,
    List<int> Function(int n)? randomBytes,
  }) async {
    final raw = await store.read();
    final json = raw == null ? null : migrateSave(raw);
    // O menu de debug pode ter gravado só o override de nível antes de existir um jogo: aí o jogo nasce com ele.
    final hasGame = json?['group_code'] != null;
    final state = hasGame
        ? GameState.fromJson(json!, balance)
        : (GameState.fresh(groupCode: generateGroupCode(nextInt), startInventory: startInventory, balance: balance)
          ..levelOverride = json?['level_override'] as int?);
    final now = nowUtc();
    final seen = (seenUtc ?? nowUtc)();
    state
      ..appVersion = appVersion
      ..epochId = epochOf?.call(now) ?? 0
      ..createdUtc ??= seen;
    // Registro de fundador: o player_id nasce na primeira abertura, e cada versão nova entra no log.
    state.founder ??= Founder.create(randomBytes: randomBytes ?? _secureBytes, version: appVersion.isEmpty ? 'dev' : appVersion, utc: seen);
    final versionAdded = state.founder!.noteVersion(appVersion.isEmpty ? 'dev' : appVersion, seen);
    final session = GameSession._(state, store, nowUtc, seenUtc ?? nowUtc, epochOf);
    session.loadNote = store.loadNote;
    if (versionAdded || !hasGame || (raw?['schema_version'] ?? 1) != saveSchemaVersion) await session.save();
    return session;
  }

  final GameState state;
  final SaveStore _store;
  final int Function() _nowUtc;
  Future<void> _last = Future.value();

  void _changed() => unawaited(save());

  /// Grava o estado de agora. As gravações saem em fila, uma de cada vez.
  Future<void> save() {
    final now = _nowUtc();
    final seen = _seenUtc();
    if (seen > state.lastSeenUtc) state.lastSeenUtc = seen;
    state.epochId = _epochOf?.call(now) ?? state.epochId;
    onSeen?.call(state.lastSeenUtc);
    return _last = _last.then((_) => _store.write(state.toJson(now)));
  }

  /// Espera as gravações pendentes.
  Future<void> flush() => _last;

  void dispose() => state.removeListener(_changed);
}

/// Bytes do gerador seguro do sistema: o `player_id` não é lógica de mundo, então não usa o PCG32 do jogo.
List<int> _secureBytes(int n) {
  final r = math.Random.secure();
  return [for (var i = 0; i < n; i++) r.nextInt(256)];
}
