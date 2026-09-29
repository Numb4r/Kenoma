/// Geração dos quatro itens de uma célula de spawn (docs/fase0-spec.md, seção 3).
library;

import 'epochs.dart';
import 'fnv.dart';
import 'pcg32.dart';

class SpawnItem {
  const SpawnItem({
    required this.index,
    required this.kind,
    required this.exists,
    required this.entryId,
    required this.quantity,
    required this.px,
    required this.py,
    required this.uid,
    this.levelDelta,
  });

  final int index;
  final String kind;
  final bool exists;

  /// Espécie, tipo da Fagulha ou material sorteado. Existindo ou não, o sorteio acontece.
  final String entryId;
  final int quantity;

  /// Delta de nível do Eco. `null` nos itens sem delta.
  final int? levelDelta;

  /// Posição dentro da célula, em `[0, 1)`.
  final double px;
  final double py;
  final int uid;
}

/// `h_i = FNV(seed_global, época, cell_x, cell_y, janela, i, SPWN)`: semente do PCG32 do item `i`.
int spawnHash(int seed, int epochId, int cellX, int cellY, int window, int index) =>
    fnv1a64([seed, epochId, cellX, cellY, window, index, saltSpwn]);

/// `uid_i = FNV(seed_global, época, cell_x, cell_y, janela, i, UID_)`.
int spawnUid(int seed, int epochId, int cellX, int cellY, int window, int index) =>
    fnv1a64([seed, epochId, cellX, cellY, window, index, saltUid]);

/// Gera os quatro itens da célula z20 `(cellX, cellY)` na janela dada.
/// `biomeKey` é a chave de spawn do bioma da célula (Vazio já entra como `residential`).
List<SpawnItem> generateCell({
  required int seed,
  required Epoch epoch,
  required int cellX,
  required int cellY,
  required int window,
  required String biomeKey,
}) =>
    [
      for (final def in epoch.items)
        _generateItem(seed, epoch.id, cellX, cellY, window, biomeKey, def),
    ];

SpawnItem _generateItem(
  int seed,
  int epochId,
  int cellX,
  int cellY,
  int window,
  String biomeKey,
  SpawnItemDef def,
) {
  final rng = Pcg32(spawnHash(seed, epochId, cellX, cellY, window, def.index), saltKenoma);
  final chance = def.chance[biomeKey] ?? (throw StateError('Item ${def.index} sem chance para $biomeKey'));
  final table = def.table[biomeKey] ?? (throw StateError('Item ${def.index} sem tabela para $biomeKey'));

  // Todo item consome sempre os mesmos sorteios, nesta ordem, existindo ou não.
  final exists = rng.nextFloat() < chance;
  var pick = rng.nextInt(table.fold(0, (sum, e) => sum + e.weight));
  var entry = table.last;
  for (final e in table) {
    if (pick < e.weight) {
      entry = e;
      break;
    }
    pick -= e.weight;
  }
  final deltaSpan = def.hasLevelDelta ? def.levelDeltaMax! - def.levelDeltaMin! + 1 : 1;
  final deltaDraw = rng.nextInt(deltaSpan);
  final quantity = def.qtyMin + rng.nextInt(def.qtyMax - def.qtyMin + 1);
  final px = rng.nextFloat();
  final py = rng.nextFloat();

  return SpawnItem(
    index: def.index,
    kind: def.kind,
    exists: exists,
    entryId: entry.id,
    levelDelta: def.hasLevelDelta ? def.levelDeltaMin! + deltaDraw : null,
    quantity: quantity,
    px: px,
    py: py,
    uid: spawnUid(seed, epochId, cellX, cellY, window, def.index),
  );
}
