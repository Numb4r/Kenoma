/// Aba Mundo, o clima: clima e eventos forçados, a velocidade do clima, a Simulação de clima (passa por todos os climas do
/// `clima.json`), o efeito no toque e o pé do arco-íris. Tudo só neste aparelho; a simulação não dá recompensa
/// (`DevTools.sandboxed`).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/weather.dart';
import '../data/climate_catalog.dart';
import 'debug_registry.dart';
import 'dev_tools.dart';

const _tapNames = {
  'lightning': 'Raio', 'hail': 'Granizo', 'dust_devil': 'Redemoinho', 'meteor': 'Meteoro', 'violet_bolt': 'Raio violeta', //
  'spark_fall': 'Fagulha do céu', 'puddle': 'Poça', 'rainbow': 'Arco-íris', 'dry_bolt': 'Raio seco', 'branch': 'Galho', 'rune': 'Runa',
  'gaze': 'Olhar', 'hurricane_eye': 'Olho do furacão', 'procession': 'Procissão', 'funnel': 'Funil do tornado', 'ghost_building': 'Prédio antigo (Maré)',
};

/// O catálogo do clima, lido só quando pedem (o mapa já deixa carregado): ler ao montar o menu travava a leitura dos
/// assets nos testes de widget.
Future<void> _loadCatalog() async {
  if (ClimateCatalog.lastLoaded?.eventInfos.isNotEmpty ?? false) return;
  final s = await Future.wait([rootBundle.loadString('assets/data/clima.json', cache: false), rootBundle.loadString('assets/data/eventos.json', cache: false)]);
  ClimateCatalog.lastLoaded = ClimateCatalog.fromJson(jsonDecode(s[0]) as Map<String, dynamic>, jsonDecode(s[1]) as Map<String, dynamic>);
}

List<DebugOption> _climates() {
  final legacy = {for (final w in Weather.values) w.id};
  return [
    for (final w in Weather.values) DebugOption(w.id, w.label),
    for (final c in ClimateCatalog.lastLoaded?.climates.values ?? const <ClimateInfo>[])
      if (!legacy.contains(c.id)) DebugOption(c.id, c.name),
  ];
}

String _climateName(String id) => [for (final o in _climates()) if (o.value == id) o.label].firstOrNull ?? id;

List<DebugEntry> climateEntries(DevTools tools) {
  final f = tools.force;
  return [
    DebugEntry(
      id: 'world.weather',
      name: 'Clima forçado',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      aliases: const ['time.weather', 'weather'],
      keywords: const ['chuva', 'sol', 'nublado', 'tempo', 'hud', 'spawns', 'clima', 'místico'],
      info: 'Vale para o HUD, o desenho, as peças do clima e os pesos de spawn. Antes da época 6, as peças usam o modelo dela. Os climas além dos quatro antigos chegam do clima.json (botão carregar).',
      optionsOf: _climates,
      load: _loadCatalog,
      read: () => f.weather,
      run: (c) => f.set(weather: c.value),
      offReal: () => f.weather == null ? null : 'clima ${_climateName(f.weather!)}',
      toReal: () => f.set(clearWeather: true),
    ),
    DebugEntry(
      id: 'world.events',
      name: 'Eventos forçados',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      multi: true,
      aliases: const ['time.events', 'event'],
      keywords: const ['evento', 'vigília', 'lua carmim', 'aurora', 'arco-íris', 'tornado', 'procissão', 'silêncio', 'sexta-feira 13'],
      info: 'Até dois eventos por cima do clima (o forçado ou o do mundo), com as combinações. Antes da época 12, vale o modelo dela. Só neste aparelho.',
      optionsOf: () => [for (final e in ClimateCatalog.lastLoaded?.eventInfos.values ?? const <EventInfo>[]) DebugOption(e.id, e.name)],
      load: _loadCatalog,
      read: () => f.events.join(','),
      run: (c) => f.toggleEvent(c.value),
      offReal: () => f.events.isEmpty ? null : 'eventos ${f.events.join('+')}',
      toReal: f.clearEvents,
    ),
    DebugEntry(
      id: 'world.weather_speed',
      name: 'Velocidade do clima',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      aliases: const ['time.weather_speed'],
      keywords: const ['formação', 'poças', 'neve', 'dunas', 'acelerar'],
      info: 'Quantas vezes mais rápido o clima forçado se forma e seca no chão. Só neste aparelho.',
      options: const [DebugOption('10', '10×'), DebugOption('60', '60×')],
      read: () => '${f.speed.round()}',
      run: (c) => f.setSpeed(c.numberOf('')),
      offReal: () => f.speed == 1 ? null : 'clima ${f.speed.round()}×',
      toReal: () => f.setSpeed(1),
    ),
    DebugEntry(
      id: 'world.weather_sim',
      name: 'Simulação de clima',
      tab: DebugTab.world,
      kind: DebugKind.toggle,
      aliases: const ['time.weather_sim'],
      keywords: const ['simulação', 'todos os climas', 'sequência', 'formação'],
      info: 'Passa por todos os climas, um depois do outro, do zero: forma, depois acaba e seca. O nome e a fase aparecem nos avisos do mapa. Não muda o mundo nem dá recompensa.',
      load: _loadCatalog,
      read: () => f.simulating ? 'on' : 'off',
      run: (c) {
        if (c.value == 'off') return f.stopSim();
        final ids = [for (final o in _climates()) o.value];
        if (ids.isEmpty) throw const DebugError('sem climas carregados');
        f.startSim(ids);
      },
      offReal: () => f.simulating ? 'simulação de clima' : null,
      toReal: f.stopSim,
    ),
    DebugEntry(
      id: 'world.weather_sim_step',
      name: 'Minutos por clima (simulação)',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      options: const [DebugOption('1', '1 min'), DebugOption('2', '2 min'), DebugOption('5', '5 min')],
      enabled: () => f.simulating,
      read: () => f.sim == null ? null : '${(f.sim!.stepS / 60).round()}',
      run: (c) => f.simStep(c.numberOf('') * 60),
    ),
    DebugEntry(
      id: 'world.weather_sim_repeat',
      name: 'Repetir este clima (simulação)',
      tab: DebugTab.world,
      kind: DebugKind.toggle,
      enabled: () => f.simulating,
      read: () => f.sim?.repeat ?? false ? 'on' : 'off',
      run: (c) => f.simRepeat(c.value == 'on'),
    ),
    DebugEntry(
      id: 'world.weather_sim_jump',
      name: 'Pular para o clima (simulação)',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      enabled: () => f.simulating,
      optionsOf: () => f.sim == null ? const [] : [for (final (i, o) in _climates().indexed) if (i < f.sim!.ids.length) DebugOption('$i', o.label)],
      read: () => f.simState() == null ? null : '${f.simState()!.index}',
      run: (c) => f.simJump(c.intOf('')),
    ),
    DebugEntry(
      id: 'world.tap_effect',
      name: 'Efeito do clima no toque',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      aliases: const ['time.weather_tap', 'time.lightning_here'],
      keywords: const ['raio aqui', 'raio', 'granizo', 'redemoinho', 'meteoro', 'toque', 'efeito', 'trovão'],
      info: 'Arme um efeito e toque no mapa do jogo: ele acontece ali, só neste aparelho (o raio cai mesmo do seu lado, com clarão, trovão e o Eco carregado).',
      options: [for (final e in _tapNames.entries) DebugOption(e.key, e.value)],
      read: () => f.tapEffect,
      run: (c) => f.set(tapEffect: c.value),
      offReal: () => f.tapEffect == null ? null : 'toque: ${_tapNames[f.tapEffect] ?? f.tapEffect}',
      toReal: () => f.tapEffect = null,
    ),
    DebugEntry(
      id: 'world.rainbow_foot',
      name: 'Ir até o pé do arco-íris',
      tab: DebugTab.world,
      kind: DebugKind.action,
      aliases: const ['time.rainbow_foot'],
      keywords: const ['arco-íris', 'arco', 'pé', 'prisma', 'teleporte', 'feérico'],
      info: 'Teleporta o GPS simulado até o pé do arco-íris ativo mais perto. Sem arco: force o evento Arco-íris ou solte um no toque.',
      run: (c) async {
        await tools.setUseSimulator(true);
        final jump = tools.force.rainbowFoot;
        if (jump == null) {
          // Com o mapa fechado, o teleporte fica pedido e acontece quando ele abrir.
          tools.force.rainbowJumpPending = true;
          return 'Abra o mapa do jogo: o GPS simulado vai até o pé do arco-íris mais perto';
        }
        final p = jump();
        if (p == null) throw const DebugError('Nenhum arco-íris ativo por perto');
        tools.simulator.teleport(p.$1, p.$2);
        return 'No pé do arco-íris';
      },
    ),
  ];
}
