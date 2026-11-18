/// Itens de debug do crafting da fase 1 (0.24.0): um kit com materiais nas três qualidades, recipientes, todas as páginas
/// e todas as receitas de experimentar conhecidas, para testar a Bolsa, a Bancada e os coletores. Escreve no save (como o
/// nível forçado), então vale na próxima vez que o mapa abrir.
library;

import 'package:flutter/material.dart';

import '../crafting/bag.dart' show acceptableCount, slotsUsedBy;
import '../data/game_data.dart';
import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

/// Soma ao save o kit, sem passar do limite da bolsa (0.24.1): equipa a maior bolsa (se o espaço estiver livre) e põe, em
/// ordem, recipientes, equipáveis, um recipiente cheio de cada condição, componentes, brutos nas três qualidades, Pós e
/// Essências; o que não cabe fica de fora. Marca as páginas e as receitas de experimentar como conhecidas. Devolve quantos
/// itens ficaram de fora.
Future<int> grantCraftingKit(DebugEnv env) async {
  final store = await env.openSave();
  final json = {...?await store.read()};
  final data = await GameData.load();
  final book = data.craft;
  final inv = <String, int>{for (final e in ((json['inventory'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int};
  final craft = {...?(json['crafting'] as Map<String, dynamic>?)};
  final equipped = {...?(craft['equipped'] as Map<String, dynamic>?)};
  final bags = [for (final i in book.items.values) if (i.kind == 'bag') i]..sort((a, b) => (b.effects['bag_slots'] ?? 0).compareTo(a.effects['bag_slots'] ?? 0));
  if (equipped['bag'] == null && bags.isNotEmpty) equipped['bag'] = bags.first.id;
  craft['equipped'] = equipped;
  final cap = book.balance.baseSlots + (book.item(equipped['bag'] as String? ?? '')?.effects['bag_slots'] ?? 0).round();
  final vessels = [...?(craft['vessels'] as List<dynamic>?)];
  int stored() => vessels.where((v) => (v as Map)['place'] == 'bag').length;
  var refused = 0;
  void add(String key, int n) {
    final ok = acceptableCount(inventory: inv, vesselsInBag: stored(), stack: book.balance.stack, cap: cap, key: key, n: n);
    if (ok > 0) inv[key] = (inv[key] ?? 0) + ok;
    refused += n - ok;
  }

  final items = book.items.values;
  for (final i in items.where((i) => i.kind == 'vessel')) {
    add(i.id, 3);
  }
  for (final i in items.where((i) => const {'bag', 'belt', 'grimoire', 'amulet', 'jewel', 'vehicle_bike', 'vehicle_car'}.contains(i.kind) && i.id != equipped['bag'])) {
    add(i.id, 1);
  }
  // Um recipiente cheio de cada condição, guardado na bolsa (um espaço cada).
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var uid = (craft['next_uid'] as int?) ?? 1;
  for (final i in items.where((i) => i.kind == 'condition')) {
    if (slotsUsedBy(inv, stored(), book.balance.stack) >= cap) {
      refused++;
      continue;
    }
    final kind = i.id.startsWith('item.moonlight') ? 'item.vessel.dark' : (i.id == 'item.rift_smoke' ? 'item.vessel.candle' : 'item.vessel.glass');
    vessels.add({'uid': uid++, 'kind': kind, 'place': 'bag', 'content': i.id, 'q': 'good', 'filled': now});
  }
  for (final i in items.where((i) => i.kind == 'component')) {
    add(i.id, 2);
  }
  for (final id in ['item.scrap', 'item.chalk', 'item.herbs', 'item.pure_water', 'item.ectoplasm']) {
    add(id, 12);
    add('$id@good', 4);
    add('$id@perfect', 2);
  }
  for (final i in items.where((i) => i.kind == 'essence_dust' || i.kind == 'essence' || i.kind == 'essence_trait')) {
    add(i.id, 6);
  }
  craft['vessels'] = vessels;
  craft['next_uid'] = uid;
  craft['pages'] = {...((craft['pages'] as List<dynamic>?) ?? const []), ...book.pages.keys}.toList();
  craft['known'] = {...((craft['known'] as List<dynamic>?) ?? const []), for (final r in data.recipes.values) if (r.discovery.name == 'experiment') r.id}.toList();
  json['inventory'] = inv;
  json['crafting'] = craft;
  await store.write(json);
  return refused;
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
            label: 'Bolsa grande, recipientes, materiais, páginas e receitas (até encher)',
            onTap: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                final out = await grantCraftingKit(env);
                messenger?.showSnackBar(SnackBar(content: Text(out == 0 ? 'Kit de crafting no save' : 'Kit de crafting no save. Bolsa cheia: $out itens ficaram de fora')));
              } catch (_) {
                messenger?.showSnackBar(const SnackBar(content: Text('Sem save para escrever')));
              }
            },
          ),
        ]),
      ),
    ];
