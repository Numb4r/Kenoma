/// Pontes para o Android do Modo Viagem (`DeviceChannels.kt` e `RideNotificationListener.kt`): saber se um app está instalado,
/// abri-lo, e as notificações de corrida. Sem plugin (testes) devolve `false` ou um fluxo mudo.
library;

import 'package:flutter/services.dart';

import 'ride.dart' show RideNotice;

class SystemBridge {
  const SystemBridge();

  static const _system = MethodChannel('kenoma/system');
  static const _rides = EventChannel('kenoma/ride_notifications');

  Future<bool> _call(String method, [Object? args]) async {
    try {
      return await _system.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isInstalled(String package) => _call('isInstalled', package);

  Future<bool> launchPackage(String package) => _call('launchPackage', package);

  Future<bool> openUrl(String url) => _call('openUrl', url);

  /// A rede de agora é Wi-Fi e sem cobrança: o fallback pré-carrega os blocos à frente. `false` nos dados móveis ou sem plugin.
  Future<bool> unmeteredWifi() => _call('unmeteredWifi');

  /// Se o Android já deu ao Kenoma o acesso às notificações.
  Future<bool> notificationAccess() => _call('notificationAccess');

  /// Abre `ACTION_NOTIFICATION_LISTENER_SETTINGS`.
  Future<bool> openNotificationSettings() => _call('openNotificationSettings');

  /// O interruptor dos Ajustes: desligado, o serviço não repassa nada.
  Future<void> setRideRelay(bool on) => _call('setRideRelay', on);

  /// As notificações do Uber e da 99 que já estão na barra (`getActiveNotifications`). Vazio sem permissão ou sem plugin.
  /// Quem chama confere antes o interruptor dos Ajustes. Nada é guardado.
  Future<List<RideNotice>> activeRides() async {
    try {
      final list = await _system.invokeMethod<List<Object?>>('activeRides') ?? const [];
      return [
        for (final e in list)
          if (e is Map) (package: '${e['package']}', title: '${e['title']}', text: '${e['text']}', postMs: (e['postMs'] as num?)?.toInt() ?? 0),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Título e texto das notificações do Uber e da 99, só enquanto alguém ouve. Nada é guardado.
  Stream<({String package, String title, String text})> rideNotifications() => _rides.receiveBroadcastStream().where((e) => e is Map).map((e) {
        final m = e as Map;
        return (package: '${m['package']}', title: '${m['title']}', text: '${m['text']}');
      }).handleError((_) {});
}
