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
  const MapCamera({required this.centerX, required this.centerY, this.pixelsPerCell = defaultScale, this.rotation = 0});

  /// Câmera centrada numa coordenada.
  factory MapCamera.atLatLon(double lat, double lon, {double pixelsPerCell = defaultScale}) {
    final (x, y) = latLonToTileFraction(lat, lon, biomeZoom);
    return MapCamera(centerX: x, centerY: y, pixelsPerCell: pixelsPerCell.clamp(minScale, maxScale));
  }

  /// Menor e maior escala, em pixels lógicos por célula. Numa tela de 411 pixels lógicos de largura
  /// (1080 físicos) mostram de ~7 km (mínimo) a ~0,2 km (máximo) de largura.
  static const double minScale = 1;
  static const double maxScale = 32;

  /// A escala da spec: um tile de 16 px por célula.
  static const double defaultScale = 16;

  final double centerX;
  final double centerY;
  final double pixelsPerCell;

  /// Rotação do mapa em radianos, no sentido horário na tela, em torno do centro da tela. 0 é o norte para
  /// cima. Girar o mapa em [rotation] leva o norte para a direita do alto da tela.
  final double rotation;

  /// Latitude e longitude do centro.
  (double, double) get latLon => tileFractionToLatLon(centerX, centerY, biomeZoom);

  /// Arrastar o dedo [dx] e [dy] pixels move o mapa junto com ele, então o centro vai para o outro lado.
  MapCamera panned(double dx, double dy) {
    final (wx, wy) = _unrotate(dx, dy);
    return MapCamera(centerX: centerX - wx / pixelsPerCell, centerY: centerY - wy / pixelsPerCell, pixelsPerCell: pixelsPerCell, rotation: rotation);
  }

  /// Desfaz a rotação de um vetor de tela: o vetor do mundo, em pixels, que aparece como ([x], [y]).
  (double, double) _unrotate(double x, double y) {
    if (rotation == 0) return (x, y);
    final c = math.cos(rotation), s = math.sin(rotation);
    return (x * c + y * s, -x * s + y * c);
  }

  /// Muda a escala (limitada) mantendo parada a célula que está sob o ponto de tela ([focalX], [focalY]).
  MapCamera zoomedAbout(double scale, double focalX, double focalY, double viewW, double viewH) {
    final next = scale.clamp(minScale, maxScale).toDouble();
    final (cx, cy) = screenToCell(focalX, focalY, viewW, viewH);
    final (wx, wy) = _unrotate(focalX - viewW / 2, focalY - viewH / 2);
    return MapCamera(centerX: cx - wx / next, centerY: cy - wy / next, pixelsPerCell: next, rotation: rotation);
  }

  /// Célula (fracionária) sob o ponto de tela.
  (double, double) screenToCell(double sx, double sy, double viewW, double viewH) {
    final (wx, wy) = _unrotate(sx - viewW / 2, sy - viewH / 2);
    return (centerX + wx / pixelsPerCell, centerY + wy / pixelsPerCell);
  }

  /// Ponto de tela de uma posição de mundo em células.
  (double, double) cellToScreen(double cx, double cy, double viewW, double viewH) {
    final vx = (cx - centerX) * pixelsPerCell, vy = (cy - centerY) * pixelsPerCell;
    if (rotation == 0) return (viewW / 2 + vx, viewH / 2 + vy);
    final c = math.cos(rotation), s = math.sin(rotation);
    return (viewW / 2 + vx * c - vy * s, viewH / 2 + vx * s + vy * c);
  }

  /// Células z21 que tocam a tela. Só essas se desenham.
  CellRange visibleRange(double viewW, double viewH) {
    final (left, top, right, bottom) = visibleBounds(viewW, viewH);
    return CellRange(left.floor(), top.floor(), (right - 1e-9).floor(), (bottom - 1e-9).floor());
  }

  /// O menor retângulo de células, alinhado ao mundo, que contém a tela inteira: com o mapa girado, os
  /// quatro cantos da tela caem em lugares diferentes e o retângulo cresce.
  (double, double, double, double) visibleBounds(double viewW, double viewH) {
    final corners = [
      screenToCell(0, 0, viewW, viewH),
      screenToCell(viewW, 0, viewW, viewH),
      screenToCell(0, viewH, viewW, viewH),
      screenToCell(viewW, viewH, viewW, viewH),
    ];
    return (
      corners.map((c) => c.$1).reduce(math.min),
      corners.map((c) => c.$2).reduce(math.min),
      corners.map((c) => c.$1).reduce(math.max),
      corners.map((c) => c.$2).reduce(math.max),
    );
  }

  /// Mantém o centro dentro de [bounds] (as bordas incluídas).
  MapCamera clampedTo(CellRange bounds) => MapCamera(
        centerX: centerX.clamp(bounds.x0.toDouble(), bounds.x1 + 1.0).toDouble(),
        centerY: centerY.clamp(bounds.y0.toDouble(), bounds.y1 + 1.0).toDouble(),
        pixelsPerCell: pixelsPerCell,
        rotation: rotation,
      );
}
