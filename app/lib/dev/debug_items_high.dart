/// Aba Criaturas, as etapas altas (0.27.0): forçar a Entidade Maior solta de uma família, forçar o rumor dela no Fórum,
/// forçar a aparição do Arquétipo e conceder as peças da fusão da Entidade (essa mexe no save).
library;

import '../crafting/fusion.dart' show essenceOfFamily;
import '../data/game_data.dart';
import '../data/tuning_data.dart' show EcoSpecies;
import 'debug_env.dart';
import 'debug_registry.dart';

/// As famílias com Entidade Maior nos dados da sintonia (carregados ao abrir o menu).
List<DebugOption> _families(DebugEnv env) => [
      for (final s in env.capture.data?.species ?? const <EcoSpecies>[])
        if (s.id.endsWith('.major')) DebugOption(s.id.split('.').first, s.id.split('.').first),
    ];

/// Soma ao save as peças da fusão da Entidade da [family]: 3 Espíritos no nível 20, a criatura de ritual no 15 e a Essência
/// do tipo que a fusão gasta.
Future<void> grantMajorKit(DebugEnv env, String family) async {
  final data = await GameData.load();
  final essence = essenceOfFamily(data, family);
  if (essence == null) throw DebugError('família sem Essência: $family');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  await env.editSave((json) {
    final collection = [...?(json['collection'] as List<dynamic>?)];
    for (final (i, (sp, lv)) in [('$family.spirit', 20), ('$family.spirit', 20), ('$family.spirit', 20), ('$family.ritual', 15)].indexed) {
      collection.add({'uid': 'dbg-major-$family-${DateTime.now().microsecondsSinceEpoch}-$i', 'species': sp, 'level': lv, 'xp': 0, 'captured_utc': now});
    }
    final inventory = {...?(json['inventory'] as Map<String, dynamic>?)};
    inventory[essence] = ((inventory[essence] as int?) ?? 0) + data.progress.conjurer.majorEssenceCost;
    return {...json, 'collection': collection, 'inventory': inventory};
  });
}

List<DebugEntry> highTierEntries(DebugEnv env) {
  final tools = env.tools;
  DebugParam family() => DebugParam('family', 'família', optionsOf: () => _families(env), fallback: 'soot');
  DebugEntry force(String id, String name, String info, String Function(String family)? Function() hook, List<String> keywords) => DebugEntry(
        id: 'creature.$id',
        name: name,
        tab: DebugTab.creatures,
        kind: DebugKind.action,
        keywords: keywords,
        info: info,
        load: env.capture.ensure,
        params: [family()],
        run: (c) => hook()?.call(c['family']) ?? (throw const DebugError('abra o mapa antes')),
      );
  return [
    force('major_here', 'Forçar a Entidade Maior solta', 'A Entidade da família aparece a uns 15 m ao norte, agora, pela janela inteira. Só se prende por ritual (a receita da Entidade). Com o mapa aberto.',
        () => tools.forceMajorHere, const ['entidade', 'maior', 'solta', 'ritual']),
    force('major_rumor', 'Forçar o rumor da Entidade', 'O rumor de uma Entidade da família que vai aparecer aqui perto daqui a algumas horas entra no Fórum agora. Com o mapa aberto.',
        () => tools.forceRumorHere, const ['entidade', 'rumor', 'fórum', 'bairro']),
    force('archetype_here', 'Forçar a aparição do Arquétipo', 'O Arquétipo da família aparece a uns 25 m, como no auge do evento dela: alguns segundos e some. Tocar marca visto. Com o mapa aberto.',
        () => tools.forceArchetypeHere, const ['arquétipo', 'evento', 'auge', 'visto']),
    DebugEntry(
      id: 'creature.major_kit',
      name: 'Conceder as peças da fusão da Entidade',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      touchesSave: true,
      keywords: const ['entidade', 'fusão', 'espírito', 'oferenda', 'conceder', 'dar'],
      info: 'Três Espíritos da família no nível 20, a criatura de ritual dela no 15 e a Essência do tipo que a fusão gasta. Entra no seu save como se fosse de verdade. Vale na próxima vez que o mapa abrir.',
      load: env.capture.ensure,
      params: [family()],
      run: (c) async {
        await grantMajorKit(env, c['family']);
        return 'Peças da Entidade de ${c['family']} no save';
      },
    ),
  ];
}
