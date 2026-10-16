/// Geração dos quatro itens de uma célula de spawn (docs/fase0-spec.md, seção 3).
library;

import 'behavior.dart';
import 'epochs.dart';
import 'fnv.dart';
import 'pcg32.dart';
import 'walkable.dart';
import 'weather.dart';

/// Sal do fluxo de sorteios `v2` (comportamento, variante, Brilhante e clima dos Ecos): separado do fluxo original, que
/// nunca muda de ordem nem de resultado.
final int saltV2 = salt('v2');

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
    this.behavior = EcoBehavior.passive,
    this.variantBiome,
    this.shiny = false,
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

  /// Só nos Ecos de épocas com o fluxo `v2`: comportamento, a chave do bioma da variante (ou `null`) e se é Brilhante.
  final EcoBehavior behavior;
  final String? variantBiome;
  final bool shiny;
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
  Weather weather = Weather.clear,
  String? Function(String entryId)? typeOf,
  PathSnapper? snapper,
}) =>
    [
      for (final def in epoch.items)
        _generateItem(seed, epoch, cellX, cellY, window, biomeKey, def, weather, typeOf, snapper),
    ];

SpawnItem _generateItem(
  int seed,
  Epoch epoch,
  int cellX,
  int cellY,
  int window,
  String biomeKey,
  SpawnItemDef def,
  Weather weather,
  String? Function(String entryId)? typeOf,
  PathSnapper? snapper,
) {
  final epochId = epoch.id;
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
  var px = rng.nextFloat();
  var py = rng.nextFloat();
  // Épocas com caminhos: Fagulhas e materiais nascem sobre o que dá para andar; os Ecos preferem, mas podem ficar um pouco
  // fora. Os sorteios acima não mudam: só a posição final é levada ao caminho.
  final walkable = epoch.walkable;
  if (walkable != null && snapper != null) {
    final s = snapper.snap(cellX, cellY, px, py, maxOffM: def.kind == 'eco' ? walkable.ecoOffPathM : 0);
    if (s != null) (px, py) = s;
  }

  // Épocas com o fluxo v2: comportamento, variante, Brilhante e o clima nos pesos. Tudo sai de um gerador separado,
  // que sempre consome os mesmos sorteios, existindo o Eco ou não, e não toca nos sorteios acima.
  var behavior = EcoBehavior.passive;
  String? variantBiome;
  var shiny = false;
  final v2 = epoch.ecoV2;
  if (v2 != null && def.kind == 'eco') {
    final r2 = Pcg32(fnv1a64([seed, epochId, cellX, cellY, window, def.index, saltV2]), saltKenoma);
    final weights = [for (final b in EcoBehavior.values) v2.behaviorWeights[b.id] ?? 0];
    var bp = r2.nextInt(weights.fold(0, (a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      if (bp < weights[i]) {
        behavior = EcoBehavior.values[i];
        break;
      }
      bp -= weights[i];
    }
    if (r2.nextFloat() < v2.variantChance) variantBiome = biomeKey;
    shiny = r2.nextFloat() < v2.shinyChance;
    final speciesRoll = r2.nextFloat();
    // O clima mexe nos pesos por tipo. Com tempo limpo, ou sem regra para nenhuma espécie da tabela, a espécie é a original.
    if (typeOf != null && weather != Weather.clear) {
      final mult = [for (final e in table) v2.weather.multiplier(weather, typeOf(e.id) ?? '')];
      if (mult.any((m) => m != 1.0)) {
        final adj = [for (var i = 0; i < table.length; i++) table[i].weight * mult[i]];
        var target = speciesRoll * adj.fold(0.0, (a, b) => a + b);
        entry = table.last;
        for (var i = 0; i < table.length; i++) {
          if (target < adj[i]) {
            entry = table[i];
            break;
          }
          target -= adj[i];
        }
      }
    }
  }

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
    behavior: behavior,
    variantBiome: variantBiome,
    shiny: shiny,
  );
}
