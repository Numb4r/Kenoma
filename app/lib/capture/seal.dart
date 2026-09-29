/// Selo, tônico e a tolerância da sintonia (docs/fase0-spec.md, seção 5).
library;

import 'dart:math' as math;

import 'eco_type.dart';
import 'tuning_balance.dart';

class Seal {
  const Seal({required this.id, required this.name, required this.tolerance, this.bonusVsType, this.bonusMultiplier = 1});

  factory Seal.fromJson(Map<String, dynamic> j) => Seal(
        id: j['id'] as String,
        name: j['name'] as String,
        tolerance: (j['tolerance'] as num).toDouble(),
        bonusVsType: j['bonus_vs_type'] == null ? null : EcoType.parse(j['bonus_vs_type'] as String),
        bonusMultiplier: (j['bonus_multiplier'] as num?)?.toDouble() ?? 1,
      );

  final String id;
  final String name;

  /// Tolerância base. O selo de tipo vale como simples.
  final double tolerance;

  /// Tipo contra o qual o selo de tipo ganha o multiplicador (o tipo que ele vence).
  final EcoType? bonusVsType;
  final double bonusMultiplier;
}

class Tonic {
  const Tonic({required this.id, required this.name, required this.extraTimeS});

  factory Tonic.fromJson(Map<String, dynamic> j) =>
      Tonic(id: j['id'] as String, name: j['name'] as String, extraTimeS: (j['extra_time_s'] as num).toDouble());

  final String id;
  final String name;
  final double extraTimeS;
}

/// Selos e tônicos de `items.json`.
({List<Seal> seals, List<Tonic> tonics}) parseTuningItems(Map<String, dynamic> itemsJson) {
  final items = (itemsJson['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  return (
    seals: [for (final i in items) if (i['kind'] == 'seal') Seal.fromJson(i)],
    tonics: [for (final i in items) if (i['kind'] == 'tonic') Tonic.fromJson(i)],
  );
}

/// Tolerância da sintonia: valor do selo, ×1,4 se o selo de tipo vence o tipo do alvo, e
/// ×1,1 por criatura forte do Círculo (até o máximo do balanceamento).
double tuningTolerance({
  required Seal seal,
  required EcoType target,
  required TuningBalance balance,
  int circleStrong = 0,
}) {
  final typeBonus = seal.bonusVsType == target ? seal.bonusMultiplier : 1.0;
  final circle = math.pow(balance.circleStrongMultiplier, circleStrong.clamp(0, balance.circleStrongMax));
  return seal.tolerance * typeBonus * circle;
}
