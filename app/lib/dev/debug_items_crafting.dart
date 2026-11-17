/// Itens de debug do crafting da fase 1 (0.24.0): um kit com materiais nas três qualidades, recipientes, todas as páginas
/// e todas as receitas de experimentar conhecidas, para testar a Bolsa, a Bancada e os coletores. Escreve no save (como o
/// nível forçado), então vale na próxima vez que o mapa abrir.
library;

import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

/// Soma ao save o kit: brutos comuns, bons e perfeitos, Pós e Essências, 3 de cada recipiente, 2 de cada componente, um
/// de cada equipável e um recipiente cheio de cada condição, e marca as páginas e as receitas de experimentar como conhecidas.
Future<void> grantCraftingKit(DebugEnv env) async {
  final store = await env.openSave();
  final json = {...?await store.read()};
  final data = await GameData.load();
  final inv = {...?(json['inventory'] as Map<String, dynamic>?)};
  void add(String key, int n) => inv[key] = ((inv[key] as int?) ?? 0) + n;
  for (final id in ['item.chalk', 'item.herbs', 'item.pure_water', 'item.ectoplasm', 'item.scrap']) {
    add(id, 12);
    add('$id@good', 4);
    add('$id@perfect', 2);
  }
  for (final i in data.craft.items.values) {
    if (i.kind == 'essence_dust' || i.kind == 'essence' || i.kind == 'essence_trait') add(i.id, 6);
    if (i.kind == 'vessel') add(i.id, 3);
    if (i.kind == 'component') add(i.id, 2);
    if (const {'bag', 'belt', 'grimoire', 'amulet', 'jewel'}.contains(i.kind)) add(i.id, 1); // um de cada equipável
  }
  final craft = {...?(json['crafting'] as Map<String, dynamic>?)};
  // Recipientes cheios guardados na bolsa: uma condição de cada (luz de cada fase, água de chuva boa, neve, fumaça).
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var uid = (craft['next_uid'] as int?) ?? 1;
  final vessels = [...?(craft['vessels'] as List<dynamic>?)];
  for (final i in data.craft.items.values.where((i) => i.kind == 'condition')) {
    final kind = i.id.startsWith('item.moonlight') ? 'item.vessel.dark' : (i.id == 'item.rift_smoke' ? 'item.vessel.candle' : 'item.vessel.glass');
    vessels.add({'uid': uid++, 'kind': kind, 'place': 'bag', 'content': i.id, 'q': 'good', 'filled': now});
  }
  craft['vessels'] = vessels;
  craft['next_uid'] = uid;
  craft['pages'] = {...((craft['pages'] as List<dynamic>?) ?? const []), ...data.craft.pages.keys}.toList();
  craft['known'] = {...((craft['known'] as List<dynamic>?) ?? const []), for (final r in data.recipes.values) if (r.discovery.name == 'experiment') r.id}.toList();
  json['inventory'] = inv;
  json['crafting'] = craft;
  await store.write(json);
}

List<DebugItem> craftingItems(DebugEnv env) => [
      DebugItem(
        id: 'player.crafting_kit',
        title: 'Kit de crafting (fase 1)',
        section: DebugSection.player,
        keywords: const ['crafting', 'bolsa', 'bancada', 'coletor', 'garrafa', 'receita', 'página', 'grimório', 'qualidade', 'kit', 'dar'],
        builder: (context) => DebugColumn([
          const DebugNote('ATENÇÃO: entra no seu save como se fosse de verdade. Vale na próxima vez que o mapa abrir.', color: KCores.brasaLaranja),
          DebugButton(
            label: 'Materiais nas 3 qualidades, recipientes, páginas e receitas',
            onTap: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                await grantCraftingKit(env);
                messenger?.showSnackBar(const SnackBar(content: Text('Kit de crafting no save')));
              } catch (_) {
                messenger?.showSnackBar(const SnackBar(content: Text('Sem save para escrever')));
              }
            },
          ),
        ]),
      ),
    ];
