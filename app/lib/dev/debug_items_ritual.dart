/// Itens de debug do ritual: abrir o ritual de qualquer espécie (num jogo descartável, sem tocar o save), forçar um Eco de
/// ritual no próximo spawn e revelar ou zerar a pesquisa dos espaços (no save, vale na próxima vez que o mapa abrir).
library;

import 'package:flutter/material.dart';

import '../core/astro.dart' show moonPhase;
import '../core/weather.dart' show Weather;
import '../player/conjurer.dart' show ConjurerState;
import '../crafting/ritual_data.dart';
import '../data/game_data.dart';
import '../player/game_state.dart';
import '../ui/ritual/ritual_screen.dart';
import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

List<DebugItem> ritualDebugItems(DebugEnv env) {
  final force = env.tools.force;
  return [
    DebugItem(
      id: 'cap.ritual',
      title: 'Abrir ritual de qualquer espécie',
      section: DebugSection.capture,
      keywords: const ['ritual', 'círculo', 'selar', 'espírito', 'kilnshade', 'rootseer', 'wellmirror'],
      builder: (_) => _RitualOpener(env: env),
    ),
    DebugItem(
      id: 'spawn.ritual',
      title: 'Forçar Eco de ritual',
      section: DebugSection.spawns,
      keywords: const ['ritual', 'espírito', 'próximo spawn', 'kilnshade'],
      builder: (_) => ListenableBuilder(
        listenable: force,
        builder: (_, _) => DebugColumn([
          const DebugNote('O próximo Eco novo à vista vira o Eco de ritual da família dele (nível 8 ou mais para abrir).'),
          DebugChip('Eco de ritual', on: force.nextRitual, color: KCores.brasaLaranja, onTap: () => force.set(ritual: !force.nextRitual)),
        ]),
      ),
    ),
    DebugItem(
      id: 'player.ritual_research',
      title: 'Pesquisa de ritual',
      section: DebugSection.player,
      keywords: const ['ritual', 'pesquisa', 'bestiário', 'espaços', 'revelar', 'zerar'],
      builder: (_) => Builder(builder: (context) {
        Future<void> set(bool all) async {
          final say = debugSayer(context);
          try {
            final data = await GameData.load();
            final store = await env.openSave();
            final json = {...?await store.read()};
            final conj = {...?(json['conjurer'] as Map<String, dynamic>?)};
            conj['ritual_research'] = {if (all) for (final r in data.ritual.recipes.values) r.speciesId: r.slotCount};
            json['conjurer'] = conj;
            await store.write(json);
            say(all ? 'Todos os espaços revelados' : 'Pesquisa zerada');
          } catch (e) {
            say('Não deu para gravar o save: $e');
          }
        }

        return DebugColumn([
          const DebugNote('Mexe no save. Vale na próxima vez que o mapa abrir.', color: KCores.brasaLaranja),
          DebugWrap([
            DebugButton(label: 'Revelar todos', color: KCores.sinalCiano, onTap: () => set(true)),
            DebugButton(label: 'Zerar a pesquisa', color: KCores.textoMudo, onTap: () => set(false)),
          ]),
        ]);
      }),
    ),
  ];
}

/// Escolhe a espécie e abre o ritual num [GameState] descartável: nível 8, Bolsa cheia dos materiais e um Círculo de Fogo,
/// Planta e Água. O resultado não vai para o save.
class _RitualOpener extends StatefulWidget {
  const _RitualOpener({required this.env});

  final DebugEnv env;

  @override
  State<_RitualOpener> createState() => _RitualOpenerState();
}

class _RitualOpenerState extends State<_RitualOpener> {
  // Os dados só carregam ao tocar em Abrir: o menu aberto não pode disparar leitura de assets (o cache dos testes).
  static const _species = {'soot.ritual': 'Kilnshade', 'frond.ritual': 'Rootseer', 'rill.ritual': 'Wellmirror'};
  String _id = _species.keys.first;
  bool _correct = false;
  bool _reveal = false;

  GameState _sandbox(GameData d) => GameState(
        groupCode: 'DEBUG-RITUAL',
        balance: d.progress,
        inventory: {for (final r in d.ritual.recipes.values) for (final m in r.materials) m.item: 9},
        collection: [
          for (final (uid, sp) in [('dbg-fire', 'soot.eco'), ('dbg-plant', 'frond.eco'), ('dbg-water', 'rill.eco')]) CreatureInstance(uid: uid, speciesId: sp, level: 10, capturedUtc: 1),
        ],
        circle: ['dbg-fire', 'dbg-plant', 'dbg-water'],
        conjurer: ConjurerState(ritualResearch: {if (_reveal) for (final r in d.ritual.recipes.values) r.speciesId: r.slotCount}),
      )..levelOverride = 8;

  WorldCondition _world(RitualRecipe r) {
    final t = widget.env.tools.clock.nowUtc;
    final base = WorldCondition(hour: localHourOf(t), biome: 'urban', moon: moonPhase(t), weather: widget.env.tools.force.weather ?? Weather.clear);
    return _correct ? r.condition.satisfying(base) : base;
  }

  Future<void> _open() async {
    final say = debugSayer(context);
    final d = await GameData.load();
    final r = d.ritual.of(_id);
    if (r == null) return say('Sem receita para $_id');
    if (!mounted) return;
    await runRitual(context,
        state: _sandbox(d), data: d, recipe: r, uid: DateTime.now().microsecondsSinceEpoch, level: 10, world: () => _world(r), nowUtc: () => widget.env.tools.clock.nowUtc);
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        const DebugNote('Num jogo descartável (nível 8, Bolsa cheia, Círculo de Fogo, Planta e Água). Não mexe no save.'),
        DebugWrap([for (final e in _species.entries) DebugChip(e.value, on: _id == e.key, onTap: () => setState(() => _id = e.key))]),
        DebugSwitch(title: 'Condição do mundo certa', subtitle: 'Senão vale a hora e a lua do relógio do jogo, bioma Urbano.', value: _correct, onChanged: (v) => setState(() => _correct = v)),
        DebugSwitch(title: 'Espaços revelados', value: _reveal, onChanged: (v) => setState(() => _reveal = v)),
        DebugButton(label: 'Abrir ritual', color: KCores.sinalCiano, onTap: _open),
      ]);
}
