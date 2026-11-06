/// O que o mundo lê dos mapas, sem saber de onde veio: pacote de região, bloco do fallback ou piso sem dados. Só interfaces.
/// `revision` sobe quando chega dado novo: quem guarda cache derivado compara e limpa, sem reiniciar o app.
library;

import 'visual_pack.dart';

/// A grade de biomas em células z21. `x0`, `y0`, `width` e `height` são a área do pacote (no mundo em camadas, a da região
/// embutida).
abstract interface class BiomeGrid {
  int get x0;
  int get y0;
  int get width;
  int get height;
  int get revision;

  /// Id do bioma da célula z21 `(x, y)`. Sem dado vale Vazio.
  int biomeAt(int x, int y);

  /// As quatro células z21 de uma célula z20, na ordem (noroeste, nordeste, sudoeste, sudeste).
  List<int> quadOf(int cellX, int cellY);
}

/// As geometrias por tile do desenho.
abstract interface class VisualSource {
  int get version;
  int get tileZoom;
  int get extent;
  int get revision;

  bool hasTile(int x, int y);

  /// O tile `(x, y)`, ou `null` se não há nada para desenhar ali.
  VisualTile? decode(int x, int y);
}

/// As vias onde não se anda.
abstract interface class NoWalkSource {
  /// Os segmentos `x0, y0, x1, y1, ...` (células z21 fracionárias) perto da célula z20 `(cx, cy)`. Vazio se nenhum.
  List<double> near(int cx, int cy);
}
