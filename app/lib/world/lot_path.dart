/// O caminho dentro do lote (0.29.0): A* em 8 direções na grade de casas, sem cortar quina de parede ou objeto. O lote é
/// pequeno (até 32 × 32), então a busca é direta. Dart puro.
library;

import 'dart:collection';
import 'dart:math' as math;

/// O caminho de [from] até [to] (as duas casas incluídas), ou `null` se não há. [walkable] diz se dá para pisar na casa.
List<(int, int)>? lotPath((int, int) from, (int, int) to, bool Function(int x, int y) walkable) {
  if (from == to) return [from];
  if (!walkable(to.$1, to.$2)) return null;
  double h((int, int) c) {
    final dx = (c.$1 - to.$1).abs(), dy = (c.$2 - to.$2).abs();
    return (dx + dy) + (math.sqrt2 - 2) * math.min(dx, dy); // octil
  }

  final g = <(int, int), double>{from: 0};
  final came = <(int, int), (int, int)>{};
  final open = SplayTreeSet<(double, int, int)>((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : (a.$2 != b.$2 ? a.$2 - b.$2 : a.$3 - b.$3));
  open.add((h(from), from.$1, from.$2));
  final closed = <(int, int)>{};
  var guard = 0;
  while (open.isNotEmpty && guard++ < 20000) {
    final top = open.first;
    open.remove(top);
    final cur = (top.$2, top.$3);
    if (cur == to) {
      final out = [cur];
      for (var c = came[cur]; c != null; c = came[c]) {
        out.add(c);
      }
      return out.reversed.toList();
    }
    if (!closed.add(cur)) continue;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final n = (cur.$1 + dx, cur.$2 + dy);
        if (closed.contains(n) || !walkable(n.$1, n.$2)) continue;
        // Na diagonal, as duas casas do lado também têm de estar livres: nada de passar pela quina.
        if (dx != 0 && dy != 0 && (!walkable(cur.$1 + dx, cur.$2) || !walkable(cur.$1, cur.$2 + dy))) continue;
        final cost = g[cur]! + (dx != 0 && dy != 0 ? math.sqrt2 : 1);
        if (cost >= (g[n] ?? double.infinity)) continue;
        g[n] = cost;
        came[n] = cur;
        open.add((cost + h(n), n.$1, n.$2));
      }
    }
  }
  return null;
}

/// A casa livre mais perto de [to] (ela mesma, se livre), procurando em anéis até [radius]; `null` se nenhuma.
(int, int)? nearestWalkable((int, int) to, bool Function(int x, int y) walkable, {int radius = 4}) {
  if (walkable(to.$1, to.$2)) return to;
  for (var r = 1; r <= radius; r++) {
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (math.max(dx.abs(), dy.abs()) != r) continue;
        if (walkable(to.$1 + dx, to.$2 + dy)) return (to.$1 + dx, to.$2 + dy);
      }
    }
  }
  return null;
}
