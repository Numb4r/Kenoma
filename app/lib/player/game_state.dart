/// O que o jogador tem e fez: nível e XP, inventário, coleção, Círculo, bestiário, marcações e o registro do
/// que já foi coletado, capturado ou fugiu. Dart puro. Tudo vai para o `save.json` (schema 2).
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/seed.dart';
import '../save/founder.dart';
import 'bestiary.dart';
import 'mark.dart';
import 'progress_balance.dart';
import 'progression.dart';

/// O registro guarda só as últimas 48 horas (docs/fase0-spec.md, seção 3).
const int registryKeepSeconds = 48 * 3600;

const int saveSchemaVersion = 2;

/// Uma criatura capturada. O uid é o do spawn de onde ela veio.
class CreatureInstance {
  const CreatureInstance({required this.uid, required this.speciesId, required this.level, required this.capturedUtc, this.xp = 0});

  /// Cópia com [level] e [xp] novos.
  CreatureInstance advanced({required int level, required int xp}) =>
      CreatureInstance(uid: uid, speciesId: speciesId, level: level, capturedUtc: capturedUtc, xp: xp);

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
    required this.balance,
    Map<String, int>? inventory,
    List<CreatureInstance>? collection,
    Map<String, int>? collected,
    PlayerProgress? progress,
    this.levelOverride,
    List<String>? circle,
    Map<String, BestiaryEntry>? bestiary,
    List<Mark>? marks,
    this.founder,
    this.createdUtc,
    Map<String, dynamic>? settings,
    this.lastSeenUtc = 0,
    Map<String, dynamic>? extra,
  })  : inventory = {...?inventory},
        collection = [...?collection],
        _collected = {...?collected},
        progress = progress ?? PlayerProgress(balance: balance),
        circle = [...?circle],
        bestiary = {...?bestiary},
        marks = [...?marks],
        settings = {...?settings},
        _extra = {...?extra};

  /// Jogo novo: seed nova e o inventário inicial do `balance.json`.
  factory GameState.fresh({required String groupCode, required Map<String, int> startInventory, required ProgressBalance balance}) =>
      GameState(groupCode: groupCode, balance: balance, inventory: startInventory);

  factory GameState.fromJson(Map<String, dynamic> j, ProgressBalance balance) {
    const known = {
      'schema_version', 'group_code', 'player', 'level_override', 'inventory', 'collection', 'collected', 'circle', 'bestiary', 'marks', 'saved_utc',
      'founder', 'created_utc', 'last_seen_utc', 'app_version', 'epoch', 'settings',
    };
    final progress = PlayerProgress.fromJson(j['player'] as Map<String, dynamic>?, balance)..settleBanked();
    return GameState(
      groupCode: j['group_code'] as String,
      balance: balance,
      progress: progress,
      levelOverride: j['level_override'] as int?,
      inventory: {for (final e in ((j['inventory'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      collection: [for (final c in (j['collection'] as List<dynamic>?) ?? const []) CreatureInstance.fromJson(c as Map<String, dynamic>)],
      collected: {for (final e in ((j['collected'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      circle: [for (final u in (j['circle'] as List<dynamic>?) ?? const []) u as String],
      bestiary: {
        for (final e in ((j['bestiary'] as Map<String, dynamic>?) ?? const {}).entries) e.key: BestiaryEntry.fromJson(e.value as Map<String, dynamic>),
      },
      marks: [for (final m in (j['marks'] as List<dynamic>?) ?? const []) Mark.fromJson(m as Map<String, dynamic>)],
      founder: j['founder'] == null ? null : Founder.fromJson(j['founder'] as Map<String, dynamic>),
      createdUtc: j['created_utc'] as int?,
      lastSeenUtc: (j['last_seen_utc'] as int?) ?? 0,
      settings: {...?(j['settings'] as Map<String, dynamic>?)},
      // Campos que esta versão não conhece são preservados (spec, seção 10).
      extra: {for (final e in j.entries) if (!known.contains(e.key)) e.key: e.value},
    );
  }

  /// Código do grupo: a seed do mundo vem dele.
  String groupCode;
  final ProgressBalance balance;
  final PlayerProgress progress;

  /// Nível forçado pelo menu de debug. `null`: vale o nível real.
  int? levelOverride;
  final Map<String, int> inventory;
  final List<CreatureInstance> collection;
  final Map<String, int> _collected;
  final Map<String, dynamic> _extra;

  /// Uids das criaturas ativas no Círculo, no máximo 3.
  final List<String> circle;
  final Map<String, BestiaryEntry> bestiary;
  final List<Mark> marks;

  /// Registro de fundador (`player_id`, primeira versão e log de versões). `null` num jogo ainda sem registro.
  Founder? founder;

  /// Quando o jogo nasceu e o último instante em que o app esteve aberto (relógio que volta não passa dele).
  int? createdUtc;
  int lastSeenUtc;

  /// Versão do app e época de quando o save foi gravado (o cabeçalho da spec).
  String appVersion = '';
  int epochId = 0;

  /// Interruptores do jogador: `street_names` e `follow_heading`.
  final Map<String, dynamic> settings;

  int get seed => seedGlobal(groupCode);

  /// O nível que o jogo usa: o do debug, se houver, senão o real. Define o nível dos Ecos e a resistência.
  int get playerLevel => levelOverride ?? progress.level;

  /// Entra noutro grupo: a seed muda, então o registro de coletas e as marcações (que são do mundo antigo) saem.
  /// A coleção, o Círculo, o inventário e o nível ficam. `false` se o código é o mesmo.
  bool changeGroup(String code) {
    if (normalizeSeedCode(code) == normalizeSeedCode(groupCode)) return false;
    groupCode = formatGroupCode(code);
    _collected.clear();
    marks.clear();
    notifyListeners();
    return true;
  }

  /// Guarda um interruptor do jogador (`street_names`, `follow_heading`).
  void setSetting(String key, Object value) {
    if (settings[key] == value) return;
    settings[key] = value;
    notifyListeners();
  }

  bool setting(String key) => settings[key] == true;

  int count(String itemId) => inventory[itemId] ?? 0;

  /// Ganha XP de Conjurador em [nowUtc]. Devolve quantos níveis subiu.
  int gainXp(int raw, int nowUtc) {
    final up = progress.gain(raw, nowUtc);
    notifyListeners();
    return up;
  }

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

  /// Fabrica uma receita se há todos os ingredientes. `false` se falta algum.
  bool craft(Map<String, int> inputs, String outId, int outQty) {
    if (inputs.entries.any((e) => count(e.key) < e.value)) return false;
    for (final e in inputs.entries) {
      final left = count(e.key) - e.value;
      left == 0 ? inventory.remove(e.key) : inventory[e.key] = left;
    }
    inventory[outId] = count(outId) + outQty;
    notifyListeners();
    return true;
  }

  static String uidKey(int uid) => uid.toString();

  /// Se o spawn já foi coletado, capturado ou fugiu: não aparece de novo.
  bool isDone(int uid) => _collected.containsKey(uidKey(uid));

  /// Registra o uid em [nowUtc] e limpa o que passou de 48 horas. Uma marcação desse uid acaba.
  void markDone(int uid, int nowUtc) {
    _collected[uidKey(uid)] = nowUtc;
    _collected.removeWhere((_, at) => nowUtc - at > registryKeepSeconds);
    marks.removeWhere((m) => m.uid == uidKey(uid));
    notifyListeners();
  }

  int get registrySize => _collected.length;

  bool hasCaptured(String speciesId) => bestiary[speciesId]?.captured ?? false;

  /// A espécie apareceu na visão do jogador.
  void markSeen(String speciesId) {
    if (bestiary[speciesId]?.seen ?? false) return;
    bestiary[speciesId] = (bestiary[speciesId] ?? const BestiaryEntry()).copyWith(seen: true);
    notifyListeners();
  }

  /// A criatura entra na coleção e no bestiário, e o spawn some do registro de vivos.
  CreatureInstance capture({required int uid, required String speciesId, required int level, required int nowUtc}) {
    final c = CreatureInstance(uid: uidKey(uid), speciesId: speciesId, level: level, capturedUtc: nowUtc);
    collection.add(c);
    bestiary[speciesId] = (bestiary[speciesId] ?? const BestiaryEntry()).copyWith(captured: true);
    markDone(uid, nowUtc);
    return c;
  }

  CreatureInstance? creature(String uid) {
    for (final c in collection) {
      if (c.uid == uid) return c;
    }
    return null;
  }

  /// Troca uma criatura da coleção por uma versão atualizada (nível, XP).
  void replaceCreature(CreatureInstance next) {
    final i = collection.indexWhere((c) => c.uid == next.uid);
    if (i >= 0) collection[i] = next;
    notifyListeners();
  }

  bool inCircle(String uid) => circle.contains(uid);

  /// Põe a criatura no Círculo, ou tira se já está. `false` se o Círculo está cheio ou ela não existe.
  bool toggleCircle(String uid) {
    if (circle.remove(uid)) {
      notifyListeners();
      return true;
    }
    if (circle.length >= 3 || creature(uid) == null) return false;
    circle.add(uid);
    notifyListeners();
    return true;
  }

  /// Tira a criatura da coleção. Criaturas do Círculo não saem.
  bool removeCreature(String uid) {
    if (inCircle(uid) || creature(uid) == null) return false;
    collection.removeWhere((c) => c.uid == uid);
    notifyListeners();
    return true;
  }

  /// As marcações que ainda valem em [nowUtc]. As vencidas saem da lista.
  List<Mark> activeMarks(int nowUtc) {
    final before = marks.length;
    marks.removeWhere((m) => !m.activeAt(nowUtc));
    if (marks.length != before) notifyListeners();
    return List.unmodifiable(marks);
  }

  Mark? markOf(int uid) {
    for (final m in marks) {
      if (m.uid == uidKey(uid)) return m;
    }
    return null;
  }

  /// Marca o sinal. `false` se já há o máximo de marcações ativas.
  bool addMark(Mark m, int nowUtc) {
    if (activeMarks(nowUtc).length >= balance.markMax) return false;
    marks.add(m);
    notifyListeners();
    return true;
  }

  bool removeMark(String uid) {
    final had = marks.any((m) => m.uid == uid);
    marks.removeWhere((m) => m.uid == uid);
    if (had) notifyListeners();
    return had;
  }

  Map<String, dynamic> toJson(int nowUtc) => {
        ..._extra,
        'schema_version': saveSchemaVersion,
        'group_code': groupCode,
        'player': progress.toJson(),
        if (levelOverride != null) 'level_override': levelOverride,
        'saved_utc': nowUtc,
        'created_utc': createdUtc ?? nowUtc,
        'last_seen_utc': lastSeenUtc,
        'app_version': appVersion,
        'epoch': epochId,
        if (founder != null) 'founder': founder!.toJson(),
        'settings': settings,
        'inventory': inventory,
        'collection': [for (final c in collection) c.toJson()],
        'collected': _collected,
        'circle': circle,
        'bestiary': {for (final e in bestiary.entries) e.key: e.value.toJson()},
        'marks': [for (final m in marks) m.toJson()],
      };
}
