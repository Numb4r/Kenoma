/// Aba Posição: o mapa do jogo, o simulador de GPS (velocidade, ruído, recompensa), o teleporte (lugares, coordenada colada
/// ou toque longo no mapa: o antigo Mapa livre virou isto), a última posição guardada, a poça mais perto e os passos. A
/// Patrulha simulada e o diário ficam em `debug_items_patrol.dart`.
library;

import 'dart:async';

import '../core/tiles.dart' show biomeZoom, latLonToTile;
import '../ui/game/game_map_screen.dart' show liveGameState, openGameMap;
import '../world/device_sensors.dart';
import '../world/places.dart';
import 'debug_env.dart';
import 'debug_items_patrol.dart';
import 'debug_registry.dart';
import 'gps_simulator.dart';

String _ll((double, double) p) => '${p.$1},${p.$2}';

/// Os lugares do teleporte (o valor é a coordenada; o `cmd` aceita o nome); `mapa` arma o toque longo no mapa do jogo.
final kTeleportPlaces = [
  for (final (label, p) in const [('Unicamp', kUnicamp), ('Centro', kCentroCampinas), ('Taquaral', kTaquaral), ('Valinhos', kValinhos), ('São Paulo', kPaulista)])
    DebugOption(_ll(p), label),
  const DebugOption('mapa', 'Escolher no mapa'),
];

List<DebugEntry> positionEntries(DebugEnv env) {
  final tools = env.tools, sim = tools.simulator;
  // O mapa do jogo, sem esperar ele fechar (a rota só termina quando ele sai).
  void openMap(DebugCall c) {
    final screen = c.context;
    if (liveGameState() == null && screen != null && screen.mounted) unawaited(openGameMap(screen, tools));
  }

  return [
    DebugEntry(
      id: 'pos.open_map',
      name: 'Abrir o mapa do jogo',
      tab: DebugTab.position,
      kind: DebugKind.action,
      aliases: const ['map.open_game', 'map'],
      keywords: const ['abrir', 'jogar', 'mapa', 'gps'],
      run: (c) {
        unawaited(openGameMap(c.screen, tools));
        return 'mapa';
      },
    ),
    DebugEntry(
      id: 'pos.simulator',
      name: 'Simulador de GPS',
      tab: DebugTab.position,
      kind: DebugKind.toggle,
      aliases: const ['sim'],
      keywords: const ['gps', 'posição', 'fonte', 'joystick'],
      info: 'No lugar do GPS real. O joystick, a velocidade e o teleporte aparecem no mapa do jogo.',
      warn: tools.emulator ? 'Emulador: a localização dele já conta como GPS simulado.' : null,
      read: () => tools.useSimulator ? 'on' : 'off',
      run: (c) => tools.setUseSimulator(c.value == 'on'),
      offReal: () => tools.useSimulator ? 'simulador' : null,
      toReal: () => tools.setUseSimulator(false),
    ),
    DebugEntry(
      id: 'pos.rewards',
      name: 'GPS simulado dá recompensa',
      tab: DebugTab.position,
      kind: DebugKind.toggle,
      keywords: const ['recompensa', 'xp', 'bestiário', 'emulador'],
      info: 'Desligado (o padrão): com o simulador ou no emulador (no mapa e na Patrulha simulada) nada conta para XP, estatísticas ou bestiário, e as capturas entram marcadas como debug.',
      read: () => tools.simRewards ? 'on' : 'off',
      run: (c) => tools.setSimRewards(c.value == 'on'),
      offReal: () => tools.simRewards ? 'simulador com recompensa' : null,
      toReal: () => tools.setSimRewards(false),
    ),
    DebugEntry(
      id: 'pos.speed',
      name: 'Velocidade do simulador',
      tab: DebugTab.position,
      kind: DebugKind.choice,
      aliases: const ['speed'],
      keywords: const ['andando', 'correndo', 'bicicleta', 'carro', 'm/s'],
      options: [for (final s in SimSpeed.values) DebugOption(s.mps.toStringAsFixed(1), '${s.label} ${s.mps.toStringAsFixed(1)}'), const DebugOption('15.0', 'Carro 15')],
      read: () => sim.speedMps.toStringAsFixed(1),
      run: (c) => sim.speedMps = c.numberOf(''),
    ),
    DebugEntry(
      id: 'pos.noise',
      name: 'Ruído de GPS (5 m)',
      tab: DebugTab.position,
      kind: DebugKind.toggle,
      keywords: const ['erro', 'jitter', 'precisão'],
      read: () => sim.noiseM > 0 ? 'on' : 'off',
      run: (c) => sim.noiseM = c.value == 'on' ? 5 : 0,
      offReal: () => sim.noiseM > 0 ? 'ruído ${sim.noiseM.round()} m' : null,
      toReal: () => sim.noiseM = 0,
    ),
    DebugEntry(
      id: 'pos.teleport',
      name: 'Teleporte',
      tab: DebugTab.position,
      kind: DebugKind.coord,
      aliases: const ['tp', 'map.free'],
      keywords: const ['coordenada', 'latitude', 'longitude', 'mapa livre', 'lugar', 'valinhos', 'são paulo', 'taquaral'],
      info: 'Liga o simulador e o leva até o lugar, a coordenada colada ("lat, lon") ou o ponto de um toque longo no mapa do jogo. Abre o mapa se ele estiver fechado.',
      options: kTeleportPlaces,
      read: () => _ll((sim.lat, sim.lon)),
      run: (c) async {
        if (c.value == 'mapa') {
          tools.setPickTeleport(true);
          openMap(c);
          return 'Toque longo no mapa: o simulador vai até lá';
        }
        final p = parseLatLon(c.value)!;
        await tools.setUseSimulator(true);
        sim.teleport(p.$1, p.$2);
        openMap(c);
        return 'Simulador em ${c.value}';
      },
      offReal: () => tools.pickTeleport ? 'escolher no mapa' : null,
      toReal: () => tools.setPickTeleport(false),
    ),
    DebugEntry(
      id: 'pos.lastcell',
      name: 'Última posição guardada',
      tab: DebugTab.position,
      kind: DebugKind.coord,
      aliases: const ['lastcell'],
      keywords: const ['célula', 'abertura', 'save', 'longe'],
      info: 'Fixa a célula que o mapa guarda para a próxima abertura (medir a abertura com o GPS longe). Fica assim até fechar o app. Com o mapa aberto.',
      options: [for (final o in kTeleportPlaces) if (o.value != 'mapa') o],
      read: () => liveGameState()?.lastMapCell?.toString(),
      run: (c) {
        final st = liveGameState();
        if (st == null) throw const DebugError('abra o mapa antes');
        final p = parseLatLon(c.value)!;
        tools.holdLastCell = true;
        st.lastMapCell = latLonToTile(p.$1, p.$2, biomeZoom);
        st.changed();
        return 'Posição guardada em ${c.value}';
      },
      offReal: () => tools.holdLastCell ? 'posição guardada presa' : null,
      toReal: () => tools.holdLastCell = false,
    ),
    DebugEntry(
      id: 'pos.puddle',
      name: 'Ir até a poça mais perto',
      tab: DebugTab.position,
      kind: DebugKind.action,
      aliases: const ['spawn.puddles'],
      keywords: const ['poça', 'rill', 'água'],
      info: 'Liga o GPS simulado sem recompensa e vai até a poça mais perto a até 1 km. Com o mapa aberto.',
      run: (c) => tools.goToNearestPuddle(),
    ),
    DebugEntry(
      id: 'pos.steps',
      name: 'Injetar passos',
      tab: DebugTab.position,
      kind: DebugKind.action,
      aliases: const ['pos.steps_inject'],
      keywords: const ['passos', 'contador', 'pedômetro', 'fagulha'],
      info: 'Somados à leitura do contador, só até fechar o app. Com o contador ligado nos Ajustes, o mapa converte na próxima leitura (a cada 30 s).',
      params: const [DebugParam('n', 'passos', options: [DebugOption('500', '+500'), DebugOption('1000', '+1000'), DebugOption('5000', '+5000')], fallback: '1000')],
      read: () => '${DeviceSensors.debugExtraSteps}',
      run: (c) {
        DeviceSensors.debugExtraSteps += c.intOf('n');
        return '+${DeviceSensors.debugExtraSteps} passos no contador';
      },
      offReal: () => DeviceSensors.debugExtraSteps == 0 ? null : '+${DeviceSensors.debugExtraSteps} passos',
      toReal: () => DeviceSensors.debugExtraSteps = 0,
    ),
    ...patrolEntries(env),
  ];
}
