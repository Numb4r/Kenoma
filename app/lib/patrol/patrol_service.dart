/// O serviço da Patrulha do Véu: o isolate que o `flutter_foreground_task` cria no serviço em primeiro plano (tipo
/// localização). Só liga o [PatrolEngine] ao Android: GPS em precisão equilibrada, bateria e contador de passos pelo canal
/// (`PatrolChannels.kt`), vibração, notificação fixa com botões e o aviso de Eco raro. Escreve só o diário.
///
/// Por que `flutter_foreground_task`: ele já traz o serviço, o motor Flutter separado, a notificação com botões e a
/// conversa com o app; um serviço próprio em Kotlin repetiria tudo isso.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';

import '../data/geolocator_source.dart';
import '../dev/gps_simulator.dart';
import '../world/device_sensors.dart';
import '../world/geo_fix.dart';
import '../world/position_source.dart';
import '../world/steps.dart' show StepReading;
import 'patrol_engine.dart';
import 'patrol_journal.dart';
import 'patrol_world.dart';

/// Em `FlutterForegroundTask.saveData`: a configuração que o app deixa antes de ligar o serviço.
const kPatrolConfigKey = 'patrol_config';

/// O canal do aviso de Eco raro e o prefixo do payload que o app lê ao abrir (`patrol_launch.dart`).
const kPatrolRareChannel = 'kenoma_patrol_rare';
const kPatrolEcoPayload = 'patrol_eco:';

/// O que o app passa ao serviço.
class PatrolConfig {
  const PatrolConfig({required this.maxDurationS, this.clockOffsetS = 0, this.sim});

  factory PatrolConfig.fromJson(Map<String, dynamic> j) => PatrolConfig(
        maxDurationS: j['max_s'] as int,
        clockOffsetS: (j['clock_offset_s'] as int?) ?? 0,
        sim: j['sim'] == null ? null : PatrolSim.fromJson(j['sim'] as Map<String, dynamic>),
      );

  final int maxDurationS;

  /// O relógio do debug: o serviço soma isto ao relógio real.
  final int clockOffsetS;

  /// Debug: anda sozinho em linha reta no lugar do GPS (funciona com a tela bloqueada).
  final PatrolSim? sim;

  Map<String, dynamic> toJson() => {'max_s': maxDurationS, 'clock_offset_s': clockOffsetS, if (sim != null) 'sim': sim!.toJson()};
}

class PatrolSim {
  const PatrolSim({required this.lat, required this.lon, required this.mps, required this.dx, required this.dy, this.rewards = false});

  factory PatrolSim.fromJson(Map<String, dynamic> j) =>
      PatrolSim(lat: _d(j['lat']), lon: _d(j['lon']), mps: _d(j['mps']), dx: _d(j['dx']), dy: _d(j['dy']), rewards: (j['rewards'] as bool?) ?? false);

  static double _d(Object? v) => (v as num).toDouble();

  final double lat, lon, mps;

  /// Direção do joystick: [dx] para leste, [dy] para norte.
  final double dx, dy;

  /// "GPS simulado dá recompensa" do debug. Desligado, o diário desta Patrulha não conta para XP nem estatísticas.
  final bool rewards;

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'mps': mps, 'dx': dx, 'dy': dy, 'rewards': rewards};
}

@pragma('vm:entry-point')
void patrolTaskMain() {
  WidgetsFlutterBinding.ensureInitialized(); // assets e canais neste motor
  DartPluginRegistrant.ensureInitialized(); // path_provider e geolocator no isolate do serviço
  FlutterForegroundTask.setTaskHandler(PatrolTaskHandler());
}

/// Os botões da notificação fixa.
List<NotificationButton> patrolButtons({required bool asking}) => asking
    ? const [NotificationButton(id: 'passenger', text: 'Sou passageiro'), NotificationButton(id: 'driver', text: 'Estou dirigindo'), NotificationButton(id: 'stop', text: 'Encerrar')]
    : const [NotificationButton(id: 'open', text: 'Abrir'), NotificationButton(id: 'stop', text: 'Encerrar')];

class PatrolTaskHandler extends TaskHandler {
  static const _sensors = DeviceSensors();
  PatrolWorld? _world;
  PatrolEngine? _engine;
  JournalWriter? _journal;
  PositionSource? _source;
  StreamSubscription<GeoFix>? _sub;
  final _notes = FlutterLocalNotificationsPlugin();
  int _offset = 0;
  bool _asking = false;
  bool _stopping = false;

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + _offset;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final raw = await FlutterForegroundTask.getData<String>(key: kPatrolConfigKey);
      final config = PatrolConfig.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
      _offset = config.clockOffsetS;
      final world = await openPatrolWorld(nowUtc: _now, realNowUtc: () => DateTime.now().millisecondsSinceEpoch ~/ 1000);
      if (world == null) return await _quit();
      _world = world;
      final b = world.balance;
      final docs = await getApplicationDocumentsDirectory();
      _journal = JournalWriter(File('${docs.path}/$kJournalFile'));
      final engine = _engine = PatrolEngine(
        world: world.world,
        state: world.state,
        balance: b,
        startUtc: _now(),
        maxDurationS: config.maxDurationS,
        streetAt: world.streetAt,
        recordCells: config.sim == null,
      );
      _write([engine.startLine(extra: {..._steps(await _sensors.readSteps()), if (config.sim != null) 'sim': true, if (config.sim != null && !config.sim!.rewards) 'sandbox': true})]);
      await _notes.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      final sim = config.sim;
      final source = _source = sim == null
          ? GeolocatorPositionSource(accuracy: LocationAccuracy.medium, distanceFilterM: b.gpsDistanceM, interval: Duration(seconds: b.gpsIntervalS))
          : (SimulatedPositionSource(lat: sim.lat, lon: sim.lon, startTimeMs: DateTime.now().millisecondsSinceEpoch, fixInterval: Duration(seconds: b.gpsIntervalS))
            ..speedMps = sim.mps
            ..setJoystick(sim.dx, sim.dy));
      _sub = source.fixes.listen(_onFix);
      await source.start();
      _notify();
    } catch (_) {
      await _quit(); // sem save, sem assets ou sem permissão: não há Patrulha
    }
  }

  Map<String, Object?> _steps(StepReading? r) => r == null ? const {} : {'steps': r.steps, 'boot': r.bootUtc};

  void _onFix(GeoFix f) {
    final engine = _engine;
    if (engine == null) return;
    unawaited(_world?.layers.fallback?.tick(f.lat, f.lon)); // só lê blocos do disco: a rede está desligada
    _handle(engine.fix(f, _now()));
  }

  void _write(List<Map<String, Object?>> lines) {
    for (final l in lines) {
      try {
        _journal?.write(l);
      } catch (_) {
        // disco cheio: a linha se perde, a Patrulha segue
      }
    }
  }

  void _handle(PatrolOutput out) {
    _write(out.lines);
    for (final p in out.vibrations) {
      unawaited(Vibration.vibrate(pattern: p).catchError((_) {}));
    }
    for (final r in out.rare) {
      unawaited(_notes
          .show(
            id: r.uid & 0x7fffffff,
            title: 'Patrulha do Véu',
            body: r.text,
            payload: '$kPatrolEcoPayload${r.uid}',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(kPatrolRareChannel, 'Ecos raros na Patrulha',
                  channelDescription: 'Brilhante, variante ou Espírito passou perto', importance: Importance.high, priority: Priority.high, enableVibration: false),
            ),
          )
          .catchError((_) {}));
    }
    if (out.lines.isNotEmpty || out.ask) _notify();
    if (out.stop != null) unawaited(_quit());
  }

  void _notify() {
    final engine = _engine;
    if (engine == null) return;
    final s = engine.status(_now());
    final changed = s.asking != _asking;
    _asking = s.asking;
    unawaited(FlutterForegroundTask.updateService(
      notificationTitle: 'Patrulha do Véu',
      notificationText: patrolNotificationText(s),
      notificationButtons: changed || s.asking ? patrolButtons(asking: s.asking) : null,
    ));
    FlutterForegroundTask.sendDataToMain({'sparks': s.sparks, 'materials': s.materials, 'marks': s.marks, 'min': s.minutes, 'asking': s.asking});
  }

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_check());

  Future<void> _check() async {
    final engine = _engine;
    if (engine == null) return;
    _handle(engine.tick(_now()));
    final pct = await _sensors.batteryPct();
    if (pct != null) _handle(engine.battery(pct, _now()));
    _notify();
  }

  Future<void> _stopWith(PatrolStop why) async {
    final engine = _engine;
    if (engine == null || engine.ended || _stopping) return _quit();
    _stopping = true;
    _handle(engine.stop(why, _now(), extra: _steps(await _sensors.readSteps())));
  }

  Future<void> _quit() async {
    await _sub?.cancel();
    _sub = null;
    await _source?.stop();
    await FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationButtonPressed(String id) {
    switch (id) {
      case 'open':
        FlutterForegroundTask.launchApp();
      case 'stop':
        unawaited(_stopWith(PatrolStop.user));
      case 'passenger' || 'driver':
        _engine?.answer(passenger: id == 'passenger');
        _notify();
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['cmd'] == 'stop') unawaited(_stopWith(PatrolStop.values.asNameMap()[data['why']] ?? PatrolStop.user));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    final engine = _engine;
    if (engine != null && !engine.ended) _write(engine.stop(PatrolStop.system, _now()).lines); // o sistema parou o serviço
    await _sub?.cancel();
    await _source?.stop();
    _world?.dispose();
  }
}
