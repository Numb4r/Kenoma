/// Dados de conteúdo do jogo no mapa: épocas, espécies, itens, receitas e o balanceamento, lidos dos
/// JSONs de `assets/data/`. A sintonia usa [tuning].
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/epochs.dart';
import 'balance_version.dart';
import 'tuning_data.dart';

class Recipe {
  const Recipe({required this.id, required this.outId, required this.outQty, required this.inputs});

  final String id;
  final String outId;
  final int outQty;

  /// Ingredientes `item -> quantidade`. Ingredientes `any:...` (receitas de Essência) não entram aqui.
  final Map<String, int> inputs;
}

class GameData {
  GameData({
    required this.tuning,
    required this.schedule,
    required this.itemNames,
    required this.startInventory,
    required this.recipes,
  });

  static Future<GameData> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<Map<String, dynamic>> json(String name) async =>
        jsonDecode(await b.loadString('assets/data/$name.json')) as Map<String, dynamic>;
    final balanceBytes = (await b.load('assets/data/balance.json')).buffer.asUint8List();
    final balance = jsonDecode(utf8.decode(balanceBytes)) as Map<String, dynamic>;
    final items = await json('items');
    return GameData(
      tuning: TuningData.fromJson(
        balance: balance,
        balanceVersion: balanceVersionOf(balanceBytes),
        creatures: await json('creatures'),
        items: items,
      ),
      schedule: EpochSchedule.fromJson(await json('epochs')),
      itemNames: {for (final i in items['items'] as List<dynamic>) (i as Map<String, dynamic>)['id'] as String: i['name'] as String},
      startInventory: {for (final e in (balance['start_inventory'] as Map<String, dynamic>).entries) e.key: e.value as int},
      recipes: {
        for (final r in (await json('recipes'))['recipes'] as List<dynamic>)
          if (!((r as Map<String, dynamic>)['in'] as List<dynamic>).any((i) => ((i as List<dynamic>)[0] as String).startsWith('any:')))
            r['id'] as String: Recipe(
              id: r['id'] as String,
              outId: (r['out'] as List<dynamic>)[0] as String,
              outQty: (r['out'] as List<dynamic>)[1] as int,
              inputs: {for (final i in r['in'] as List<dynamic>) (i as List<dynamic>)[0] as String: i[1] as int},
            ),
      },
    );
  }

  final TuningData tuning;
  final EpochSchedule schedule;
  final Map<String, String> itemNames;
  final Map<String, int> startInventory;
  final Map<String, Recipe> recipes;

  String itemName(String id) => itemNames[id] ?? id;

  EcoSpecies? species(String id) {
    for (final s in tuning.species) {
      if (s.id == id) return s;
    }
    return null;
  }
}
