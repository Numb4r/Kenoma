/// Névoa de guerra (docs/GDD.md): o mapa começa encoberto e é revelado em volta do caminho real andado, salvo no
/// aparelho. As células reveladas são as de spawn (z20, ~35 m) e ficam guardadas em blocos z17: cada bloco cobre 8 × 8
/// células e vira um inteiro de 64 bits, um bit por célula (`bit = linha × 8 + coluna`). O caminho do simulador de debug
/// fica num conjunto à parte, para dar para limpar. Dart puro; o desenho do véu é de `ui/game/fog_painter.dart`.
library;

import 'dart:math' as math;

/// Quantas células z20 cabem por lado de um bloco z17.
const int fogChunkSide = 8;

/// Quantas células estão marcadas num [mask] de 64 bits.
int popCount(int mask) {
  var n = 0;
  var m = mask;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

class FogState {
  FogState({Map<String, int>? cells, Map<String, int>? debug})
      : _cells = {...?cells},
        _debug = {...?debug};

  factory FogState.fromJson(Map<String, dynamic>? j) => FogState(
        cells: {for (final e in ((j?['cells'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
        debug: {for (final e in ((j?['debug'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      );

  final Map<String, int> _cells;
  final Map<String, int> _debug;

  static String chunkKey(int cx, int cy) => '${cx ~/ fogChunkSide},${cy ~/ fogChunkSide}';
  static int bitOf(int cx, int cy) => (cy % fogChunkSide) * fogChunkSide + (cx % fogChunkSide);

  bool _has(Map<String, int> m, int cx, int cy) => ((m[chunkKey(cx, cy)] ?? 0) & (1 << bitOf(cx, cy))) != 0;

  /// Se a célula z20 `(cx, cy)` está revelada, pelo caminho real ou pelo de debug.
  bool isRevealed(int cx, int cy) => _has(_cells, cx, cy) || _has(_debug, cx, cy);

  /// Marca a célula. `true` se ela era nova.
  bool _mark(Map<String, int> m, int cx, int cy) {
    if (_has(m, cx, cy)) return false;
    final k = chunkKey(cx, cy);
    m[k] = (m[k] ?? 0) | (1 << bitOf(cx, cy));
    return true;
  }

  /// Revela as células z20 que tocam o círculo de raio [radiusM] em torno de de ([x21], [y21]) (células z21 fracionárias, com
  /// [metersPerCell21] metros por célula z21). Devolve quantas eram novas. Com [debug], vão para o conjunto de debug.
  int reveal(double x21, double y21, double radiusM, double metersPerCell21, {bool debug = false}) {
    final target = debug ? _debug : _cells;
    final r21 = radiusM / metersPerCell21; // raio em células z21
    var added = 0;
    for (var cy = ((y21 - r21) / 2).floor(); cy <= ((y21 + r21) / 2).floor(); cy++) {
      for (var cx = ((x21 - r21) / 2).floor(); cx <= ((x21 + r21) / 2).floor(); cx++) {
        if (cx < 0 || cy < 0) continue;
        // A célula entra se qualquer parte dela toca o círculo (a distância do ponto ao retângulo da célula).
        final dx = math.max(0.0, ((cx + 0.5) * 2 - x21).abs() - 1), dy = math.max(0.0, ((cy + 0.5) * 2 - y21).abs() - 1);
        if (math.sqrt(dx * dx + dy * dy) > r21) continue;
        if (_mark(target, cx, cy)) added++;
      }
    }
    // A célula onde o jogador está sempre entra, mesmo com o raio menor que meia célula.
    if (_mark(target, (x21 / 2).floor(), (y21 / 2).floor())) added++;
    return added;
  }

  /// Quantas células o caminho real revelou (sem as de debug).
  int get revealedCount => _cells.values.fold(0, (a, m) => a + popCount(m));

  int get debugCount => _debug.values.fold(0, (a, m) => a + popCount(m));

  /// A área revelada pelo caminho real, em km², dado o lado de uma célula z20 em metros.
  double areaKm2(double cellSideM) => revealedCount * cellSideM * cellSideM / 1e6;

  /// Apaga o que veio do simulador.
  void clearDebug() => _debug.clear();

  /// Os blocos z17 que têm alguma célula revelada.
  Iterable<String> get chunkKeys => {..._cells.keys, ..._debug.keys};

  Map<String, dynamic> toJson() => {'cells': _cells, 'debug': _debug};
}
