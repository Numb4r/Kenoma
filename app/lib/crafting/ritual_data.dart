/// Os dados do ritual básico (GDD, "Ritual"): as receitas de `rituals.json`, a condição do mundo e o balanceamento
/// (`balance.json`, bloco `ritual`). Dart puro. A lógica de tentar e selar está em `ritual.dart`.
library;

import '../core/astro.dart' show MoonPhase;
import '../core/weather.dart' show Weather;

/// Um espaço de material: o item e a quantidade exata.
class RitualSlot {
  const RitualSlot(this.item, this.qty);

  final String item;
  final int qty;
}

enum ConditionKind { hour, biome, moon, weather }

/// A condição do mundo que a receita pede.
class RitualCondition {
  const RitualCondition({required this.kind, this.from = 0, this.to = 0, this.value = ''});

  factory RitualCondition.fromJson(Map<String, dynamic> j) {
    final kind = ConditionKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => throw FormatException('Condição de ritual desconhecida: ${j['kind']}'));
    return RitualCondition(kind: kind, from: (j['from'] as int?) ?? 0, to: (j['to'] as int?) ?? 0, value: (j['value'] as String?) ?? '');
  }

  final ConditionKind kind;

  /// Faixa de horas locais `[from, to)`; vale a virada da meia-noite se `from > to`.
  final int from;
  final int to;

  /// Chave do bioma (`green`), nome da fase (`fullMoon`) ou id do clima (`rain`).
  final String value;

  bool holds(WorldCondition w) => switch (kind) {
        ConditionKind.hour => from <= to ? (w.hour >= from && w.hour < to) : (w.hour >= from || w.hour < to),
        ConditionKind.biome => w.biome == value,
        ConditionKind.moon => w.moon.name == value,
        ConditionKind.weather => w.weather.id == value,
      };

  /// Uma condição do mundo que satisfaz esta (para o debug).
  WorldCondition satisfying(WorldCondition base) => switch (kind) {
        ConditionKind.hour => base.copyWith(hour: from),
        ConditionKind.biome => base.copyWith(biome: value),
        ConditionKind.moon => base.copyWith(moon: MoonPhase.values.firstWhere((p) => p.name == value)),
        ConditionKind.weather => base.copyWith(weather: Weather.parse(value)),
      };
}

/// O mundo no lugar e no instante do ritual: hora local (0 a 23), chave do bioma da célula, fase da lua e clima.
class WorldCondition {
  const WorldCondition({required this.hour, required this.biome, required this.moon, required this.weather});

  final int hour;
  final String biome;
  final MoonPhase moon;
  final Weather weather;

  WorldCondition copyWith({int? hour, String? biome, MoonPhase? moon, Weather? weather}) =>
      WorldCondition(hour: hour ?? this.hour, biome: biome ?? this.biome, moon: moon ?? this.moon, weather: weather ?? this.weather);
}

/// A hora local (0 a 23) do instante UTC. [offset] só existe para testar sem depender do fuso da máquina.
int localHourOf(int utcSeconds, {Duration? offset}) {
  final t = DateTime.fromMillisecondsSinceEpoch(utcSeconds * 1000, isUtc: true);
  return (offset != null ? t.add(offset) : t.toLocal()).hour;
}

/// A receita de uma espécie de ritual. Os espaços, na ordem fixa da pesquisa: a condição (0), os materiais (1 a n) e o
/// Círculo (n + 1). O Círculo pede uma criatura de tipo forte contra o da espécie e de nível [circleMinLevel] ou mais.
class RitualRecipe {
  const RitualRecipe({required this.speciesId, required this.condition, required this.materials, required this.circleMinLevel});

  factory RitualRecipe.fromJson(Map<String, dynamic> j) => RitualRecipe(
        speciesId: j['species'] as String,
        condition: RitualCondition.fromJson(j['condition'] as Map<String, dynamic>),
        materials: [for (final m in j['materials'] as List<dynamic>) RitualSlot((m as Map<String, dynamic>)['item'] as String, m['qty'] as int)],
        circleMinLevel: (j['circle'] as Map<String, dynamic>)['min_level'] as int,
      );

  final String speciesId;
  final RitualCondition condition;
  final List<RitualSlot> materials;
  final int circleMinLevel;

  /// Condição + materiais + Círculo.
  int get slotCount => materials.length + 2;
  int get circleIndex => materials.length + 1;
}

/// Os números do ritual no `balance.json` (bloco `ritual`).
class RitualBalance {
  RitualBalance(Map<String, dynamic> balance)
      : slotsPerSighting = _i(balance['ritual'], 'slots_per_sighting', 1),
        sealAnimS = _d(balance['ritual'], 'seal_anim_s', 2),
        materialMaxQty = _i(balance['ritual'], 'material_max_qty', 9);

  static int _i(Object? m, String k, int d) => (((m as Map<String, dynamic>?)?[k]) as num?)?.toInt() ?? d;
  static double _d(Object? m, String k, double d) => (((m as Map<String, dynamic>?)?[k]) as num?)?.toDouble() ?? d;

  /// Quantos espaços da receita cada avistamento (de um Eco diferente) da espécie revela.
  final int slotsPerSighting;

  /// Duração do sigilo se fechando, em segundos.
  final double sealAnimS;

  /// O máximo de unidades de um item que a tela deixa pôr num espaço.
  final int materialMaxQty;
}

/// As receitas por espécie, mais o balanceamento. Vazio se o `rituals.json` não foi carregado.
class RitualBook {
  const RitualBook({this.recipes = const {}, required this.balance});

  factory RitualBook.fromJson(Map<String, dynamic>? rituals, Map<String, dynamic> balance) => RitualBook(
        recipes: {
          for (final r in (rituals?['rituals'] as List<dynamic>?) ?? const []) (r as Map<String, dynamic>)['species'] as String: RitualRecipe.fromJson(r),
        },
        balance: RitualBalance(balance),
      );

  final Map<String, RitualRecipe> recipes;
  final RitualBalance balance;

  RitualRecipe? of(String speciesId) => recipes[speciesId];
}
