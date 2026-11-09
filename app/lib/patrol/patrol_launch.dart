/// O toque no aviso de Eco raro da Patrulha: abre o app direto no Eco. O payload é `patrol_eco:<uid>`; o mapa do jogo ouve
/// [patrolFocusUid] e abre o encontro do Eco marcado (depois de incorporar o diário).
library;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'patrol_service.dart' show kPatrolEcoPayload;

/// O Eco que o jogador pediu para abrir, ou `null`. Quem abre põe de volta em `null`.
final patrolFocusUid = ValueNotifier<int?>(null);

/// O callback de toque de TODA notificação local do app (o `LocalNotifier` também o usa: só há um por isolate).
void onNotificationResponse(NotificationResponse r) {
  final p = r.payload;
  if (p != null && p.startsWith(kPatrolEcoPayload)) patrolFocusUid.value = int.tryParse(p.substring(kPatrolEcoPayload.length));
}

/// Liga o toque e, se o app abriu por um aviso, já põe o Eco em [patrolFocusUid]. `true` se abriu por um aviso da Patrulha.
Future<bool> initPatrolLaunch() async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: onNotificationResponse,
    );
    final d = await plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d?.didNotificationLaunchApp == true && r != null) onNotificationResponse(r);
    return patrolFocusUid.value != null;
  } catch (_) {
    return false; // sem o plugin (testes)
  }
}
