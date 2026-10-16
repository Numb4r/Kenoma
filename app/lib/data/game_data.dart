/// Dados de conteúdo do jogo no mapa: épocas, espécies, itens, receitas e o balanceamento, lidos dos
/// JSONs de `assets/data/`. A sintonia usa [tuning].
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/epochs.dart';
import '../net/signed_feed.dart';
import '../player/progress_balance.dart';
import '../story/forum_data.dart';
import '../core/weather.dart';
import '../world/steps.dart';
import '../world/street_life_balance.dart';
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

/// Uma variante (de bioma ou Brilhante): o nome, o traço passivo (só dado por enquanto) e a cor da paleta.
class VariantInfo {
  const VariantInfo({required this.name, required this.trait, required this.tint});

  final String name;
  final String trait;

  /// A cor (0xAARRGGBB) que troca a paleta do sprite: sem arte nova.
  final int tint;
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
    required this.street,
    required this.steps,
    this.variants = const {},
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
      epochs: await loadEpochsJson(bundle: b),
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
        street: StreetLifeBalance(balance),
        steps: StepsBalance.fromJson(balance),
        variants: {
          for (final e in ((creatures['variants'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: VariantInfo(
              name: (e.value as Map<String, dynamic>)['name'] as String,
              trait: e.value['trait'] as String,
              tint: 0xFF000000 | int.parse((e.value['tint'] as String).substring(1), radix: 16),
            ),
        },
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

  /// Comportamentos, Radar, névoa e Familiar do `balance.json`.
  final StreetLifeBalance street;

  /// Passos por Fagulha do contador opcional (`balance.json`, bloco `steps`).
  final StepsBalance steps;

  /// As variantes: `urban`, `green`, `water`, `residential` e `shiny`.
  final Map<String, VariantInfo> variants;

  /// A variante de um Eco: a Brilhante vale mais que a de bioma. `null` se é comum.
  VariantInfo? variantInfo({String? biome, bool shiny = false}) => variants[shiny ? 'shiny' : biome];

  /// O modelo do clima da época mais nova que o traz (para o HUD e a chuva, mesmo antes de a época 2 começar).
  WeatherModel? get weatherModel {
    for (final e in schedule.epochs.reversed) {
      if (e.ecoV2 != null) return e.ecoV2!.weather;
    }
    return null;
  }

  String itemName(String id) => itemNames[id] ?? id;

  EcoSpecies? species(String id) {
    for (final s in tuning.species) {
      if (s.id == id) return s;
    }
    return null;
  }
}
