/// Itens das seções Posição e Tempo e mundo: simulador de GPS, velocidade, ruído, joystick, teleporte, relógio UTC e
/// clima forçado.
library;

import 'package:flutter/material.dart';

import '../core/weather.dart';
import '../ui/tema.dart';
import '../world/places.dart';
import 'clock_input.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';
import 'dev_tools.dart';
import 'gps_simulator.dart';

List<DebugItem> positionItems(DebugEnv env) {
  final tools = env.tools;
  return [
    DebugItem(
      id: 'pos.simulator',
      title: 'Simulador de GPS',
      section: DebugSection.position,
      keywords: const ['gps', 'posição', 'fonte', 'simulador'],
      builder: (_) => ListenableBuilder(
        listenable: tools,
        builder: (context, _) => Column(children: [
          Align(alignment: Alignment.centerLeft, child: DebugNote('Fonte de posição: ${tools.useSimulator ? 'simulador' : 'GPS real'}')),
          DebugSwitch(
            title: 'Simulador de GPS',
            subtitle: 'No lugar do GPS real. Joystick, velocidade e teleporte no mapa do jogo.',
            value: tools.useSimulator,
            color: KCores.sinalCiano,
            onChanged: (v) => tools.setUseSimulator(v),
          ),
        ]),
      ),
    ),
    DebugItem(
      id: 'pos.speed',
      title: 'Velocidade do simulador',
      section: DebugSection.position,
      keywords: const ['andando', 'correndo', 'bicicleta', 'm/s'],
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => DebugWrap([
          for (final s in SimSpeed.values)
            DebugChip('${s.label} ${s.mps.toStringAsFixed(1)} m/s', on: tools.simulator.speedMps == s.mps, onTap: () => setState(() => tools.simulator.speedMps = s.mps)),
        ]),
      ),
    ),
    DebugItem(
      id: 'pos.noise',
      title: 'Ruído de GPS',
      section: DebugSection.position,
      keywords: const ['erro', 'jitter', 'precisão'],
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => DebugSwitch(
          title: 'Ruído de GPS (5 m)',
          value: tools.simulator.noiseM > 0,
          onChanged: (v) => setState(() => tools.simulator.noiseM = v ? 5 : 0),
        ),
      ),
    ),
    DebugItem(
      id: 'pos.joystick',
      title: 'Joystick',
      section: DebugSection.position,
      keywords: const ['mover', 'andar', 'controle'],
      builder: (_) => ListenableBuilder(
        listenable: tools,
        builder: (context, _) => DebugNote(tools.useSimulator
            ? 'O joystick aparece por cima do mapa do jogo, no canto de baixo à esquerda.'
            : 'Ligue o simulador de GPS: o joystick aparece por cima do mapa do jogo.'),
      ),
    ),
    DebugItem(
      id: 'pos.teleport',
      title: 'Teleporte',
      section: DebugSection.position,
      keywords: const ['coordenada', 'latitude', 'longitude', 'unicamp', 'centro', 'taquaral'],
      builder: (_) => _Teleport(tools: env.tools),
    ),
  ];
}

class _Teleport extends StatefulWidget {
  const _Teleport({required this.tools});

  final DevTools tools;

  @override
  State<_Teleport> createState() => _TeleportState();
}

class _TeleportState extends State<_Teleport> {
  final _lat = TextEditingController(text: kUnicamp.$1.toString());
  final _lon = TextEditingController(text: kUnicamp.$2.toString());

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _preset((double, double) p) => setState(() {
        _lat.text = p.$1.toString();
        _lon.text = p.$2.toString();
      });

  void _go() {
    final c = parseCoord(_lat.text, _lon.text);
    if (c == null) return debugSnack(context, 'Coordenada inválida');
    widget.tools.simulator.teleport(c.$1, c.$2);
    debugSnack(context, 'Teleportado');
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        Row(children: [Expanded(child: DebugField('Latitude', _lat, numeric: true)), const SizedBox(width: KEspaco.s1), Expanded(child: DebugField('Longitude', _lon, numeric: true))]),
        DebugWrap([
          DebugButton(label: 'Unicamp', color: KCores.textoMudo, onTap: () => _preset(kUnicamp)),
          DebugButton(label: 'Centro', color: KCores.textoMudo, onTap: () => _preset(kCentroCampinas)),
          DebugButton(label: 'Taquaral', color: KCores.textoMudo, onTap: () => _preset(kTaquaral)),
          DebugButton(label: 'Teleportar', onTap: _go),
        ]),
      ]);
}

List<DebugItem> timeItems(DebugEnv env) {
  final tools = env.tools;
  return [
    DebugItem(
      id: 'time.clock',
      title: 'Relógio UTC',
      section: DebugSection.time,
      keywords: const ['hora', 'data', 'época', 'override', 'tempo'],
      builder: (_) => _ClockItem(tools: tools),
    ),
    DebugItem(
      id: 'time.weather',
      title: 'Clima forçado',
      section: DebugSection.time,
      keywords: const ['chuva', 'sol', 'nublado', 'tempo', 'hud', 'spawns'],
      builder: (_) => ListenableBuilder(
        listenable: tools.force,
        builder: (context, _) => DebugColumn([
          const DebugNote('Vale para o HUD, a chuva e os pesos de spawn.'),
          DebugWrap([
            DebugChip('Real', on: tools.force.weather == null, color: KCores.veuVioleta, onTap: () => tools.force.set(clearWeather: true)),
            for (final w in Weather.values) DebugChip(w.label, on: tools.force.weather == w, color: KCores.veuVioleta, onTap: () => tools.force.set(weather: w)),
          ]),
        ]),
      ),
    ),
  ];
}

class _ClockItem extends StatefulWidget {
  const _ClockItem({required this.tools});

  final DevTools tools;

  @override
  State<_ClockItem> createState() => _ClockItemState();
}

class _ClockItemState extends State<_ClockItem> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply() {
    final t = parseUtcInput(_text.text);
    if (t == null) return debugSnack(context, 'Use aaaa-mm-dd hh:mm em UTC');
    widget.tools.clock.setUtc(t);
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.tools.clock;
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => DebugColumn([
        Text('${formatUtc(clock.now)}${clock.overridden ? '  (OVERRIDE)' : ''}', style: KTexto.rotulo.copyWith(color: clock.overridden ? KCores.brasaLaranja : KCores.texto)),
        DebugField('aaaa-mm-dd hh:mm (UTC)', _text),
        DebugWrap([
          DebugButton(label: 'Aplicar', color: KCores.brasaLaranja, onTap: _apply),
          DebugButton(label: 'Relógio real', color: KCores.textoMudo, onTap: clock.clear),
        ]),
      ]),
    );
  }
}
