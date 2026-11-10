/// Itens do clima no tempo (seção Tempo e mundo): a velocidade do clima forçado e a Simulação de clima, que passa por todos
/// os climas do `clima.json`. Só neste aparelho; a simulação não dá recompensa (`DevTools.sandboxed`).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/climate_catalog.dart';
import '../ui/tema.dart';
import '../world/debug_force.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';
import 'dev_tools.dart';

List<DebugItem> climateTimeItems(DevTools tools) => [
      DebugItem(
        id: 'time.weather_speed',
        title: 'Velocidade do clima',
        section: DebugSection.time,
        keywords: const ['formação', 'poças', 'neve', 'dunas', 'acelerar', 'clima'],
        builder: (_) => ListenableBuilder(
          listenable: tools.force,
          builder: (context, _) => DebugColumn([
            const DebugNote('Quantas vezes mais rápido o clima forçado se forma e seca no chão. Só neste aparelho.'),
            DebugWrap([
              for (final v in const [1.0, 10.0, 60.0])
                DebugChip('${v.toInt()}x', on: tools.force.speed == v, color: KCores.veuVioleta, onTap: () => tools.force.setSpeed(v)),
            ]),
          ]),
        ),
      ),
      DebugItem(
        id: 'time.weather_sim',
        title: 'Simulação de clima',
        section: DebugSection.time,
        keywords: const ['simulação', 'todos os climas', 'sequência', 'clima', 'formação'],
        builder: (_) => _SimItem(force: tools.force),
      ),
    ];

class _SimItem extends StatefulWidget {
  const _SimItem({required this.force});

  final DebugForce force;

  @override
  State<_SimItem> createState() => _SimItemState();
}

class _SimItemState extends State<_SimItem> {
  ClimateCatalog? _catalog = ClimateCatalog.lastLoaded;

  void _load() {
    rootBundle.loadString('assets/data/clima.json', cache: false).then((s) {
      if (mounted) setState(() => _catalog = ClimateCatalog.fromJson(jsonDecode(s) as Map<String, dynamic>));
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.force;
    final climates = _catalog?.climates.values.toList() ?? const <ClimateInfo>[];
    return ListenableBuilder(
      listenable: f,
      builder: (context, _) {
        final sim = f.sim, st = f.simState();
        return DebugColumn([
          const DebugNote('Passa por todos os climas, um depois do outro, do zero: forma, depois acaba e seca. O nome e a fase aparecem nos avisos do mapa. Não muda o mundo nem dá recompensa.'),
          DebugWrap([
            if (sim == null)
              DebugButton(label: 'Começar', color: KCores.veuVioleta, enabled: climates.isNotEmpty, onTap: () => f.startSim([for (final c in climates) c.id]))
            else
              DebugButton(label: 'Parar', color: KCores.brasaLaranja, onTap: f.stopSim),
            if (sim != null) DebugChip('Repetir este', on: sim.repeat, color: KCores.veuVioleta, onTap: () => f.simRepeat(!sim.repeat)),
            if (_catalog == null) DebugButton(label: 'Carregar climas', color: KCores.textoMudo, onTap: _load),
          ]),
          if (sim != null) ...[
            DebugWrap([
              for (final m in const [1, 2, 5])
                DebugChip('$m min por clima', on: sim.stepS == m * 60, color: KCores.sinalCiano, onTap: () => f.simStep(m * 60.0)),
            ]),
            DebugWrap([
              for (final (i, c) in climates.indexed)
                if (i < sim.ids.length) DebugChip(c.name, on: st?.index == i, color: KCores.veuVioleta, onTap: () => f.simJump(i)),
            ]),
          ],
        ]);
      },
    );
  }
}
