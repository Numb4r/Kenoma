/// Itens de debug da fusão: conceder Ecos e Essência para testar a fusão. Escreve no save (como o nível forçado), então
/// vale na próxima vez que o mapa abrir. Para forçar um Espírito no próximo spawn, ver `spawn.spirit`.
library;

import 'package:flutter/material.dart';

import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

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

List<DebugItem> fusionItems(DebugEnv env) => [
      DebugItem(
        id: 'player.fusion_grant',
        title: 'Conceder Ecos e Essência (fusão)',
        section: DebugSection.player,
        keywords: const ['fusão', 'espírito', 'eco', 'essência', 'conceder', 'dar'],
        builder: (context) => DebugColumn([
          const DebugNote('ATENÇÃO: entra no seu save como se fosse de verdade. Vale na próxima vez que o mapa abrir.', color: KCores.brasaLaranja),
          DebugWrap([
            for (final f in _essenceOf.keys)
              DebugButton(
                label: '+5 Ecos $f + 5 Essência',
                onTap: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  try {
                    await grantFusionKit(env, family: f);
                    messenger?.showSnackBar(SnackBar(content: Text('5 Ecos $f NV 8 e 5 Essência no save')));
                  } catch (_) {
                    messenger?.showSnackBar(const SnackBar(content: Text('Sem save para escrever')));
                  }
                },
              ),
          ]),
        ]),
      ),
    ];
