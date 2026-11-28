/// Aba Mundo, fora o clima (`debug_items_climate.dart`): o relógio UTC, o tráfego simulado, o Ônibus Espectral e os Outros
/// Veilbreakers. Só neste aparelho; nada disso muda o mundo dos amigos.
library;

import 'clock_input.dart';
import 'debug_env.dart';
import 'debug_items_climate.dart';
import 'debug_registry.dart';

List<DebugEntry> worldEntries(DebugEnv env) {
  final tools = env.tools, clock = tools.clock;
  String two(int v) => v.toString().padLeft(2, '0');
  return [
    DebugEntry(
      id: 'world.clock',
      name: 'Relógio UTC',
      tab: DebugTab.world,
      kind: DebugKind.action,
      aliases: const ['time.clock', 'clock'],
      keywords: const ['hora', 'data', 'época', 'override', 'tempo'],
      info: 'O relógio do jogo, em UTC (aaaa-mm-dd hh:mm). Real volta ao do aparelho.',
      params: const [DebugParam('t', 'aaaa-mm-dd hh:mm (UTC)', kind: DebugParamKind.text)],
      read: () => formatUtc(clock.now),
      status: () => '${formatUtc(clock.now)} UTC${clock.overridden ? ' (forçado)' : ''}',
      run: (c) {
        final t = parseUtcInput(c['t']);
        if (t == null) throw const DebugError('Use aaaa-mm-dd hh:mm em UTC');
        clock.setUtc(t);
        return 'Relógio em ${formatUtc(clock.now)} UTC';
      },
      offReal: () => clock.overridden ? 'relógio ${two(clock.now.hour)}:${two(clock.now.minute)} UTC' : null,
      toReal: clock.clear,
    ),
    ...climateEntries(tools),
    DebugEntry(
      id: 'world.traffic_density',
      name: 'Densidade do tráfego',
      tab: DebugTab.world,
      kind: DebugKind.choice,
      aliases: const ['traffic.sim'],
      keywords: const ['carros', 'passantes', 'agentes', 'rush', 'lotado'],
      info: 'O tráfego comum é cenário, só neste aparelho. Hora e clima é o normal.',
      options: const [DebugOption('auto', 'Hora e clima'), DebugOption('0', 'Vazio'), DebugOption('0.3', 'Pouco'), DebugOption('1', 'Rush'), DebugOption('2.5', 'Lotado')],
      read: () => tools.trafficDensity == null ? 'auto' : _num(tools.trafficDensity!),
      run: (c) => c.value == 'auto' ? tools.setTraffic(clearDensity: true) : tools.setTraffic(density: c.numberOf('')),
      offReal: () => tools.trafficDensity == null ? null : 'tráfego ${_num(tools.trafficDensity!)}',
      toReal: () => tools.setTraffic(clearDensity: true),
    ),
    DebugEntry(
      id: 'world.buses',
      name: 'Muitos ônibus',
      tab: DebugTab.world,
      kind: DebugKind.toggle,
      aliases: const ['buses'],
      keywords: const ['ônibus', 'ponto', 'parada', 'avenida'],
      info: 'Quase todo carro novo de avenida vira ônibus (só cena, para ver a parada no ponto).',
      read: () => tools.manyBuses ? 'on' : 'off',
      run: (c) => tools.setManyBuses(c.value == 'on'),
      offReal: () => tools.manyBuses ? 'muitos ônibus' : null,
      toReal: () => tools.setManyBuses(false),
    ),
    DebugEntry(
      id: 'world.spectral',
      name: 'Próximo Ônibus Espectral',
      tab: DebugTab.world,
      kind: DebugKind.action,
      aliases: const ['spectral'],
      keywords: const ['espectral', 'ônibus', 'ponto', 'teleporte'],
      info: 'Leva o GPS simulado a 25 m do ponto mais perto e o relógio para s segundos antes da chegada. Com o mapa aberto.',
      params: const [DebugParam('s', 'segundos antes', kind: DebugParamKind.number, min: 0, max: 600, fallback: '12')],
      run: (c) {
        final sp = tools.nextSpectral?.call();
        if (sp == null) throw const DebugError('nenhum ponto perto (com o mapa aberto)');
        tools.simulator.teleport(sp.lat - 25 / 111320, sp.lon);
        clock.setUtc(sp.at - c.intOf('s'));
        return 'Ônibus em ${c['s']} s';
      },
    ),
    DebugEntry(
      id: 'world.npcs',
      name: 'Outros Veilbreakers em toda célula',
      tab: DebugTab.world,
      kind: DebugKind.toggle,
      aliases: const ['npcs'],
      keywords: const ['npc', 'veilbreakers', 'outros', 'z18'],
      info: 'Um dos Outros Veilbreakers em toda célula z18, só neste aparelho, para conferir e fotografar.',
      read: () => tools.forceNpcs ? 'on' : 'off',
      run: (c) => tools.setForceNpcs(c.value == 'on'),
      offReal: () => tools.forceNpcs ? 'npc em toda célula' : null,
      toReal: () => tools.setForceNpcs(false),
    ),
    DebugEntry(
      id: 'world.npc',
      name: 'Abrir o Veilbreaker mais perto',
      tab: DebugTab.world,
      kind: DebugKind.action,
      aliases: const ['npc'],
      keywords: const ['npc', 'veilbreakers', 'folha'],
      info: 'Vai até o Outro Veilbreaker mais perto e abre a folha dele. Com o mapa aberto.',
      run: (c) => tools.openNearestNpc?.call() ?? (throw const DebugError('nenhum à vista (com o mapa aberto)')),
    ),
    DebugEntry(
      id: 'world.npctune',
      name: 'Próxima sintonia de um Veilbreaker',
      tab: DebugTab.world,
      kind: DebugKind.action,
      aliases: const ['npctune'],
      keywords: const ['npc', 'sintonia', 'veilbreakers', 'relógio'],
      info: 'Leva o GPS simulado a 45 m ao sul do Eco (longe da proteção de 30 m, ainda na tela) e o relógio para s segundos antes.',
      params: const [DebugParam('s', 'segundos antes', kind: DebugParamKind.number, min: 0, max: 600, fallback: '4')],
      run: (c) {
        final tu = tools.nextNpcTune?.call();
        if (tu == null) throw const DebugError('nenhuma sintonia perto (com o mapa aberto)');
        tools.simulator.teleport(tu.lat - 45 / 111320, tu.lon);
        clock.setUtc(tu.at - c.intOf('s'));
        return 'Sintonia em ${c['s']} s';
      },
    ),
  ];
}

String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
