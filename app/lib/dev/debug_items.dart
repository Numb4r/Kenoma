/// Os itens padrão do menu de debug, por seção. Para somar um item novo, ver o cabeçalho de `debug_registry.dart`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'debug_capture.dart';
import 'debug_env.dart';
import 'debug_items_climate.dart';
import 'debug_items_creature.dart';
import 'debug_items_patrol.dart';
import 'debug_items_position.dart';
import 'debug_items_profile.dart';
import 'debug_items_school.dart';
import 'debug_items_ritual.dart';
import 'debug_items_save.dart';
import 'debug_items_world.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';
import 'dev_tools.dart';

DebugRegistry buildDefaultRegistry(DebugEnv env) => DebugRegistry()
  ..addAll(positionItems(env))
  ..addAll(patrolItems(env))
  ..addAll(timeItems(env))
  ..addAll(climateTimeItems(env.tools))
  ..addAll(spawnItems(env))
  ..addAll(creatureItems(env))
  ..addAll(mapItems(env))
  ..addAll(trafficItems(env))
  ..addAll(playerItems(env))
  ..addAll(profileItems(env))
  ..addAll(schoolItems(env))
  ..addAll(captureItems(env.capture))
  ..addAll(signatureItems(env))
  ..addAll(performanceItems())
  ..addAll(saveItems(env))
  ..addAll(ritualDebugItems(env));

/// Tráfego simulado: contador de agentes, área e semáforos desenhados, densidade forçada.
List<DebugItem> trafficItems(DebugEnv env) {
  final tools = env.tools;
  return [
    DebugItem(
      id: 'traffic.sim',
      title: 'Simulação do tráfego',
      section: DebugSection.traffic,
      keywords: const ['carros', 'passantes', 'semáforo', 'área', 'contador', 'agentes', 'densidade'],
      builder: (_) => ListenableBuilder(
        listenable: tools,
        builder: (_, _) => DebugColumn([
          DebugSwitch(title: 'Área simulada e semáforos no mapa', subtitle: 'Círculo: o raio. Pontos: a luz de cada acesso. Quadrados: entradas (estacionamentos).', value: tools.showTraffic, onChanged: (v) => tools.setTraffic(show: v)),
          DebugWrap([
            for (final (label, d) in const [('Hora e clima', null), ('Vazio', 0.0), ('Pouco', 0.3), ('Rush', 1.0), ('Lotado', 2.5)])
              DebugChip(label, on: tools.trafficDensity == d, onTap: () => d == null ? tools.setTraffic(clearDensity: true) : tools.setTraffic(density: d)),
          ]),
          _TrafficStats(tools),
        ]),
      ),
    ),
  ];
}

class _TrafficStats extends StatefulWidget {
  const _TrafficStats(this.tools);
  final DevTools tools;

  @override
  State<_TrafficStats> createState() => _TrafficStatsState();
}

class _TrafficStatsState extends State<_TrafficStats> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DebugNote(widget.tools.trafficStats?.call() ?? 'Abra o mapa do jogo para a simulação começar.');
}
