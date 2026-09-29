/// Épocas (epochs.json): pacote de região e tabelas de spawn de cada uma (docs/fase0-spec.md, seção 3).
library;

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

class Epoch {
  const Epoch({
    required this.id,
    required this.startsUtc,
    required this.validUntilUtc,
    required this.regionPacks,
    required this.items,
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

  /// Os quatro itens fixos de uma célula, na ordem do índice.
  final List<SpawnItemDef> items;
}

class EpochSchedule {
  EpochSchedule(List<Epoch> epochs) : epochs = List.unmodifiable(epochs) {
    assert(epochs.isNotEmpty, 'epochs.json sem épocas');
  }

  factory EpochSchedule.fromJson(Map<String, dynamic> json) => EpochSchedule([
        for (final e in json['epochs'] as List<dynamic>) Epoch.fromJson(e as Map<String, dynamic>),
      ]);

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
