/// Épocas (epochs.json): pacote de região e tabelas de spawn de cada uma (docs/fase0-spec.md, seção 3).
library;

import 'features.dart';
import 'weather.dart';

class WeightedEntry {
  const WeightedEntry(this.id, this.weight);

  final String id;
  final int weight;
}

class RegionPackRef {
  const RegionPackRef({required this.file, required this.sha256});

  final String file;
  final String sha256;
}

class SpawnItemDef {
  const SpawnItemDef({
    required this.index,
    required this.kind,
    required this.chance,
    required this.table,
    required this.qtyMin,
    required this.qtyMax,
    this.levelDeltaMin,
    this.levelDeltaMax,
  });

  factory SpawnItemDef.fromJson(Map<String, dynamic> json) {
    final qty = (json['qty'] as List<dynamic>).cast<int>();
    final delta = (json['level_delta'] as List<dynamic>?)?.cast<int>();
    return SpawnItemDef(
      index: json['index'] as int,
      kind: json['kind'] as String,
      chance: {
        for (final e in (json['chance'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble(),
      },
      table: {
        for (final e in (json['table'] as Map<String, dynamic>).entries)
          e.key: [
            for (final pair in e.value as List<dynamic>)
              WeightedEntry((pair as List<dynamic>)[0] as String, pair[1] as int),
          ],
      },
      qtyMin: qty[0],
      qtyMax: qty[1],
      levelDeltaMin: delta?[0],
      levelDeltaMax: delta?[1],
    );
  }

  final int index;
  final String kind;

  /// Chance de existir, por chave de bioma de spawn.
  final Map<String, double> chance;

  /// Lista ponderada, por chave de bioma de spawn, na ordem do arquivo.
  final Map<String, List<WeightedEntry>> table;
  final int qtyMin;
  final int qtyMax;
  final int? levelDeltaMin;
  final int? levelDeltaMax;

  bool get hasLevelDelta => levelDeltaMin != null && levelDeltaMax != null;
}

/// O que a época 2 acrescenta aos Ecos (docs/GDD.md): comportamento, variante de bioma, Brilhante e o efeito do
/// clima nos spawns. Entra num fluxo de sorteios separado (`v2`) e só vale em épocas que o trazem: nas outras os
/// itens saem exatamente como antes.
class EcoV2 {
  const EcoV2({required this.behaviorWeights, required this.variantChance, required this.shinyChance, required this.weather});

  factory EcoV2.fromJson(Map<String, dynamic> j) => EcoV2(
        behaviorWeights: {for (final e in (j['behavior_weights'] as Map<String, dynamic>).entries) e.key: e.value as int},
        variantChance: (j['variant_chance'] as num).toDouble(),
        shinyChance: (j['shiny_chance'] as num).toDouble(),
        weather: WeatherModel.fromJson(j['weather'] as Map<String, dynamic>),
      );

  /// Peso de cada comportamento (`passive`, `skittish`, `aggressive`, `hidden`), na ordem de [EcoBehavior].
  final Map<String, int> behaviorWeights;
  final double variantChance;
  final double shinyChance;
  final WeatherModel weather;
}

/// Épocas com posições sobre o que dá para andar: Fagulhas e materiais são projetados no caminho mais próximo da célula
/// (geometria do pacote visual, fixada pelo SHA-256 da época) e os Ecos podem ficar até [ecoOffPathM] metros fora dele.
class Walkable {
  const Walkable({required this.ecoOffPathM});

  factory Walkable.fromJson(Map<String, dynamic> j) => Walkable(ecoOffPathM: (j['eco_off_path_m'] as num).toDouble());

  final double ecoOffPathM;
}

class Epoch {
  const Epoch({
    required this.id,
    required this.startsUtc,
    required this.validUntilUtc,
    required this.regionPacks,
    required this.items,
    this.visualPacks = const {},
    this.ecoV2,
    this.walkable,
    this.requiresFeature,
  });

  factory Epoch.fromJson(Map<String, dynamic> json) => Epoch(
        id: json['id'] as int,
        startsUtc: _parseUtcSeconds(json['starts_utc'] as String),
        validUntilUtc: _parseUtcSeconds(json['valid_until_utc'] as String),
        regionPacks: {
          for (final e in (json['region_packs'] as Map<String, dynamic>).entries)
            e.key: RegionPackRef(
              file: (e.value as Map<String, dynamic>)['file'] as String,
              sha256: e.value['sha256'] as String,
            ),
        },
        visualPacks: {
          for (final e in ((json['visual_packs'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: RegionPackRef(
              file: (e.value as Map<String, dynamic>)['file'] as String,
              sha256: e.value['sha256'] as String,
            ),
        },
        walkable: json['walkable'] == null ? null : Walkable.fromJson(json['walkable'] as Map<String, dynamic>),
        requiresFeature: json['requires_feature'] as String?,
        ecoV2: json['eco_v2'] == null ? null : EcoV2.fromJson(json['eco_v2'] as Map<String, dynamic>),
        items: [
          for (final i in (json['spawn'] as Map<String, dynamic>)['items'] as List<dynamic>)
            SpawnItemDef.fromJson(i as Map<String, dynamic>),
        ],
      );

  final int id;

  /// Segundos UTC desde a época Unix.
  final int startsUtc;
  final int validUntilUtc;
  final Map<String, RegionPackRef> regionPacks;

  /// Pacote visual de cada região (ruas, água e verde, só desenho). Campo separado do pacote lógico: pode
  /// ser trocado sem nova época, porque não muda o mundo.
  final Map<String, RegionPackRef> visualPacks;

  /// Os quatro itens fixos de uma célula, na ordem do índice.
  final List<SpawnItemDef> items;

  /// Posições sobre caminhos andáveis (a partir da época 2). `null` nas épocas 0 e 1.
  final Walkable? walkable;

  /// A época só existe em builds com esta funcionalidade ligada (`street_life`: a 0.13.1 sai sem ela e não conhece a época).
  final String? requiresFeature;

  /// Comportamento, variantes, Brilhante e clima dos Ecos. `null` nas épocas 0, 1 e 2.
  final EcoV2? ecoV2;
}

class EpochSchedule {
  EpochSchedule(List<Epoch> epochs) : epochs = List.unmodifiable(epochs) {
    assert(epochs.isNotEmpty, 'epochs.json sem épocas');
  }

  factory EpochSchedule.fromJson(Map<String, dynamic> json) => EpochSchedule([
        for (final e in json['epochs'] as List<dynamic>)
          if (_available((e as Map<String, dynamic>)['requires_feature'] as String?)) Epoch.fromJson(e),
      ]);

  static bool _available(String? feature) => feature == null || (feature == 'street_life' && streetLifeEnabled);

  final List<Epoch> epochs;

  /// Época de maior `starts_utc` que já passou. `null` se o relógio está antes da primeira.
  Epoch? current(int tUtc) {
    Epoch? best;
    for (final e in epochs) {
      if (e.startsUtc <= tUtc && (best == null || e.startsUtc > best.startsUtc)) best = e;
    }
    return best;
  }

  /// Mundo desatualizado: o relógio está antes da primeira época ou chegou ao `valid_until_utc`
  /// da última época conhecida. O app mostra o aviso e continua gerando.
  bool isStale(int tUtc) =>
      tUtc < epochs.map((e) => e.startsUtc).reduce((a, b) => a < b ? a : b) ||
      tUtc >= epochs.map((e) => e.validUntilUtc).reduce((a, b) => a > b ? a : b);

  /// Época que o app usa no instante `tUtc`: a vigente ou, antes da primeira, a primeira.
  EpochSelection select(int tUtc) {
    final epoch = current(tUtc) ?? epochs.reduce((a, b) => a.startsUtc <= b.startsUtc ? a : b);
    return EpochSelection(epoch: epoch, stale: isStale(tUtc));
  }
}

class EpochSelection {
  const EpochSelection({required this.epoch, required this.stale});

  final Epoch epoch;

  /// Mostrar o aviso de mundo desatualizado.
  final bool stale;
}

int _parseUtcSeconds(String iso) {
  final t = DateTime.parse(iso);
  assert(t.isUtc, 'datas de época terminam em Z: $iso');
  return t.millisecondsSinceEpoch ~/ 1000;
}
