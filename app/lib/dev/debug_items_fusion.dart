/// Itens de debug da fusão: conceder Ecos e Essência para testar a fusão. Escreve no save (como o nível forçado), então
/// vale na próxima vez que o mapa abrir. Para forçar um Espírito no próximo spawn, ver `spawn.spirit`.
library;

import 'debug_env.dart';
import 'debug_registry.dart';

/// Família -> tipo da Essência dela (só para o debug; o jogo lê isso de `creatures.json`).
const Map<String, String> _essenceOf = {'soot': 'fire', 'frond': 'plant', 'rill': 'water'};

/// Soma ao save [ecos] Ecos da [family] (nível [level]) e [essence] unidades da Essência dela.
Future<void> grantFusionKit(DebugEnv env, {required String family, int ecos = 5, int level = 8, int essence = 5}) async {
  final store = await env.openSave();
  final json = {...?await store.read()};
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final collection = [...?(json['collection'] as List<dynamic>?)];
  for (var i = 0; i < ecos; i++) {
    collection.add({'uid': 'dbg-$family-${DateTime.now().microsecondsSinceEpoch}-$i', 'species': '$family.eco', 'level': level, 'xp': 0, 'captured_utc': now});
  }
  final inventory = {...?(json['inventory'] as Map<String, dynamic>?)};
  final key = 'item.essence.${_essenceOf[family]}';
  inventory[key] = ((inventory[key] as int?) ?? 0) + essence;
  json['collection'] = collection;
  json['inventory'] = inventory;
  await store.write(json);
}

List<DebugEntry> fusionEntries(DebugEnv env) => [
      DebugEntry(
        id: 'creature.fusion_grant',
        name: 'Conceder Ecos e Essência (fusão)',
        tab: DebugTab.creatures,
        kind: DebugKind.action,
        aliases: const ['player.fusion_grant'],
        touchesSave: true,
        keywords: const ['fusão', 'espírito', 'eco', 'essência', 'conceder', 'dar'],
        info: '5 Ecos da família no nível 8 e 5 unidades da Essência dela. Entra no seu save como se fosse de verdade. Vale na próxima vez que o mapa abrir.',
        params: [DebugParam('family', 'família', options: [for (final f in _essenceOf.keys) DebugOption(f, f)], fallback: 'soot')],
        run: (c) async {
          env.requireMapClosed();
          await grantFusionKit(env, family: c['family']);
          return '5 Ecos ${c['family']} NV 8 e 5 Essência no save';
        },
      ),
    ];
