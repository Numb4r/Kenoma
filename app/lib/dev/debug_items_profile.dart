/// Aba Jogador, o Conjurador: o nível forçado, conceder níveis, XP e pontos de talento, o veículo e o Radar. Os que editam o
/// save em disco pedem o mapa fechado; reabra o mapa depois. O teto de nível e os talentos devidos por nível voltam a
/// valer no carregamento.
library;

import '../crafting/crafting_state.dart' show LoadoutSlot;
import '../ui/game/game_map_screen.dart' show liveGameState;
import 'debug_env.dart';
import 'debug_registry.dart';
import 'street_debug_section.dart';

/// Devolve o JSON do save com [levels] níveis a mais (XP do nível zerado), [xp] a mais e [talent] pontos de talento.
/// O teto de nível e os pontos devidos por nível são aplicados por `GameState.fromJson`.
Map<String, dynamic> grantProfile(Map<String, dynamic> save, {int levels = 0, int xp = 0, int talent = 0}) {
  final player = {...?(save['player'] as Map<String, dynamic>?)};
  player['level'] = ((player['level'] as int?) ?? 1) + levels;
  if (levels > 0) player['xp'] = 0;
  player['xp'] = ((player['xp'] as int?) ?? 0) + xp;
  final conjurer = {...?(save['conjurer'] as Map<String, dynamic>?)};
  conjurer['talent_earned'] = ((conjurer['talent_earned'] as int?) ?? 0) + talent;
  return {...save, 'player': player, 'conjurer': conjurer};
}

List<DebugEntry> profileEntries(DebugEnv env) {
  final tools = env.tools;

  /// O nível forçado (1 a 20) guardado no save; 0 deixa valer o nível real. Sem disco (testes), vale só na memória.
  Future<void> setLevel(int level) async {
    tools.setLevelOverride(level);
    if (liveGameState() != null) return; // o mapa aberto usa o do DevTools e grava o save dele
    try {
      final store = await env.openSave();
      final json = {...?await store.read()}..remove('player_level');
      level == 0 ? json.remove('level_override') : json['level_override'] = level;
      await store.write(json);
    } catch (_) {
      // sem disco, o nível vale só até fechar o menu
    }
  }

  DebugEntry grant(String id, String name, List<String> aliases, List<DebugOption> amounts, {int levels = 0, int xp = 0, int talent = 0}) => DebugEntry(
        id: 'player.$id.add',
        name: name,
        tab: DebugTab.player,
        kind: DebugKind.action,
        aliases: aliases,
        touchesSave: true,
        keywords: const ['xp', 'nível', 'level', 'talento', 'perfil', 'conceder'],
        info: 'Edita o save. Reabra o mapa depois. O nível para no teto.',
        params: [DebugParam('n', 'quanto', options: amounts, fallback: amounts.first.value)],
        run: (c) async {
          final n = c.intOf('n');
          await env.editSave((json) => grantProfile(json, levels: levels * n, xp: xp * n, talent: talent * n));
          return 'Concedido. Reabra o mapa.';
        },
      );

  return [
    DebugEntry(
      id: 'player.level',
      name: 'Nível forçado no jogo',
      tab: DebugTab.player,
      kind: DebugKind.number,
      aliases: const ['level'],
      touchesSave: true,
      keywords: const ['nível', 'level', 'override', 'conjurador', 'forçar'],
      info: '0 usa o nível real. Um valor aqui manda nos Ecos do mapa, na resistência e nos apps do celular. Vale na próxima vez que abrir o mapa.',
      min: 0,
      max: 20,
      read: () => '${tools.levelOverride}',
      run: (c) => setLevel(c.intOf('')),
      offReal: () => tools.levelOverride == 0 ? null : 'nível ${tools.levelOverride}',
      toReal: () => setLevel(0),
    ),
    grant('level', 'Conceder níveis', const ['player.grant'], const [DebugOption('1', '+1'), DebugOption('5', '+5')], levels: 1),
    grant('xp', 'Conceder XP', const [], const [DebugOption('100', '+100'), DebugOption('500', '+500'), DebugOption('2000', '+2000')], xp: 1),
    grant('talent', 'Conceder pontos de talento', const [], const [DebugOption('1', '+1'), DebugOption('3', '+3')], talent: 1),
    DebugEntry(
      id: 'player.vehicle',
      name: 'Equipar veículo',
      tab: DebugTab.player,
      kind: DebugKind.action,
      aliases: const ['vehicle'],
      touchesSave: true,
      keywords: const ['veículo', 'carrinho', 'bicicleta', 'viagem'],
      info: 'Equipa direto no save aberto, sem passar pela bolsa: o id depois de item.vehicle. (cart@perfect, bike). Com o mapa aberto.',
      params: const [DebugParam('id', 'veículo (cart@perfect)', kind: DebugParamKind.text, fallback: 'cart')],
      run: (c) {
        final live = liveGameState();
        if (live == null || c['id'].isEmpty) throw const DebugError('abra o mapa e diga o veículo');
        final id = 'item.vehicle.${c['id']}';
        live.crafting.equipped[c['id'].startsWith('cart') ? LoadoutSlot.vehicleCar : LoadoutSlot.vehicleBike] = id;
        live.changed();
        return id;
      },
    ),
    DebugEntry(
      id: 'player.radar_reset',
      name: 'Zerar a recarga do Radar',
      tab: DebugTab.player,
      kind: DebugKind.action,
      aliases: const ['map.radar_reset'],
      touchesSave: true,
      keywords: const ['radar', 'ocultos', 'zerar', 'recarga'],
      info: 'Zera a recarga do Radar e esquece os Ocultos que ele tinha revelado.',
      run: (_) async {
        await env.editSave(resetRadar);
        return 'Radar pronto.';
      },
    ),
  ];
}
