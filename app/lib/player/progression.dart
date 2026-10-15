/// Nível e XP do Conjurador (docs/fase0-spec.md, seção 8): a curva, o teto e o bônus de descanso. Dart puro.
library;

import 'dart:math' as math;

import 'progress_balance.dart';

/// XP para ir do nível [n] ao `n + 1`: `a × n^expoente`, arredondado para dezenas.
int xpToNext(int n, ProgressBalance b) => (b.curveA * math.pow(n, b.curveExponent) / b.curveRoundTo).round() * b.curveRoundTo;

/// O dia local do aparelho como número de dias, para o descanso. O dia local não afeta o mundo.
/// [offset] só existe para testar sem depender do fuso da máquina.
int localDay(int utcSeconds, {Duration? offset}) {
  final t = DateTime.fromMillisecondsSinceEpoch(utcSeconds * 1000, isUtc: true);
  final local = offset != null ? t.add(offset) : t.toLocal();
  return DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ 86400000;
}

class PlayerProgress {
  PlayerProgress({this.level = 1, this.xp = 0, this.bankedXp = 0, int? restBalance, this.restDay, required this.balance})
      : restBalance = restBalance ?? balance.restDailyDoubled;

  final ProgressBalance balance;

  /// Nível real, de 1 ao teto.
  int level;

  /// XP dentro do nível, rumo ao próximo.
  int xp;

  /// XP guardado além do teto, para quando o teto subir.
  int bankedXp;

  /// Quanto XP bruto ainda rende o dobro.
  int restBalance;

  /// Último dia local em que o saldo de descanso foi atualizado.
  int? restDay;

  bool get atCap => level >= balance.playerLevelCap;
  int get toNext => atCap ? 0 : xpToNext(level, balance);

  /// De 0 a 1: o quanto falta para o próximo nível (1 no teto).
  double get fraction => atCap ? 1 : xp / toNext;

  /// Soma o descanso dos dias que passaram desde a última vez. Relógio que volta não tira nada.
  void refreshRest(int nowUtc, {Duration? offset}) {
    final today = localDay(nowUtc, offset: offset);
    final last = restDay;
    if (last == null) {
      restDay = today;
    } else if (today > last) {
      restBalance = math.min(balance.restMaxBanked, restBalance + balance.restDailyDoubled * (today - last));
      restDay = today;
    }
  }

  /// Ganha [raw] de XP bruto em [nowUtc]. O descanso dobra até o saldo. Devolve quantos níveis subiu.
  int gain(int raw, int nowUtc, {Duration? offset}) {
    if (raw <= 0) return 0;
    refreshRest(nowUtc, offset: offset);
    final bonus = math.min(raw, restBalance);
    restBalance -= bonus;
    return _add(raw + bonus);
  }

  /// Aplica o XP guardado se o teto subiu desde a última vez.
  int settleBanked() {
    if (bankedXp == 0 || atCap) return 0;
    final banked = bankedXp;
    bankedXp = 0;
    return _add(banked);
  }

  int _add(int total) {
    var gained = 0;
    xp += total;
    while (!atCap && xp >= toNext) {
      xp -= toNext;
      level++;
      gained++;
    }
    if (atCap) {
      bankedXp += xp;
      xp = 0;
    }
    return gained;
  }

  Map<String, dynamic> toJson() =>
      {'level': level, 'xp': xp, 'banked_xp': bankedXp, 'rest_balance': restBalance, 'rest_day': restDay};

  factory PlayerProgress.fromJson(Map<String, dynamic>? j, ProgressBalance balance) => PlayerProgress(
        level: ((j?['level'] as int?) ?? 1).clamp(1, balance.playerLevelCap),
        xp: (j?['xp'] as int?) ?? 0,
        bankedXp: (j?['banked_xp'] as int?) ?? 0,
        restBalance: j?['rest_balance'] as int?,
        restDay: j?['rest_day'] as int?,
        balance: balance,
      );
}

/// XP do Conjurador por uma sintonia concluída: `base + por_nível × nível do Eco`, com teto.
int tuningXp(int ecoLevel, ProgressBalance b) => math.min(b.tuningMax, b.tuningBase + b.tuningPerEcoLevel * ecoLevel);
