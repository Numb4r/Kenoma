/// Itens da seção Posição para a Patrulha do Véu e os passos: Patrulha com o GPS simulado (anda sozinha em linha reta, então
/// funciona com a tela bloqueada), forçar o fim, ver e limpar o `patrulha.jsonl` e injetar passos.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/game_data.dart';
import '../patrol/patrol_controller.dart';
import '../patrol/patrol_engine.dart' show PatrolStop;
import '../patrol/patrol_service.dart' show PatrolSim;
import '../ui/tema.dart';
import '../world/device_sensors.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

List<DebugItem> patrolItems(DebugEnv env) => [
      DebugItem(
        id: 'pos.patrol_sim',
        title: 'Patrulha simulada',
        section: DebugSection.position,
        keywords: const ['patrulha', 'serviço', 'segundo plano', 'bloqueada', 'simulador', 'fim'],
        builder: (_) => _PatrolSim(env: env),
      ),
      DebugItem(
        id: 'pos.patrol_journal',
        title: 'Diário da Patrulha',
        section: DebugSection.position,
        keywords: const ['patrulha', 'patrulha.jsonl', 'diário', 'limpar'],
        builder: (_) => const _Journal(),
      ),
      DebugItem(
        id: 'pos.steps_inject',
        title: 'Injetar passos',
        section: DebugSection.position,
        keywords: const ['passos', 'contador', 'pedômetro', 'fagulha'],
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => DebugColumn([
            DebugNote('Somados à leitura do contador (só até fechar o app): ${DeviceSensors.debugExtraSteps}. Com o contador ligado nos '
                'Ajustes, o mapa converte na próxima leitura (a cada 30 s).'),
            DebugWrap([
              for (final n in const [500, 1000, 5000])
                DebugButton(label: '+$n', onTap: () => setState(() => DeviceSensors.debugExtraSteps += n)),
              DebugButton(label: 'Zerar', color: KCores.textoMudo, onTap: () => setState(() => DeviceSensors.debugExtraSteps = 0)),
            ]),
          ]),
        ),
      ),
    ];

class _PatrolSim extends StatefulWidget {
  const _PatrolSim({required this.env});

  final DebugEnv env;

  @override
  State<_PatrolSim> createState() => _PatrolSimState();
}

class _PatrolSimState extends State<_PatrolSim> {
  (double, double) _dir = (0, 1);

  @override
  void initState() {
    super.initState();
    unawaited(PatrolController.instance.refresh());
  }

  Future<void> _start() async {
    final say = debugSayer(context);
    try {
      await FlutterForegroundTask.requestNotificationPermission();
    } catch (_) {}
    final data = await GameData.load();
    final tools = widget.env.tools;
    final sim = tools.simulator;
    final err = await PatrolController.instance.start(
      tickS: data.patrol.tickS,
      maxDurationS: data.patrol.maxHoursDefault * 3600,
      clockOffsetS: tools.clock.nowUtc - tools.clock.realNowUtc,
      sim: PatrolSim(lat: sim.lat, lon: sim.lon, mps: sim.speedMps, dx: _dir.$1, dy: _dir.$2),
    );
    say(err ?? 'Patrulha simulada ligada: pode bloquear a tela');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PatrolController.instance,
        builder: (context, _) {
          final c = PatrolController.instance;
          return DebugColumn([
            DebugNote(c.running
                ? 'Ligada: ${jsonEncode(c.status)}'
                : 'Anda sozinha da posição do simulador, na velocidade dele, na direção abaixo. Sem GPS: dá para bloquear a tela.'),
            DebugWrap([
              for (final (label, d) in const [('Norte', (0.0, 1.0)), ('Leste', (1.0, 0.0)), ('Sul', (0.0, -1.0)), ('Oeste', (-1.0, 0.0))])
                DebugChip(label, on: _dir == d, onTap: () => setState(() => _dir = d)),
            ]),
            DebugWrap([
              DebugButton(label: 'Começar', color: KCores.sinalCiano, enabled: !c.running, onTap: _start),
              DebugButton(label: 'Forçar o fim', color: KCores.brasaLaranja, enabled: c.running, onTap: () => c.stop(PatrolStop.debug)),
            ]),
          ]);
        },
      );
}

class _Journal extends StatelessWidget {
  const _Journal();

  Future<void> _show(BuildContext context) async {
    final f = await patrolJournalFile();
    final text = await f.exists() ? await f.readAsString() : '';
    final lines = text.split('\n').where((l) => l.isNotEmpty).toList();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('patrulha.jsonl · ${lines.length} linhas · ${text.length} bytes', style: KTexto.rotulo),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(lines.isEmpty ? '(vazio)' : lines.reversed.take(60).join('\n'), style: KTexto.rotulo)),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar'))],
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final say = debugSayer(context);
    if (await PatrolController.instance.refresh()) return say('Encerre a Patrulha antes: o serviço ainda escreve no diário');
    final f = await patrolJournalFile();
    if (await f.exists()) await f.delete();
    say('Diário apagado');
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        const DebugNote('O que o serviço gravou e o app ainda não incorporou (as últimas linhas primeiro). O app incorpora ao abrir o mapa.'),
        DebugWrap([
          DebugButton(label: 'Ver', onTap: () => _show(context)),
          DebugButton(label: 'Limpar', color: KCores.brasaLaranja, onTap: () => _clear(context)),
        ]),
      ]);
}
