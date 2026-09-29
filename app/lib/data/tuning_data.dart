/// Dados de conteúdo da sintonia, lidos dos JSONs em `assets/data/`.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../capture/eco_type.dart';
import '../capture/seal.dart';
import '../capture/tuning_balance.dart';
import 'balance_version.dart';

class EcoSpecies {
  const EcoSpecies({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final EcoType type;
}

class TuningData {
  const TuningData({
    required this.balance,
    required this.balanceVersion,
    required this.species,
    required this.seals,
    required this.tonics,
  });

  factory TuningData.fromJson({
    required Map<String, dynamic> balance,
    required Map<String, dynamic> creatures,
    required Map<String, dynamic> items,
    required String balanceVersion,
  }) {
    final parsed = parseTuningItems(items);
    return TuningData(
      balance: TuningBalance(balance),
      balanceVersion: balanceVersion,
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
    // O balance.json é lido como bytes: a versão é o hash do arquivo, não de uma releitura dele.
    final balanceBytes = (await rootBundle.load('assets/data/balance.json')).buffer.asUint8List();
    return TuningData.fromJson(
      balance: jsonDecode(utf8.decode(balanceBytes)) as Map<String, dynamic>,
      balanceVersion: balanceVersionOf(balanceBytes),
      creatures: await json('creatures'),
      items: await json('items'),
    );
  }

  final TuningBalance balance;

  /// Versão do balanceamento carregado (8 caracteres do SHA-256 do `balance.json`).
  final String balanceVersion;
  final List<EcoSpecies> species;
  final List<Seal> seals;
  final List<Tonic> tonics;
}
