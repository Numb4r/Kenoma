/// Câmera do mapa: onde está, em que escala e quais células z21 aparecem. Dart puro, sem Flutter: a
/// tela só aplica o que sai daqui.
///
/// Coordenadas de mundo em células z21 fracionárias (x para leste, y para o sul, como no slippy map).
/// A escala é em pixels de tela por célula; a spec usa 16 px por célula como base.
library;

import 'dart:math' as math;

import '../core/tiles.dart';

/// Retângulo de células z21, com os dois extremos incluídos.
class CellRange {
  const CellRange(this.x0, this.y0, this.x1, this.y1);

  final int x0;
  final int y0;
  final int x1;
  final int y1;

  int get width => math.max(0, x1 - x0 + 1);
  int get height => math.max(0, y1 - y0 + 1);
  bool get isEmpty => width == 0 || height == 0;
  int get count => width * height;

  bool contains(int x, int y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;

  /// A interseção com [other]. Vazia se não se tocam.
  CellRange intersect(CellRange other) =>
      CellRange(math.max(x0, other.x0), math.max(y0, other.y0), math.min(x1, other.x1), math.min(y1, other.y1));

  /// Os quatro limites, para comparar faixas.
  (int, int, int, int) get bounds => (x0, y0, x1, y1);

  @override
  String toString() => 'CellRange($x0,$y0..$x1,$y1)';
}

class MapCamera {
  const MapCamera({required this.centerX, required this.centerY, this.pixelsPerCell = defaultScale});

  /// Câmera centrada numa coordenada.
  factory MapCamera.atLatLon(double lat, double lon, {double pixelsPerCell = defaultScale}) {
    final (x, y) = latLonToTileFraction(lat, lon, biomeZoom);
    return MapCamera(centerX: x, centerY: y, pixelsPerCell: pixelsPerCell.clamp(minScale, maxScale));
  }

  /// Menor e maior escala: de ~10 km a ~0,6 km de largura numa tela de 1080 px.
  static const double minScale = 2;
  static const double maxScale = 32;

  /// A escala da spec: um tile de 16 px por célula.
  static const double defaultScale = 16;

  final double centerX;
  final double centerY;
  final double pixelsPerCell;

  /// Latitude e longitude do centro.
  (double, double) get latLon => tileFractionToLatLon(centerX, centerY, biomeZoom);

  /// Arrastar o dedo [dx] e [dy] pixels move o mapa junto com ele, então o centro vai para o outro lado.
  MapCamera panned(double dx, double dy) =>
      MapCamera(centerX: centerX - dx / pixelsPerCell, centerY: centerY - dy / pixelsPerCell, pixelsPerCell: pixelsPerCell);

  /// Muda a escala (limitada) mantendo parada a célula que está sob o ponto de tela ([focalX], [focalY]).
  MapCamera zoomedAbout(double scale, double focalX, double focalY, double viewW, double viewH) {
    final next = scale.clamp(minScale, maxScale).toDouble();
    final (cx, cy) = screenToCell(focalX, focalY, viewW, viewH);
    return MapCamera(
      centerX: cx - (focalX - viewW / 2) / next,
      centerY: cy - (focalY - viewH / 2) / next,
      pixelsPerCell: next,
    );
  }

  /// Célula (fracionária) sob o ponto de tela.
  (double, double) screenToCell(double sx, double sy, double viewW, double viewH) =>
      (centerX + (sx - viewW / 2) / pixelsPerCell, centerY + (sy - viewH / 2) / pixelsPerCell);

  /// Ponto de tela de uma posição de mundo em células.
  (double, double) cellToScreen(double cx, double cy, double viewW, double viewH) =>
      (viewW / 2 + (cx - centerX) * pixelsPerCell, viewH / 2 + (cy - centerY) * pixelsPerCell);

  /// Células z21 que tocam a tela. Só essas se desenham.
  CellRange visibleRange(double viewW, double viewH) {
    final (left, top) = screenToCell(0, 0, viewW, viewH);
    final (right, bottom) = screenToCell(viewW, viewH, viewW, viewH);
    return CellRange(left.floor(), top.floor(), (right - 1e-9).floor(), (bottom - 1e-9).floor());
  }

  /// Mantém o centro dentro de [bounds] (as bordas incluídas).
  MapCamera clampedTo(CellRange bounds) => MapCamera(
        centerX: centerX.clamp(bounds.x0.toDouble(), bounds.x1 + 1.0).toDouble(),
        centerY: centerY.clamp(bounds.y0.toDouble(), bounds.y1 + 1.0).toDouble(),
        pixelsPerCell: pixelsPerCell,
      );
}
