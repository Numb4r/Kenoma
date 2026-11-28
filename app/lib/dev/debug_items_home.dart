/// Aba Jogador, a Casa (0.28.0): definir a casa aqui (sem a espera de 30 dias), avançar o tempo das estações em horas e
/// encher os depósitos. Mexem no save do mapa aberto.
library;

import '../core/tiles.dart';
import '../crafting/home_actions.dart';
import '../data/game_data.dart';
import '../player/game_state.dart';
import '../ui/game/game_map_screen.dart' show liveGameState, livePlayerPos;
import 'debug_env.dart';
import 'debug_registry.dart';

GameState _live() => liveGameState() ?? (throw const DebugError('abra o mapa antes'));

/// Faz cada estação contar como se [seconds] tivessem passado (o ponto de partida de cada criatura recua).
int advanceStations(GameState s, int seconds) {
  var n = 0;
  for (final st in s.home.stations.values) {
    for (final uid in st.workers) {
      final at = st.since[uid];
      if (at == null) continue;
      st.since[uid] = at - seconds;
      n++;
    }
  }
  s.changed();
  return n;
}

List<DebugEntry> homeEntries(DebugEnv env) {
  final tools = env.tools;
  return [
    DebugEntry(
      id: 'player.home_here',
      name: 'Definir a casa aqui',
      tab: DebugTab.player,
      kind: DebugKind.action,
      touchesSave: true,
      keywords: const ['casa', 'home', 'definir', 'espera', 'armazém'],
      info: 'A casa vai para a célula onde o Conjurador está, sem a espera de 30 dias. Precisa do nível 10 (use o nível forçado). Com o mapa aberto.',
      run: (c) {
        final s = _live();
        final p = livePlayerPos() ?? (throw const DebugError('sem posição no mapa'));
        final cell = latLonToTile(p.lat, p.lon, biomeZoom);
        final r = setHome(s, cell, tools.clock.nowUtc, ignoreCooldown: true);
        if (r == HomeResult.locked) throw DebugError('a casa abre no nível ${s.balance.home.unlockLevel}');
        return 'Casa na célula ${cell.$1}, ${cell.$2}';
      },
    ),
    DebugEntry(
      id: 'player.home_advance',
      name: 'Avançar o tempo das estações',
      tab: DebugTab.player,
      kind: DebugKind.action,
      touchesSave: true,
      keywords: const ['casa', 'estação', 'tempo', 'produção', 'horas'],
      info: 'Cada criatura trabalhando conta como se essas horas tivessem passado. O depósito continua parando quando enche. Com o mapa aberto.',
      params: const [DebugParam('h', 'horas', options: [DebugOption('1', '1 h'), DebugOption('3', '3 h'), DebugOption('6', '6 h'), DebugOption('12', '12 h'), DebugOption('24', '24 h')], fallback: '3')],
      run: (c) {
        final n = advanceStations(_live(), c.intOf('h') * 3600);
        return '${c.intOf('h')} h a mais para $n ${n == 1 ? 'criatura' : 'criaturas'}';
      },
    ),
    DebugEntry(
      id: 'player.home_fill',
      name: 'Encher os depósitos',
      tab: DebugTab.player,
      kind: DebugKind.action,
      touchesSave: true,
      keywords: const ['casa', 'estação', 'depósito', 'cheio', 'encher'],
      info: 'Avança as estações o bastante para todo depósito encher (as que gastam insumo enchem até onde a carga deixa). Com o mapa aberto.',
      run: (c) async {
        final s = _live();
        final data = await GameData.load();
        advanceStations(s, 2 * s.balance.home.depositS);
        return 'Depósitos cheios em ${data.home.stations.where((d) => s.home.stations[d.id]?.workers.isNotEmpty ?? false).length} estações';
      },
    ),
  ];
}
