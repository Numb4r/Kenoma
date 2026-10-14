/// O que o jogador tem e fez: inventário, coleção e o registro do que já foi coletado, capturado ou
/// fugiu. Dart puro. O formato completo do save fica para o M10; este é o mínimo para nada se perder
/// ao fechar o app.
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/seed.dart';

/// O registro guarda só as últimas 48 horas (docs/fase0-spec.md, seção 3).
const int registryKeepSeconds = 48 * 3600;

const int saveSchemaVersion = 1;

/// Uma criatura capturada. O uid é o do spawn de onde ela veio.
class CreatureInstance {
  const CreatureInstance({required this.uid, required this.speciesId, required this.level, required this.capturedUtc, this.xp = 0});

  factory CreatureInstance.fromJson(Map<String, dynamic> j) => CreatureInstance(
        uid: j['uid'] as String,
        speciesId: j['species'] as String,
        level: j['level'] as int,
        xp: (j['xp'] as int?) ?? 0,
        capturedUtc: j['captured_utc'] as int,
      );

  /// Uid do spawn, em texto (o inteiro de 64 bits com sinal, em decimal).
  final String uid;
  final String speciesId;
  final int level;
  final int xp;
  final int capturedUtc;

  Map<String, dynamic> toJson() => {'uid': uid, 'species': speciesId, 'level': level, 'xp': xp, 'captured_utc': capturedUtc};
}

class GameState extends ChangeNotifier {
  GameState({
    required this.groupCode,
    Map<String, int>? inventory,
    List<CreatureInstance>? collection,
    Map<String, int>? collected,
    this.playerLevel = 1,
    Map<String, dynamic>? extra,
  })  : inventory = {...?inventory},
        collection = [...?collection],
        _collected = {...?collected},
        _extra = {...?extra};

  /// Jogo novo: seed nova e o inventário inicial do `balance.json`.
  factory GameState.fresh({required String groupCode, required Map<String, int> startInventory}) =>
      GameState(groupCode: groupCode, inventory: startInventory);

  factory GameState.fromJson(Map<String, dynamic> j) {
    const known = {'schema_version', 'group_code', 'player_level', 'inventory', 'collection', 'collected', 'saved_utc'};
    return GameState(
      groupCode: j['group_code'] as String,
      playerLevel: (j['player_level'] as int?) ?? 1,
      inventory: {for (final e in ((j['inventory'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      collection: [for (final c in (j['collection'] as List<dynamic>?) ?? const []) CreatureInstance.fromJson(c as Map<String, dynamic>)],
      collected: {for (final e in ((j['collected'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      // Campos que esta versão não conhece são preservados (spec, seção 10).
      extra: {for (final e in j.entries) if (!known.contains(e.key)) e.key: e.value},
    );
  }

  /// Código do grupo: a seed do mundo vem dele.
  final String groupCode;
  int playerLevel;
  final Map<String, int> inventory;
  final List<CreatureInstance> collection;
  final Map<String, int> _collected;
  final Map<String, dynamic> _extra;

  late final int seed = seedGlobal(groupCode);

  int count(String itemId) => inventory[itemId] ?? 0;

  void add(String itemId, int n) {
    if (n <= 0) return;
    inventory[itemId] = count(itemId) + n;
    notifyListeners();
  }

  /// Gasta uma unidade. `false` se não há.
  bool take(String itemId) {
    final have = count(itemId);
    if (have <= 0) return false;
    if (have == 1) {
      inventory.remove(itemId);
    } else {
      inventory[itemId] = have - 1;
    }
    notifyListeners();
    return true;
  }

  static String uidKey(int uid) => uid.toString();

  /// Se o spawn já foi coletado, capturado ou fugiu: não aparece de novo.
  bool isDone(int uid) => _collected.containsKey(uidKey(uid));

  /// Registra o uid em [nowUtc] e limpa o que passou de 48 horas.
  void markDone(int uid, int nowUtc) {
    _collected[uidKey(uid)] = nowUtc;
    _collected.removeWhere((_, at) => nowUtc - at > registryKeepSeconds);
    notifyListeners();
  }

  int get registrySize => _collected.length;

  /// A criatura entra na coleção e o spawn some do registro de vivos.
  CreatureInstance capture({required int uid, required String speciesId, required int level, required int nowUtc}) {
    final c = CreatureInstance(uid: uidKey(uid), speciesId: speciesId, level: level, capturedUtc: nowUtc);
    collection.add(c);
    markDone(uid, nowUtc);
    return c;
  }

  Map<String, dynamic> toJson(int nowUtc) => {
        ..._extra,
        'schema_version': saveSchemaVersion,
        'group_code': groupCode,
        'player_level': playerLevel,
        'saved_utc': nowUtc,
        'inventory': inventory,
        'collection': [for (final c in collection) c.toJson()],
        'collected': _collected,
      };
}
