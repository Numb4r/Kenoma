/// Dados de conteúdo do jogo no mapa: épocas, espécies, itens, receitas e o balanceamento, lidos dos
/// JSONs de `assets/data/`. A sintonia usa [tuning].
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/epochs.dart';
import '../player/progress_balance.dart';
import '../story/forum_data.dart';
import '../story/mentor_script.dart';
import 'balance_version.dart';
import 'tuning_data.dart';

class Recipe {
  const Recipe({required this.id, required this.outId, required this.outQty, required this.inputs, this.anyEssence = 0});

  final String id;
  final String outId;
  final int outQty;

  /// Ingredientes `item -> quantidade`, sem a Essência de qualquer tipo.
  final Map<String, int> inputs;

  /// Quantas Essências de qualquer tipo a receita pede (`any:essence`), misturadas ou não.
  final int anyEssence;
}

class GameData {
  GameData({
    required this.tuning,
    required this.schedule,
    required this.itemNames,
    required this.startInventory,
    required this.recipes,
    required this.progress,
    required this.mentor,
    required this.forum,
  });

  static Future<GameData> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<Map<String, dynamic>> json(String name) async =>
        jsonDecode(await b.loadString('assets/data/$name.json')) as Map<String, dynamic>;
    final balanceBytes = (await b.load('assets/data/balance.json')).buffer.asUint8List();
    return GameData.fromJson(
      balance: jsonDecode(utf8.decode(balanceBytes)) as Map<String, dynamic>,
      balanceVersion: balanceVersionOf(balanceBytes),
      creatures: await json('creatures'),
      items: await json('items'),
      epochs: await json('epochs'),
      recipes: await json('recipes'),
      mentor: await json('mentor'),
      forum: await json('forum'),
    );
  }

  factory GameData.fromJson({
    required Map<String, dynamic> balance,
    required String balanceVersion,
    required Map<String, dynamic> creatures,
    required Map<String, dynamic> items,
    required Map<String, dynamic> epochs,
    required Map<String, dynamic> recipes,
    required Map<String, dynamic> mentor,
    required Map<String, dynamic> forum,
  }) =>
      GameData(
        mentor: MentorScript.fromJson(mentor),
        forum: ForumData.fromJson(forum),
        tuning: TuningData.fromJson(balance: balance, balanceVersion: balanceVersion, creatures: creatures, items: items),
        progress: ProgressBalance(balance),
        schedule: EpochSchedule.fromJson(epochs),
        itemNames: {for (final i in items['items'] as List<dynamic>) (i as Map<String, dynamic>)['id'] as String: i['name'] as String},
        startInventory: {for (final e in (balance['start_inventory'] as Map<String, dynamic>).entries) e.key: e.value as int},
        recipes: {
          for (final r in recipes['recipes'] as List<dynamic>)
            (r as Map<String, dynamic>)['id'] as String: Recipe(
              id: r['id'] as String,
              outId: (r['out'] as List<dynamic>)[0] as String,
              outQty: (r['out'] as List<dynamic>)[1] as int,
              inputs: {
                for (final i in r['in'] as List<dynamic>)
                  if (!((i as List<dynamic>)[0] as String).startsWith('any:')) i[0] as String: i[1] as int,
              },
              anyEssence: [
                for (final i in r['in'] as List<dynamic>)
                  if (((i as List<dynamic>)[0] as String) == 'any:essence') i[1] as int,
              ].fold(0, (a, b) => a + b),
            ),
        },
      );

  final TuningData tuning;
  final EpochSchedule schedule;
  final Map<String, String> itemNames;
  final Map<String, int> startInventory;
  final Map<String, Recipe> recipes;

  /// XP, descanso, marcação e destilação do `balance.json`.
  final ProgressBalance progress;

  /// O roteiro do mentor (chat) e os pedidos do fórum Limen.
  final MentorScript mentor;
  final ForumData forum;

  String itemName(String id) => itemNames[id] ?? id;

  EcoSpecies? species(String id) {
    for (final s in tuning.species) {
      if (s.id == id) return s;
    }
    return null;
  }
}
