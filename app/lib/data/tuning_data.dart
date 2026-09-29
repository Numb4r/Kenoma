/// Dados de conteúdo da sintonia, lidos dos JSONs em `assets/data/`.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../capture/eco_type.dart';
import '../capture/seal.dart';
import '../capture/tuning_balance.dart';

class EcoSpecies {
  const EcoSpecies({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final EcoType type;
}

class TuningData {
  const TuningData({required this.balance, required this.species, required this.seals, required this.tonics});

  factory TuningData.fromJson({
    required Map<String, dynamic> balance,
    required Map<String, dynamic> creatures,
    required Map<String, dynamic> items,
  }) {
    final parsed = parseTuningItems(items);
    return TuningData(
      balance: TuningBalance(balance),
      species: [
        for (final s in creatures['species'] as List<dynamic>)
          if ((s as Map<String, dynamic>)['tier'] == 'eco')
            EcoSpecies(id: s['id'] as String, name: s['name'] as String, type: EcoType.parse(s['type'] as String)),
      ],
      seals: parsed.seals,
      tonics: parsed.tonics,
    );
  }

  static Future<TuningData> load() async {
    Future<Map<String, dynamic>> json(String name) async =>
        jsonDecode(await rootBundle.loadString('assets/data/$name.json')) as Map<String, dynamic>;
    return TuningData.fromJson(
      balance: await json('balance'),
      creatures: await json('creatures'),
      items: await json('items'),
    );
  }

  final TuningBalance balance;
  final List<EcoSpecies> species;
  final List<Seal> seals;
  final List<Tonic> tonics;
}
