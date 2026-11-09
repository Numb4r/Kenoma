/// O lado do app da Patrulha do Véu: liga e desliga o serviço, guarda o estado que a notificação mostra (para o HUD) e
/// incorpora o diário no save. Um só por processo ([PatrolController.instance]): há um serviço só.
///
/// Fonte da verdade com o app aberto e a Patrulha ligada: o SERVIÇO coleta e marca; o app fica calado como no Modo Viagem
/// (mostra o mundo, sem coletar) e lê o diário a cada `journal_read_s`. Assim ninguém pega o mesmo spawn duas vezes, e o que
/// o app pega por toque (material, sintonia) o diário depois ignora pelo uid.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import '../player/game_state.dart';
import '../world/device_sensors.dart';
import 'patrol_engine.dart';
import 'patrol_journal.dart';
import 'patrol_service.dart';

/// Em `settings`: horas até a Patrulha desligar sozinha (2 a 4) e se a tela de primeira vez já foi vista.
const kPatrolMaxHoursKey = 'patrol_max_h';
const kPatrolIntroSeenKey = 'patrol_intro_seen';

/// O arquivo do diário nos documentos do app.
Future<File> patrolJournalFile() async => File('${(await getApplicationDocumentsDirectory()).path}/$kJournalFile');

class PatrolController extends ChangeNotifier {
  PatrolController._();

  static final instance = PatrolController._();

  bool _running = false;
  bool _wired = false;

  /// O serviço está ligado (conferido em [refresh]).
  bool get running => _running;

  /// O que a notificação mostra agora (vem do serviço).
  Map<String, Object?> status = const {};

  void _wire() {
    if (_wired) return;
    _wired = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is! Map) return;
    status = {for (final e in data.entries) '${e.key}': e.value};
    _running = true;
    notifyListeners();
  }

  /// Confere se o serviço está ligado. Sem o plugin (testes), desligado.
  Future<bool> refresh() async {
    bool on;
    try {
      _wire();
      on = await FlutterForegroundTask.isRunningService;
    } catch (_) {
      on = false;
    }
    if (on != _running) {
      _running = on;
      if (!on) status = const {};
      notifyListeners();
    }
    return on;
  }

  /// Liga a Patrulha (o app precisa estar à vista). Devolve o erro em português, ou `null`.
  Future<String?> start({required int tickS, required int maxDurationS, int clockOffsetS = 0, PatrolSim? sim}) async {
    try {
      _wire();
      if (await FlutterForegroundTask.isRunningService) return null;
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'kenoma_patrol',
          channelName: 'Patrulha do Véu',
          channelDescription: 'Aparece enquanto a Patrulha está ligada',
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(tickS * 1000),
          allowWakeLock: true,
          allowAutoRestart: false, // morreu, acabou: o app fecha a Patrulha ao abrir
          stopWithTask: false, // fechar o app não encerra
        ),
      );
      await FlutterForegroundTask.saveData(
        key: kPatrolConfigKey,
        value: jsonEncode(PatrolConfig(maxDurationS: maxDurationS, clockOffsetS: clockOffsetS, sim: sim).toJson()),
      );
      final r = await FlutterForegroundTask.startService(
        serviceId: 4712,
        serviceTypes: const [ForegroundServiceTypes.location],
        notificationTitle: 'Patrulha do Véu',
        notificationText: 'Começando...',
        notificationButtons: patrolButtons(asking: false),
        callback: patrolTaskMain,
      );
      if (r is ServiceRequestFailure) return 'Não consegui ligar a Patrulha: ${r.error}';
      _running = true;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Não consegui ligar a Patrulha: $e';
    }
  }

  /// Pede ao serviço para encerrar (ele escreve o fim no diário). Se ele não responde em alguns segundos, para à força.
  Future<void> stop([PatrolStop why = PatrolStop.user]) async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      FlutterForegroundTask.sendDataToTask({'cmd': 'stop', 'why': why.name});
      for (var i = 0; i < 20 && await FlutterForegroundTask.isRunningService; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (_) {
      // sem o plugin: nada a parar
    } finally {
      await refresh();
    }
  }

  Future<void> _incorporating = Future.value();

  /// Incorpora o diário no [state], uma vez de cada vez. [onCell] recebe as células z17 visitadas.
  Future<JournalResult> incorporate(GameState state, {required int nowUtc, void Function(int x17, int y17, int tUtc)? onCell}) {
    final next = _incorporating.then((_) async {
      final running = await refresh();
      return incorporateJournal(
        state,
        await patrolJournalFile(),
        running: running,
        nowUtc: nowUtc,
        steps: running ? null : await const DeviceSensors().readSteps(),
        onCell: onCell,
      );
    });
    _incorporating = next.then((_) {}, onError: (_) {});
    return next;
  }
}

/// Encerra a Patrulha e apaga o diário. Para o recomeço do zero (o progresso sai, o diário não pode voltar a entrar).
Future<void> stopPatrol({bool deleteJournal = true}) async {
  await PatrolController.instance.stop(PatrolStop.user);
  if (!deleteJournal) return;
  try {
    final f = await patrolJournalFile();
    if (await f.exists()) await f.delete();
  } catch (_) {
    // sem pasta de documentos
  }
}
