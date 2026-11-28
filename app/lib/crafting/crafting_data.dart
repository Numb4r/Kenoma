/// Os dados do crafting da fase 1 (docs/GDD.md, "Regras da fase 1"): o que cada item é (degrau, aba da bolsa, efeitos,
/// validade), as condições das receitas, as páginas de grimório e as tabelas do `balance.json` (`crafting`). Dart puro.
library;

import 'quality.dart';

/// O degrau de um material (docs/GDD.md, "Degraus de material").
enum Tier {
  raw('Bruto'),
  refined('Refinado'),
  component('Componente'),
  piece('Peça');

  const Tier(this.label);

  final String label;
}

/// As abas da bolsa.
enum BagTab {
  materials('Materiais'),
  conditions('Condições'),
  use('Uso'),
  equip('Equipáveis'),
  quest('Missão');

  const BagTab(this.label);

  final String label;
}

/// As estações do ano, já invertidas para o hemisfério sul (docs/GDD.md, "Lua e estações do ano").
enum YearSeason {
  summer('verão'),
  autumn('outono'),
  winter('inverno'),
  spring('primavera');

  const YearSeason(this.label);

  final String label;

  /// "no verão", "na primavera".
  String get inLabel => this == spring ? 'na $label' : 'no $label';
}

/// Os grupos de fase que as receitas de lua e o frasco escuro usam.
enum MoonGroup {
  newMoon('new', 'lua nova'),
  waxing('waxing', 'crescente'),
  full('full', 'lua cheia'),
  waning('waning', 'minguante');

  const MoonGroup(this.key, this.label);

  final String key;
  final String label;

  static MoonGroup byKey(String k) => MoonGroup.values.firstWhere((g) => g.key == k);
}

/// Os efeitos que um equipável pode dar (`effects` em `items.json`). Só estes têm uso no código.
const kEffectKeys = ['bag_slots', 'belt_slots', 'planted_slots', 'seal_tolerance', 'tonic_time', 'fill_speed'];

class ItemDef {
  const ItemDef({
    required this.id,
    required this.name,
    required this.kind,
    this.desc = '',
    this.tier = Tier.raw,
    this.type,
    this.perishH,
    this.meltsTo,
    this.keepsCold = false,
    this.effects = const {},
    this.season,
    this.inSeasonMult = 1,
    this.feminine = false,
    this.perishVerb,
  });

  factory ItemDef.fromJson(Map<String, dynamic> j) {
    final kind = j['kind'] as String;
    return ItemDef(
      id: j['id'] as String,
      name: j['name'] as String,
      kind: kind,
      desc: (j['desc'] as String?) ?? '',
      tier: j['tier'] == null ? _defaultTier(kind) : Tier.values.byName(j['tier'] as String),
      type: j['type'] as String?,
      perishH: (j['perish_h'] as num?)?.toDouble(),
      meltsTo: j['melts_to'] as String?,
      keepsCold: (j['keeps_cold'] as bool?) ?? false,
      effects: {for (final e in ((j['effects'] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as num).toDouble()},
      season: j['season'] == null ? null : YearSeason.values.byName(j['season'] as String),
      inSeasonMult: ((j['in_season_mult'] as num?) ?? 1).toDouble(),
      feminine: j['gender'] == 'f',
      perishVerb: j['perish_verb'] as String?,
    );
  }

  static Tier _defaultTier(String kind) => switch (kind) {
        'condition' || 'refined' => Tier.refined,
        'component' => Tier.component,
        'material' || 'essence' || 'essence_dust' || 'essence_trait' || 'essence_prismatic' || 'essence_crimson' => Tier.raw,
        _ => Tier.piece,
      };

  final String id;
  final String name;
  final String kind;
  final String desc;
  final Tier tier;
  final String? type;

  /// Horas até o conteúdo engarrafado estragar (ou derreter, com [meltsTo]); `null` não estraga.
  final double? perishH;
  final String? meltsTo;

  /// O recipiente que guarda neve sem derreter (o frasco térmico).
  final bool keepsCold;
  final Map<String, double> effects;

  /// O amuleto de estação: a linha só se fabrica nela, e ele vale [inSeasonMult] vezes nela.
  final YearSeason? season;
  final double inSeasonMult;

  /// O nome é feminino (`gender: f`): a interface concorda ("garrafa cheia", "frasco cheio").
  final bool feminine;

  /// O verbo da validade (`derrete`, `apaga`, `estraga`); sem ele, `estraga`.
  final String? perishVerb;

  /// [m] ou [f] conforme o gênero do nome.
  String agree(String m, String f) => feminine ? f : m;

  BagTab get tab => switch (kind) {
        'vessel' || 'condition' => BagTab.conditions,
        'seal' || 'tonic' || 'tool' || 'lure' || 'furniture' => BagTab.use,
        'bag' || 'belt' || 'grimoire' || 'amulet' || 'jewel' || 'gadget' || 'vehicle_bike' || 'vehicle_car' => BagTab.equip,
        'quest' => BagTab.quest,
        _ => BagTab.materials,
      };

  bool get equipable => tab == BagTab.equip;
}

/// O que uma receita pede do momento e do lugar (`needs` em `recipes.json`). Todo campo vazio não pede nada.
class Needs {
  const Needs({this.night = false, this.daySun = false, this.waterM, this.biomes = const [], this.moon = const [], this.season, this.climates = const []});

  factory Needs.fromJson(Map<String, dynamic>? j) => j == null
      ? const Needs()
      : Needs(
          night: (j['night'] as bool?) ?? false,
          daySun: (j['day_sun'] as bool?) ?? false,
          waterM: (j['water_m'] as num?)?.toDouble(),
          biomes: [...((j['biomes'] as List<dynamic>?) ?? const []).cast<String>()],
          moon: [for (final m in ((j['moon'] as List<dynamic>?) ?? const []).cast<String>()) MoonGroup.byKey(m)],
          season: j['season'] == null ? null : YearSeason.values.byName(j['season'] as String),
          climates: [...((j['climates'] as List<dynamic>?) ?? const []).cast<String>()],
        );

  /// Não pede nada do momento nem do lugar.
  bool get isNone => !night && !daySun && waterM == null && biomes.isEmpty && moon.isEmpty && season == null && climates.isEmpty;

  final bool night;

  /// De dia com sol forte (o sol alto e sem nuvem).
  final bool daySun;

  /// Água (rio, lago, poça do mapa) a até tantos metros.
  final double? waterM;

  /// Chaves de bioma (`green`, `water`, `sacred`...): basta uma.
  final List<String> biomes;
  final List<MoonGroup> moon;
  final YearSeason? season;

  /// Climas (ids de `clima.json`): basta um.
  final List<String> climates;

  bool get none => !night && !daySun && waterM == null && biomes.isEmpty && moon.isEmpty && season == null && climates.isEmpty;
}

/// Como a receita entra no grimório.
enum Discovery { start, experiment, page }

class GrimoirePage {
  const GrimoirePage({required this.id, required this.name, this.desc = ''});

  final String id;
  final String name;
  final String desc;
}

/// Uma regra de coletor (`crafting.collectors.rules`): que recipientes, com que condição, enchem de quê.
class CollectorRule {
  const CollectorRule({
    required this.id,
    required this.vessels,
    required this.out,
    this.climates = const [],
    this.events = const [],
    this.night = false,
    this.quality = Quality.common,
    required this.carryS,
    required this.plantedS,
  });

  factory CollectorRule.fromJson(Map<String, dynamic> j) => CollectorRule(
        id: j['id'] as String,
        vessels: [...(j['vessels'] as List<dynamic>).cast<String>()],
        out: j['out'] as String,
        climates: [...((j['climates'] as List<dynamic>?) ?? const []).cast<String>()],
        events: [...((j['events'] as List<dynamic>?) ?? const []).cast<String>()],
        night: (j['night'] as bool?) ?? false,
        quality: Quality.byName(j['quality'] as String?),
        carryS: (j['carry_s'] as num).toDouble(),
        plantedS: (j['planted_s'] as num).toDouble(),
      );

  final String id;
  final List<String> vessels;

  /// O conteúdo; `{moon}` vira o grupo de fase (`item.moonlight.{moon}`).
  final String out;
  final List<String> climates;

  /// Eventos do calendário que também valem (a Noite das Fendas para o pote de vela).
  final List<String> events;
  final bool night;
  final Quality quality;

  /// Segundos de condição para encher no cinto e plantado.
  final double carryS;
  final double plantedS;
}

/// O que sobe a qualidade de um bruto: o lugar real (bioma) e a fase da lua certa, um nível cada.
class RawQuality {
  const RawQuality({this.biomes = const [], this.moon = const []});

  factory RawQuality.fromJson(Map<String, dynamic> j) => RawQuality(
        biomes: [...((j['biomes'] as List<dynamic>?) ?? const []).cast<String>()],
        moon: [for (final m in ((j['moon'] as List<dynamic>?) ?? const []).cast<String>()) MoonGroup.byKey(m)],
      );

  final List<String> biomes;
  final List<MoonGroup> moon;
}

/// As tabelas do `balance.json` (`crafting`).
class CraftingBalance {
  const CraftingBalance({
    this.baseSlots = 40,
    this.stack = 99,
    this.discardPerDust = 5,
    this.unlockLevels = const {},
    this.benchLevel = 5,
    this.beltSlots = 3,
    this.plantedSlots = 3,
    this.plantedGapM = 100,
    this.rules = const [],
    this.rawQuality = const {},
    this.sealTolerance = const [1, 1, 1],
    this.duration = const [1, 1, 1],
    this.waterNearM = 150,
    this.nightSunDeg = -6,
    this.strongSunDeg = 35,
    this.experimentSlots = 3,
  });

  factory CraftingBalance.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const CraftingBalance();
    final bag = (j['bag'] as Map<String, dynamic>?) ?? const {};
    final col = (j['collectors'] as Map<String, dynamic>?) ?? const {};
    final q = (j['quality'] as Map<String, dynamic>?) ?? const {};
    final eff = (q['effects'] as Map<String, dynamic>?) ?? const {};
    final cond = (j['conditions'] as Map<String, dynamic>?) ?? const {};
    List<double> three(Object? l) => l == null ? const [1, 1, 1] : [for (final x in l as List<dynamic>) (x as num).toDouble()];
    return CraftingBalance(
      baseSlots: (bag['base_slots'] as int?) ?? 40,
      stack: (bag['stack'] as int?) ?? 99,
      discardPerDust: (bag['discard_per_dust'] as int?) ?? 5,
      unlockLevels: {for (final e in ((j['unlock_levels'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      benchLevel: (j['bench_level'] as int?) ?? 5,
      beltSlots: (col['belt_slots'] as int?) ?? 3,
      plantedSlots: (col['planted_slots'] as int?) ?? 3,
      plantedGapM: ((col['planted_gap_m'] as num?) ?? 100).toDouble(),
      rules: [for (final r in (col['rules'] as List<dynamic>?) ?? const []) CollectorRule.fromJson(r as Map<String, dynamic>)],
      rawQuality: {for (final e in ((q['raw'] as Map<String, dynamic>?) ?? const {}).entries) e.key: RawQuality.fromJson(e.value as Map<String, dynamic>)},
      sealTolerance: three(eff['seal_tolerance']),
      duration: three(eff['duration']),
      waterNearM: ((cond['water_m'] as num?) ?? 150).toDouble(),
      nightSunDeg: ((cond['night_sun_deg'] as num?) ?? -6).toDouble(),
      strongSunDeg: ((cond['strong_sun_deg'] as num?) ?? 35).toDouble(),
      experimentSlots: (j['experiment_slots'] as int?) ?? 3,
    );
  }

  final int baseSlots;
  final int stack;
  final int discardPerDust;

  /// Nível que libera cada receita (as bolsas maiores).
  final Map<String, int> unlockLevels;
  final int benchLevel;
  final int beltSlots;
  final int plantedSlots;
  final double plantedGapM;
  final List<CollectorRule> rules;
  final Map<String, RawQuality> rawQuality;

  /// Multiplicador por qualidade (comum, bom, perfeito): a tolerância do selo e a duração dos itens de uso.
  final List<double> sealTolerance;
  final List<double> duration;

  /// "Perto de água" quando a receita não diz a distância.
  final double waterNearM;
  final double nightSunDeg;
  final double strongSunDeg;
  final int experimentSlots;
}

/// O livro do crafting: itens, páginas e balanço.
class CraftingBook {
  const CraftingBook({this.items = const {}, this.pages = const {}, this.balance = const CraftingBalance()});

  factory CraftingBook.fromJson({required Map<String, dynamic> items, required Map<String, dynamic> recipes, Map<String, dynamic>? balance}) => CraftingBook(
        items: {for (final i in items['items'] as List<dynamic>) (i as Map<String, dynamic>)['id'] as String: ItemDef.fromJson(i)},
        pages: {
          for (final p in (recipes['pages'] as List<dynamic>?) ?? const [])
            (p as Map<String, dynamic>)['id'] as String: GrimoirePage(id: p['id'] as String, name: p['name'] as String, desc: (p['desc'] as String?) ?? ''),
        },
        balance: CraftingBalance.fromJson(balance?['crafting'] as Map<String, dynamic>?),
      );

  final Map<String, ItemDef> items;
  final Map<String, GrimoirePage> pages;
  final CraftingBalance balance;

  /// A definição do item de uma chave de pilha (ou de um id puro).
  ItemDef? item(String key) => items[parseStack(key).id];
}
