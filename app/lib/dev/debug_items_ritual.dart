/// Aba Criaturas, o ritual: abrir o ritual de qualquer espécie (num jogo descartável, sem tocar o save) e revelar ou zerar
/// a pesquisa dos espaços (no save, vale na próxima vez que o mapa abrir). Forçar um Eco de ritual no próximo spawn é o
/// `creature.ritual`.
library;

import '../core/astro.dart' show moonPhase;
import '../core/weather.dart' show Weather;
import '../crafting/ritual_data.dart';
import '../data/game_data.dart';
import '../player/conjurer.dart' show ConjurerState;
import '../player/game_state.dart';
import '../ui/ritual/ritual_screen.dart';
import 'debug_env.dart';
import 'debug_registry.dart';

const _species = [DebugOption('soot.ritual', 'Kilnshade'), DebugOption('frond.ritual', 'Rootseer'), DebugOption('rill.ritual', 'Wellmirror')];

/// Um jogo descartável para o ritual: nível 8, Bolsa cheia dos materiais e um Círculo de Fogo, Planta e Água.
GameState _sandbox(GameData d, {required bool reveal}) => GameState(
      groupCode: 'DEBUG-RITUAL',
      balance: d.progress,
      inventory: {for (final r in d.ritual.recipes.values) for (final m in r.materials) m.item: 9},
      collection: [
        for (final (uid, sp) in [('dbg-fire', 'soot.eco'), ('dbg-plant', 'frond.eco'), ('dbg-water', 'rill.eco')]) CreatureInstance(uid: uid, speciesId: sp, level: 10, capturedUtc: 1),
      ],
      circle: ['dbg-fire', 'dbg-plant', 'dbg-water'],
      conjurer: ConjurerState(ritualResearch: {if (reveal) for (final r in d.ritual.recipes.values) r.speciesId: r.slotCount}),
    )..levelOverride = 8;

List<DebugEntry> ritualEntries(DebugEnv env) {
  final tools = env.tools;
  WorldCondition world(RitualRecipe r, bool correct) {
    final t = tools.clock.nowUtc;
    final base = WorldCondition(hour: localHourOf(t), biome: 'urban', moon: moonPhase(t), weather: Weather.parse(tools.force.weather));
    return correct ? r.condition.satisfying(base) : base;
  }

  Future<String> research(bool all) async {
    final data = await GameData.load();
    await env.editSave((json) {
      final conj = {...?(json['conjurer'] as Map<String, dynamic>?)};
      conj['ritual_research'] = {if (all) for (final r in data.ritual.recipes.values) r.speciesId: r.slotCount};
      return {...json, 'conjurer': conj};
    });
    return all ? 'Todos os espaços revelados' : 'Pesquisa zerada';
  }

  return [
    DebugEntry(
      id: 'creature.ritual_open',
      name: 'Abrir ritual de qualquer espécie',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['cap.ritual'],
      keywords: const ['ritual', 'círculo', 'selar', 'espírito', 'kilnshade', 'rootseer', 'wellmirror'],
      info: 'Num jogo descartável (nível 8, Bolsa cheia, Círculo de Fogo, Planta e Água). Não mexe no save. Sem a condição certa, vale a hora e a lua do relógio do jogo, bioma Urbano.',
      params: const [
        DebugParam('species', 'espécie', options: _species, fallback: 'soot.ritual'),
        DebugParam('correct', 'condição do mundo certa', kind: DebugParamKind.toggle, fallback: 'off'),
        DebugParam('reveal', 'espaços revelados', kind: DebugParamKind.toggle, fallback: 'off'),
      ],
      run: (c) async {
        final screen = c.screen;
        final d = await GameData.load();
        final r = d.ritual.of(c['species']);
        if (r == null) throw DebugError('Sem receita para ${c['species']}');
        if (!screen.mounted) return null;
        await runRitual(screen,
            state: _sandbox(d, reveal: c.flag('reveal')), data: d, recipe: r, uid: DateTime.now().microsecondsSinceEpoch, level: 10, world: () => world(r, c.flag('correct')), nowUtc: () => tools.clock.nowUtc);
        return null;
      },
    ),
    DebugEntry(
      id: 'creature.ritual_research',
      name: 'Revelar a pesquisa de ritual',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['player.ritual_research'],
      touchesSave: true,
      keywords: const ['ritual', 'pesquisa', 'bestiário', 'espaços', 'revelar'],
      info: 'Todos os espaços de todas as receitas. Vale na próxima vez que o mapa abrir.',
      run: (_) => research(true),
    ),
    DebugEntry(
      id: 'creature.ritual_research_clear',
      name: 'Zerar a pesquisa de ritual',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      touchesSave: true,
      destructive: true,
      keywords: const ['ritual', 'pesquisa', 'zerar'],
      info: 'Esquece o que a pesquisa revelou. Vale na próxima vez que o mapa abrir.',
      run: (_) => research(false),
    ),
  ];
}
