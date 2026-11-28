/// Aba Criaturas: forçar o próximo Eco (comportamento, variante, Brilhante, Espírito, ritual), criar criaturas na Aura, a
/// camada pessoal de spawn e o Círculo de teste, marcar espécie vista e a saída animada. A sintonia fica em
/// `debug_capture.dart`; ritual e pesquisa em `debug_items_ritual.dart`.
///
/// O que nasce pelo "Criar criatura" vive fora do mundo determinístico (`world/debug_creatures.dart`) e não conta para o
/// bestiário nem para as estatísticas. O último formulário fica nas preferências do menu.
library;

import '../capture/eco_type.dart';
import '../core/behavior.dart';
import '../data/tuning_data.dart';
import '../ui/game/game_map_screen.dart' show liveGameState;
import '../ui/type_label.dart';
import '../world/debug_creatures.dart';
import 'debug_capture.dart';
import 'debug_env.dart';
import 'debug_items_fusion.dart';
import 'debug_items_ritual.dart';
import 'debug_registry.dart';

/// As espécies Eco candidatas do [spec]: a escolhida, ou todas as Eco do tipo. Só as que existem nos dados.
List<String> debugCandidates(DebugCreatureSpec spec, List<EcoSpecies> species) => [
      for (final s in species)
        if (s.tier == 'eco' && !s.ritualOnly && (spec.speciesId != null ? s.id == spec.speciesId : s.type.name == spec.type)) s.id,
    ];

/// O formulário do "Criar criatura" como valores dos parâmetros (para voltar das preferências).
Map<String, String> creatureForm(DebugCreatureSpec s) => {
      'species': s.speciesId ?? 'tipo',
      if (s.type != null) 'type': s.type!,
      'layer': s.spirit ? 'spirit' : 'eco',
      'level': '${s.level}',
      'shiny': s.shiny ? 'on' : 'off',
      'variant': s.variant.id,
      'behavior': s.behavior.id,
      'count': '${s.count}',
      'walk': s.walk ? 'on' : 'off',
    };

List<DebugEntry> creatureEntries(DebugEnv env) {
  final tools = env.tools, force = tools.force;
  List<EcoSpecies> ecos() => [for (final s in env.capture.data?.species ?? const <EcoSpecies>[]) if (s.tier == 'eco' && !s.ritualOnly) s];
  DebugEntry next(String id, String name, String alias, bool Function() get, void Function(bool v) set, {String? info}) => DebugEntry(
        id: 'creature.$id',
        name: name,
        tab: DebugTab.creatures,
        kind: DebugKind.toggle,
        aliases: [alias],
        keywords: const ['próximo spawn', 'forçar', 'eco'],
        info: info,
        read: () => get() ? 'on' : 'off',
        run: (c) => set(c.value == 'on'),
        offReal: () => get() ? 'próximo: ${name.toLowerCase()}' : null,
        toReal: () => set(false),
      );
  return [
    DebugEntry(
      id: 'creature.behavior',
      name: 'Comportamento do próximo Eco',
      tab: DebugTab.creatures,
      kind: DebugKind.choice,
      aliases: const ['spawn.behavior'],
      keywords: const ['eco', 'oculto', 'passivo', 'próximo spawn', 'forçar'],
      warn: 'o que for forçado e capturado fica no seu save como se fosse de verdade.',
      options: [for (final b in EcoBehavior.values) DebugOption(b.id, b.label)],
      read: () => force.nextBehavior?.id,
      run: (c) => force.set(behavior: EcoBehavior.parse(c.value)),
      offReal: () => force.nextBehavior == null ? null : 'próximo: ${force.nextBehavior!.label.toLowerCase()}',
      toReal: () {
        force.nextBehavior = null;
        force.set();
      },
    ),
    next('variant', 'Variante de bioma', 'spawn.variant', () => force.nextVariant, (v) => force.set(variant: v)),
    next('shiny', 'Brilhante', 'spawn.shiny', () => force.nextShiny, (v) => force.set(shiny: v)),
    next('spirit', 'Espírito', 'spawn.spirit', () => force.nextSpirit, (v) => force.set(spirit: v), info: 'O próximo Eco novo à vista vira o Espírito da família dele, mesmo abaixo do nível 8.'),
    next('ritual', 'Eco de ritual', 'spawn.ritual', () => force.nextRitual, (v) => force.set(ritual: v), info: 'O próximo Eco novo à vista vira o Eco de ritual da família dele (nível 8 ou mais para abrir).'),
    DebugEntry(
      id: 'creature.create',
      name: 'Criar criatura',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['spawn.create', 'creature'],
      keywords: const ['criar', 'criatura', 'eco', 'espírito', 'nível', 'brilhante', 'carmesim', 'variante', 'aura', 'repetir', 'spawn'],
      info: 'Nasce na Aura com a costura, fora do mundo do grupo. Fica 20 minutos ou até ser capturada, marcada como debug: não conta para o bestiário nem para as estatísticas. Acima do teto da camada (Eco 20, Espírito 30), a sintonia usa o teto. O formulário fica: tocar de novo repete.',
      load: env.capture.ensure,
      params: [
        DebugParam('species', 'espécie', optionsOf: () => [const DebugOption('tipo', 'Só o tipo'), for (final s in ecos()) DebugOption(s.id, s.name)], fallback: 'tipo'),
        DebugParam('type', 'tipo (sorteia a espécie)', optionsOf: () => [for (final t in EcoType.values) if (ecos().any((s) => s.type == t)) DebugOption(t.name, typeLabel(t))], fallback: 'fire'),
        const DebugParam('layer', 'camada', options: [DebugOption('eco', 'Eco'), DebugOption('spirit', 'Espírito')], fallback: 'eco'),
        const DebugParam('level', 'nível', kind: DebugParamKind.number, min: 1, max: 40, fallback: '5'),
        const DebugParam('shiny', 'Brilhante', kind: DebugParamKind.toggle, fallback: 'off'),
        DebugParam('variant', 'variante', options: [for (final v in DebugVariant.values) DebugOption(v.id, v.label)], fallback: 'none'),
        DebugParam('behavior', 'comportamento', options: [for (final b in EcoBehavior.values) DebugOption(b.id, b.label)], fallback: 'passive'),
        const DebugParam('count', 'quantidade', kind: DebugParamKind.number, min: 1, max: 10, fallback: '1'),
        const DebugParam('walk', 'anda em laço', kind: DebugParamKind.toggle, fallback: 'off'),
      ],
      run: (c) {
        final spec = DebugCreatureSpec(
          speciesId: c['species'] == 'tipo' ? null : c['species'],
          type: c['species'] == 'tipo' ? c['type'] : null,
          spirit: c['layer'] == 'spirit',
          level: c.intOf('level'),
          shiny: c.flag('shiny'),
          variant: DebugVariant.parse(c['variant']),
          behavior: EcoBehavior.parse(c['behavior']),
          count: c.intOf('count'),
          walk: c.flag('walk'),
        );
        final ids = debugCandidates(spec, env.capture.data!.species);
        if (ids.isEmpty) throw const DebugError('Escolha uma espécie ou um tipo.');
        force.creatures.request(spec, ids);
        env.prefs?.setCreatureForm(spec.toJson());
        return '${spec.count} na fila: nascem na Aura na próxima atualização do mapa (20 min ou até a captura).';
      },
      offReal: () => force.creatures.pending > 0 ? '${force.creatures.pending} criatura(s) na fila' : null,
      toReal: force.creatures.clear,
    ),
    DebugEntry(
      id: 'creature.hide_personal',
      name: 'Esconder a camada pessoal',
      tab: DebugTab.creatures,
      kind: DebugKind.toggle,
      aliases: const ['spawn.personal'],
      keywords: const ['pessoal', 'círculo', 'habilidade', 'base'],
      info: 'O que as habilidades do Círculo acrescentam só para você. Escondida, o mapa mostra só o mundo base, igual para todos.',
      read: () => tools.hidePersonal ? 'on' : 'off',
      run: (c) => tools.setHidePersonal(c.value == 'on'),
      offReal: () => tools.hidePersonal ? 'sem a camada pessoal' : null,
      toReal: () => tools.setHidePersonal(false),
    ),
    DebugEntry(
      id: 'creature.test_circle',
      name: 'Círculo de teste',
      tab: DebugTab.creatures,
      kind: DebugKind.choice,
      multi: true,
      keywords: const ['círculo', 'habilidade', 'rill', 'hum', 'shade', 'wisp', 'sprig', 'bit', 'clod'],
      info: 'Só no mapa, nível 10, o save não muda: até três famílias, ou o Círculo vazio. A troca vale a partir da janela seguinte de cada célula.',
      options: [
        const DebugOption('vazio', 'Vazio'),
        for (final f in ['rill', 'hum', 'clod', 'shade', 'wisp', 'bit', 'sprig']) DebugOption(f, f),
      ],
      read: () {
        final t = tools.testCircle;
        return t == null ? '' : (t.isEmpty ? 'vazio' : [for (final id in t) id.split('.').first].join(','));
      },
      run: (c) {
        if (c.value == 'vazio') return tools.setTestCircle(const []);
        final now = [...?tools.testCircle];
        if (!now.remove('${c.value}.eco') && now.length < 3) now.add('${c.value}.eco');
        tools.setTestCircle(now);
      },
      offReal: () => tools.testCircle == null ? null : 'círculo de teste',
      toReal: () => tools.setTestCircle(null),
    ),
    DebugEntry(
      id: 'creature.layers',
      name: 'Camadas de spawn agora',
      tab: DebugTab.creatures,
      kind: DebugKind.view,
      keywords: const ['hash', 'base', 'pessoal', 'janela', 'célula'],
      info: 'Dois aparelhos na mesma célula e janela: a base tem de ser igual e a pessoal, diferente (outro player_id).',
      read: () => 'Nesta sessão: ${tools.personalStats?.call() ?? 'abra o mapa do jogo'}\n${tools.layerHashes?.call() ?? 'Hashes: abra o mapa do jogo'}',
    ),
    DebugEntry(
      id: 'creature.seen',
      name: 'Marcar espécie vista',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['seen'],
      touchesSave: true,
      keywords: const ['bestiário', 'retrato', 'vista'],
      info: 'Marca a espécie como vista no save aberto (o retrato no Bestiário). Com o mapa aberto.',
      load: env.capture.ensure,
      params: [
        DebugParam('species', 'espécie',
            optionsOf: () => [for (final s in env.capture.data?.species ?? const <EcoSpecies>[]) DebugOption(s.id, s.name)], fallback: 'soot.eco'),
      ],
      run: (c) {
        final live = liveGameState();
        if (live == null || c['species'].isEmpty) throw const DebugError('abra o mapa e diga a espécie');
        live.markSeen(c['species']);
        live.changed();
        return '${c['species']} vista';
      },
    ),
    DebugEntry(
      id: 'creature.exit',
      name: 'Saída animada do Eco mais perto',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['exit'],
      keywords: const ['saída', 'fuga', 'sintonizado', 'animação'],
      info: 'Só no desenho: o Eco mais perto sai sintonizado ou fugindo. Com o mapa aberto.',
      params: const [DebugParam('mode', 'saída', options: [DebugOption('tuned', 'Sintonizado'), DebugOption('flee', 'Fuga')], fallback: 'tuned')],
      run: (c) => '${tools.exitNearestEco?.call(c['mode'] != 'flee') ?? (throw const DebugError('sem Eco à vista'))}',
    ),
    ...captureEntries(env.capture),
    ...ritualEntries(env),
    ...fusionEntries(env),
  ];
}

/// Volta o último "Criar criatura" das preferências para o formulário (o menu chama ao abrir).
void restoreCreatureForm(DebugRegistry r, Map<String, dynamic>? json) {
  if (json == null) return;
  r.byName('creature.create')?.form.addAll(creatureForm(DebugCreatureSpec.fromJson(json)));
}
