/// Quando avisar o jogador (notificações locais opcionais): as diárias do fórum renovadas e o descanso acumulado
/// cheio. Só planeja instantes; quem agenda no sistema é `local_notifier.dart`. Dart puro.
library;

import '../player/progress_balance.dart';
import '../player/progression.dart';

/// Ids fixos: reagendar substitui o aviso anterior.
const int notifyDailyId = 1;
const int notifyRestId = 2;

/// Hora local do aviso: de manhã, para não acordar ninguém.
const int notifyHour = 9;

class PlannedNotification {
  const PlannedNotification({required this.id, required this.title, required this.body, required this.atUtc});

  final int id;
  final String title;
  final String body;

  /// Instante do aviso, em segundos UTC.
  final int atUtc;

  @override
  String toString() => 'PlannedNotification($id, $atUtc, $title)';
}

/// Segundos UTC de [hour] h do dia local [day] (número de dias, como em [localDay]). [offset] só existe para
/// testar sem depender do fuso da máquina: com ele o dia local é UTC + offset.
int localInstant(int day, int hour, {Duration? offset}) {
  final midnightUtcOfDay = day * 86400; // o dia local como se fosse UTC
  if (offset != null) return midnightUtcOfDay + hour * 3600 - offset.inSeconds;
  final d = DateTime.fromMillisecondsSinceEpoch(midnightUtcOfDay * 1000, isUtc: true);
  return DateTime(d.year, d.month, d.day, hour).millisecondsSinceEpoch ~/ 1000;
}

/// O saldo de descanso de hoje: o guardado mais os dias que passaram desde a última atualização, até o teto.
int restToday(PlayerProgress p, int today) {
  final last = p.restDay;
  if (last == null || today <= last) return p.restBalance;
  final grown = p.restBalance + p.balance.restDailyDoubled * (today - last);
  return grown > p.balance.restMaxBanked ? p.balance.restMaxBanked : grown;
}

/// Os avisos de [nowUtc] em diante, se as notificações estão ligadas:
/// - **diárias renovadas**: às 9 h do próximo dia local, quando os três pedidos do fórum mudam;
/// - **descanso cheio**: às 9 h do dia local em que o saldo de descanso (350 por dia, até 1050) enche, se ainda não
///   está cheio.
List<PlannedNotification> planNotifications({
  required bool enabled,
  required int nowUtc,
  required PlayerProgress progress,
  required ProgressBalance balance,
  Duration? offset,
}) {
  if (!enabled) return const [];
  final today = localDay(nowUtc, offset: offset);
  final out = <PlannedNotification>[
    PlannedNotification(
      id: notifyDailyId,
      title: 'Limen',
      body: 'Três pedidos novos no fórum. Um deles dá para fazer em casa.',
      atUtc: localInstant(today + 1, notifyHour, offset: offset),
    ),
  ];
  final rest = restToday(progress, today);
  if (rest < balance.restMaxBanked) {
    final days = ((balance.restMaxBanked - rest) / balance.restDailyDoubled).ceil();
    out.add(PlannedNotification(
      id: notifyRestId,
      title: 'Descanso cheio',
      body: '${balance.restMaxBanked} de XP em dobro esperando. Quanto mais parado, mais o Véu guarda.',
      atUtc: localInstant(today + days, notifyHour, offset: offset),
    ));
  }
  return [for (final n in out) if (n.atUtc > nowUtc) n];
}
