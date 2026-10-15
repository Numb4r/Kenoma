/// As notificações locais no sistema (Android): pede a permissão e agenda os avisos de `notification_plan.dart`.
/// Os instantes são absolutos (UTC), então não precisa saber o fuso do aparelho.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_plan.dart';

abstract class Notifier {
  /// Pede a permissão de notificar (Android 13+). `true` se o jogador deixou.
  Future<bool> requestPermission();

  /// Cancela os avisos antigos e agenda [plan].
  Future<void> apply(List<PlannedNotification> plan);
}

class LocalNotifier implements Notifier {
  LocalNotifier() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'kenoma_daily',
    'Avisos do Kenoma',
    channelDescription: 'Pedidos novos do fórum e descanso acumulado',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return (await android?.requestNotificationsPermission()) ?? false;
  }

  @override
  Future<void> apply(List<PlannedNotification> plan) async {
    await _init();
    await _plugin.cancelAll();
    for (final n in plan) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, n.atUtc * 1000),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // sem alarme exato: dispensa a permissão extra
      );
    }
  }
}
