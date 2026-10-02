import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../world/map_camera.dart';
import '../../world/map_probe.dart';
import '../../world/region_map.dart';
import 'map_renderer.dart';

/// O que o painel de debug mostra: o centro do mapa, a escala e o que há sob o dedo.
class MapHudData {
  const MapHudData({required this.lat, required this.lon, required this.pixelsPerCell, required this.cellX, required this.cellY, this.probe});

  final double lat;
  final double lon;
  final double pixelsPerCell;

  /// Célula z21 do centro.
  final int cellX;
  final int cellY;

  /// O que há sob o último ponto tocado. `null` antes do primeiro toque.
  final MapProbe? probe;
}

/// Tela do mapa em Flame. Guarda a câmera, repassa os gestos para ela e desenha com o [MapRenderer]:
/// as regras (células visíveis, bioma, limites) estão em `world/`.
class MapGame extends FlameGame {
  MapGame({required this.renderer, required MapCamera camera}) : _camera = camera.clampedTo(renderer.packCells) {
    hud = ValueNotifier(_hud());
  }

  final MapRenderer renderer;
  RegionMap get map => renderer.map;

  MapCamera _camera;
  MapCamera get mapCamera => _camera;

  /// Sobrepõe a grade das células de spawn (z20).
  bool grid20 = false;
  MapProbe? probe;
  late final ValueNotifier<MapHudData> hud;

  double _scaleAtStart = MapCamera.defaultScale;
  double _sinceHud = 0;
  bool _dirty = false;

  @override
  Color backgroundColor() => const Color(0xFF1A1424);

  double get _w => size.x;
  double get _h => size.y;

  MapHudData _hud() {
    final (lat, lon) = _camera.latLon;
    return MapHudData(
      lat: lat,
      lon: lon,
      pixelsPerCell: _camera.pixelsPerCell,
      cellX: _camera.centerX.floor(),
      cellY: _camera.centerY.floor(),
      probe: probe,
    );
  }

  /// Leva a câmera para uma coordenada, mantendo a escala.
  void jumpTo(double lat, double lon) {
    _camera = MapCamera.atLatLon(lat, lon, pixelsPerCell: _camera.pixelsPerCell).clampedTo(renderer.packCells);
    _dirty = true;
  }

  void setGrid20(bool on) {
    grid20 = on;
    _dirty = true;
  }

  void scaleStart() => _scaleAtStart = _camera.pixelsPerCell;

  /// Arrasta ([dx], [dy] pixels) e dá zoom ([scale] acumulado desde o início do gesto) em volta do ponto
  /// de ancoragem ([fx], [fy]).
  void scaleUpdate({required double fx, required double fy, required double dx, required double dy, required double scale}) {
    if (_w <= 0 || _h <= 0) return;
    _camera = _camera.panned(dx, dy).zoomedAbout(_scaleAtStart * scale, fx, fy, _w, _h).clampedTo(renderer.packCells);
    _dirty = true;
  }

  /// O dedo está em ([x], [y]): a sonda mostra o que há ali.
  void touch(double x, double y) {
    if (_w <= 0 || _h <= 0) return;
    final (cx, cy) = _camera.screenToCell(x, y, _w, _h);
    probe = probeAt(map, cx, cy);
    _dirty = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sinceHud += dt;
    // O painel não precisa mais que ~10 atualizações por segundo.
    if (_dirty && _sinceHud >= 0.1) {
      _dirty = false;
      _sinceHud = 0;
      hud.value = _hud();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_w <= 0 || _h <= 0) return;
    renderer.paint(canvas, Size(_w, _h), camera: _camera, grid20: grid20, probe: probe);
  }
}
