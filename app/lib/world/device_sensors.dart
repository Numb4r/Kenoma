/// Pontes para o código nativo (`DeviceChannels.kt`): contador de passos, proximidade e a tela de backup do Android.
/// Tudo opcional: sem plugin (testes, outras plataformas), sem sensor ou sem permissão, devolve `false`/`null`/fluxo mudo.
library;

import 'package:flutter/services.dart';

class DeviceSensors {
  const DeviceSensors();

  static const _steps = MethodChannel('kenoma/steps');
  static const _proximity = EventChannel('kenoma/proximity');
  static const _system = MethodChannel('kenoma/system');

  /// Pede ACTIVITY_RECOGNITION (só quando o jogador liga o contador). `false` se negada ou indisponível.
  Future<bool> requestStepsPermission() async {
    try {
      return await _steps.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Passos acumulados desde o boot, ou `null`.
  Future<int?> readSteps() async {
    try {
      return await _steps.invokeMethod<int>('read');
    } catch (_) {
      return null;
    }
  }

  /// `true` enquanto o sensor de proximidade está coberto. Sem sensor, o fluxo nunca emite.
  Stream<bool> proximity() => _proximity.receiveBroadcastStream().where((e) => e is bool).cast<bool>().handleError((_) {});

  /// Abre a tela de ajustes do Android onde fica o backup. `false` se não conseguiu.
  Future<bool> openBackupSettings() async {
    try {
      return await _system.invokeMethod<bool>('openBackupSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
