/// Aba Posição, a Patrulha do Véu: a Patrulha com o GPS simulado (anda sozinha em linha reta, então funciona com a tela
/// bloqueada), forçar o fim e o diário `patrulha.jsonl` (ver e limpar).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/game_data.dart';
import '../patrol/patrol_controller.dart';
import '../patrol/patrol_engine.dart' show PatrolStop;
import '../patrol/patrol_service.dart' show PatrolSim;
import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';

const _dirs = {'norte': (0.0, 1.0), 'leste': (1.0, 0.0), 'sul': (0.0, -1.0), 'oeste': (-1.0, 0.0)};

/// O diário lido da última vez (o `cmd` e a tela leem daqui; [_readJournal] atualiza).
String _journal = '';

Future<void> _readJournal() async {
  final f = await patrolJournalFile();
  _journal = await f.exists() ? await f.readAsString() : '';
}

List<String> get _lines => _journal.split('\n').where((l) => l.isNotEmpty).toList();

List<DebugEntry> patrolEntries(DebugEnv env) {
  final c = PatrolController.instance;
  return [
    DebugEntry(
      id: 'pos.patrol_sim',
      name: 'Patrulha simulada',
      tab: DebugTab.position,
      kind: DebugKind.action,
      keywords: const ['patrulha', 'serviço', 'segundo plano', 'bloqueada', 'simulador'],
      info: 'Anda sozinha da posição do simulador, na velocidade dele, na direção escolhida. Sem GPS: dá para bloquear a tela.',
      params: [DebugParam('dir', 'direção', options: [for (final d in _dirs.keys) DebugOption(d, d[0].toUpperCase() + d.substring(1))], fallback: 'norte')],
      enabled: () => !c.running,
      load: c.refresh,
      autoLoad: true,
      status: () => c.running ? 'Ligada: ${jsonEncode(c.status)}' : 'Parada.',
      run: (call) async {
        try {
          await FlutterForegroundTask.requestNotificationPermission();
        } catch (_) {}
        final data = await GameData.load();
        final tools = env.tools, sim = tools.simulator, d = _dirs[call['dir']]!;
        final err = await c.start(
          tickS: data.patrol.tickS,
          maxDurationS: data.patrol.maxHoursDefault * 3600,
          clockOffsetS: tools.clock.nowUtc - tools.clock.realNowUtc,
          sim: PatrolSim(lat: sim.lat, lon: sim.lon, mps: sim.speedMps, dx: d.$1, dy: d.$2, rewards: tools.simRewards),
        );
        if (err != null) throw DebugError(err);
        return 'Patrulha simulada ligada: pode bloquear a tela';
      },
      offReal: () => c.running ? 'patrulha ligada' : null,
      toReal: () => c.stop(PatrolStop.debug),
    ),
    DebugEntry(
      id: 'pos.patrol_stop',
      name: 'Forçar o fim da Patrulha',
      tab: DebugTab.position,
      kind: DebugKind.action,
      keywords: const ['patrulha', 'fim', 'parar'],
      enabled: () => c.running,
      run: (_) async {
        await c.stop(PatrolStop.debug);
        return 'Patrulha encerrada';
      },
    ),
    DebugEntry(
      id: 'pos.patrol_journal',
      name: 'Diário da Patrulha',
      tab: DebugTab.position,
      kind: DebugKind.view,
      keywords: const ['patrulha', 'patrulha.jsonl', 'diário'],
      info: 'O que o serviço gravou e o app ainda não incorporou (o app incorpora ao abrir o mapa). As últimas linhas primeiro.',
      load: _readJournal,
      read: () => 'patrulha.jsonl: ${_lines.length} linhas, ${_journal.length} bytes',
      extra: (_) => _JournalLines(),
    ),
    DebugEntry(
      id: 'pos.patrol_journal_clear',
      name: 'Limpar o diário da Patrulha',
      tab: DebugTab.position,
      kind: DebugKind.action,
      destructive: true,
      keywords: const ['patrulha', 'diário', 'limpar', 'apagar'],
      info: 'Apaga o que o serviço gravou e o app ainda não incorporou.',
      run: (_) async {
        if (await c.refresh()) throw const DebugError('Encerre a Patrulha antes: o serviço ainda escreve no diário');
        final f = await patrolJournalFile();
        if (await f.exists()) await f.delete();
        _journal = '';
        return 'Diário apagado';
      },
    ),
  ];
}

/// As últimas linhas do diário, recolhidas até tocar (só leitura).
class _JournalLines extends StatefulWidget {
  @override
  State<_JournalLines> createState() => _JournalLinesState();
}

class _JournalLinesState extends State<_JournalLines> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (!_open) await _readJournal();
            if (mounted) setState(() => _open = !_open);
          },
          child: SizedBox(
            height: kToqueMinDp,
            child: Row(children: [
              Icon(_open ? Icons.expand_less : Icons.expand_more, color: KCores.textoMudo),
              Text(_open ? 'ESCONDER AS LINHAS' : 'VER AS ÚLTIMAS LINHAS', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
            ]),
          ),
        ),
        if (_open) SelectableText(_lines.isEmpty ? '(vazio)' : _lines.reversed.take(60).join('\n'), style: KTexto.corpoPequeno),
      ]);
}
