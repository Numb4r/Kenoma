/// Pontes para o código nativo (`DeviceChannels.kt` e `PatrolChannels.kt`): contador de passos, bateria, proximidade e a tela
/// de backup do Android. Tudo opcional: sem plugin (testes, outras plataformas), sem sensor ou sem permissão, devolve
/// `false`/`null`/fluxo mudo. Passos e bateria também respondem no motor do serviço da Patrulha.
library;

import 'package:flutter/services.dart';

import 'steps.dart' show StepReading;

class DeviceSensors {
  const DeviceSensors();

  static const _steps = MethodChannel('kenoma/steps');
  static const _proximity = EventChannel('kenoma/proximity');
  static const _system = MethodChannel('kenoma/system');
  static const _battery = MethodChannel('kenoma/battery');

  /// Passos de mentira do menu de debug, somados a cada leitura (só na memória deste processo). Sem sensor, a leitura vira
  /// só eles, num boot fixo.
  static int debugExtraSteps = 0;

  /// Pede ACTIVITY_RECOGNITION (só quando o jogador liga o contador). `false` se negada ou indisponível.
  Future<bool> requestStepsPermission() async {
    try {
      return await _steps.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Passos acumulados desde o boot e a hora do boot, ou `null`.
  Future<StepReading?> readSteps() async {
    Map<Object?, Object?>? m;
    try {
      m = await _steps.invokeMethod<Map<Object?, Object?>>('read');
    } catch (_) {
      m = null;
    }
    final steps = m?['steps'], boot = m?['boot_ms'];
    if (steps is int) return StepReading(steps + debugExtraSteps, boot is int ? boot ~/ 1000 : null);
    return debugExtraSteps > 0 ? StepReading(debugExtraSteps, 0) : null;
  }

  /// A carga da bateria em %, ou `null`.
  Future<int?> batteryPct() async {
    try {
      return await _battery.invokeMethod<int>('read');
    } catch (_) {
      return null;
    }
  }

  /// `true` enquanto o sensor de proximidade está coberto. Sem sensor, o fluxo nunca emite.
  Stream<bool> proximity() => _proximity.receiveBroadcastStream().where((e) => e is bool).cast<bool>().handleError((_) {});

  /// Avisa o Android que os dados mudaram (`BackupManager.dataChanged`): o próximo Auto Backup leva o save novo. Depois do
  /// recomeço, é o que impede uma reinstalação de trazer o jogo antigo de volta. Sem plugin, não faz nada.
  Future<void> requestBackup() async {
    try {
      await _system.invokeMethod<bool>('requestBackup');
    } catch (_) {
      // sem canal (testes, outras plataformas): nada a pedir
    }
  }

  /// Abre a tela de ajustes do Android onde fica o backup. `false` se não conseguiu.
  Future<bool> openBackupSettings() async {
    try {
      return await _system.invokeMethod<bool>('openBackupSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
