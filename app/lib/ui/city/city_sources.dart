/// De onde o estilo Completo tira a cena: no mapa, os pacotes da região (ruas e verdes do visual, prédios e árvores do arquivo
/// de prédios, pontos do tráfego e a grade de biomas); no Laboratório, o quarteirão fixo. Os tiles montados ficam num cache
/// pequeno. Só desenho.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/biomes.dart';
import '../../data/building_pack.dart';
import '../../data/map_sources.dart';
import '../../data/traffic_pack.dart';
import '../../world/city_scene.dart';
import '../../world/lab_block.dart';
import '../../world/visual_map.dart';

class MapCityTiles {
  MapCityTiles({required this.visual, required this.grid, required this.biomes, this.buildings, this.points, this.maxTiles = 12});

  final VisualMap visual;
  final BiomeGrid grid;
  final BiomeSet biomes;
  final BuildingSource? buildings;
  final TrafficPointSource? points;
  final int maxTiles;
  final _tiles = <(int, int), CityTile>{};
  int _revision = -1;

  /// Metros por célula z21 na latitude de agora (a largura das ruas e o espaço entre postes).
  double mpc = 17.6;

  int get cellsPerTile => visual.cellsPerTile;

  String biomeAt(int cx, int cy) {
    try {
      return biomes.byId(grid.biomeAt(cx, cy)).key;
    } on StateError {
      return 'void';
    }
  }

  /// 0.22.2: os tiles montados antes de os prédios deles chegarem (o tile de prédios ainda carregava).
  final _waiting = <(int, int)>{};
  int _buildingRev = -1;

  /// Os tiles que ganharam os prédios desde a última chamada: quem desenha refaz os blocos deles.
  List<(int, int)> takeRefreshed() {
    final b = buildings;
    if (b == null || b.buildingRevision == _buildingRev) return const [];
    _buildingRev = b.buildingRevision;
    final out = <(int, int)>[];
    for (final k in [..._waiting]) {
      final c = cellsPerTile;
      if (!b.readyAt(k.$1 * c + c / 2, k.$2 * c + c / 2)) continue;
      _waiting.remove(k);
      _tiles.remove(k);
      out.add(k);
    }
    return out;
  }

  CityTile tileAt(int tx, int ty) {
    if (visual.pack.revision != _revision) {
      _revision = visual.pack.revision; // chegou bloco ou região: a cena muda
      _tiles.clear();
    }
    final key = (tx, ty);
    final hit = _tiles.remove(key);
    if (hit != null) return _tiles[key] = hit;
    final c = cellsPerTile;
    if (buildings != null && !buildings!.readyAt(tx * c + c / 2, ty * c + c / 2)) _waiting.add(key);
    final t = buildCityTile(tx: tx, ty: ty, visual: visual.tile(tx, ty), cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, mpc: mpc, biomeAt: biomeAt, buildings: buildings, points: points);
    _tiles[key] = t;
    while (_tiles.length > maxTiles) {
      _tiles.remove(_tiles.keys.first);
    }
    return t;
  }

  int get revision => _revision;
}

/// O quarteirão do Laboratório em células z21: metros divididos por [mpc], com o centro em `(origin, origin)` no tile
/// `(0, 0)`. Tudo num tile só (o quarteirão tem uns 300 m).
class LabCityTiles {
  LabCityTiles(LabBlock block, {this.mpc = 17.6, this.origin = 32, this.ground = 'urban'}) : _tile = _build(block, mpc, origin.toDouble());

  /// O chão de fundo do quarteirão (o Urbano; a cena de um bioma no catálogo usa o dela).
  final String ground;

  final double mpc;
  final int origin;
  final CityTile _tile;
  static const int cellsPerTile = 64;

  (double, double) toCells(double xm, double ym) => (origin + xm / mpc, origin + ym / mpc);

  CityTile tileAt(int tx, int ty) => tx == 0 && ty == 0 ? _tile : CityTile.empty;

  String biomeAt(int cx, int cy) => ground;

  static CityTile _build(LabBlock b, double mpc, double o) {
    Float64List xy(List<Pt> pts) => Float64List.fromList([for (final p in pts) ...[o + p.$1 / mpc, o + p.$2 / mpc]]);
    final roads = [for (final r in b.roads) CityRoad(r.cls, xy(r.pts))];
    final props = <CityProp>[];
    for (final (i, t) in b.trees.indexed) {
      final h = cityHash([i, 11]);
      props.add(CityProp(const ['tree_a', 'tree_b', 'tree_c', 'ipe_purple', 'ipe_yellow'][h % 5], o + t.$1 / mpc, o + t.$2 / mpc, hash: h));
    }
    final tile = CityTile(
      roads: roads,
      greens: [for (final g in b.greens) [xy(g)]],
      waters: [for (final w in b.waters) [xy(w)]],
      buildings: [
        for (final lb in b.buildings)
          CityBuilding(xy(lb.pts), buildingLook(type: lb.type, shop: lb.shop || lb.onAvenue, areaM2: lb.areaM2, levels: lb.levels, gridBiome: lb.onAvenue ? 'lit' : 'urban'), lb.hash, levels: (lb.levels ?? 0).round()),
      ],
      props: props,
    );
    // Postes pelas mesmas regras do mapa, com as ruas do quarteirão.
    final lamps = <CityProp>[];
    for (final r in roads) {
      lamps.addAll(_lampsAlong(r, mpc));
    }
    // Árvores nos verdes da praça, pelas mesmas regras do mapa (um quarto delas ipê).
    final planted = plantTrees(tile.greens, 0, 0, 64, 64, mpc, const {}, (x, y, h) => h % 100 < 25 ? (h % 2 == 0 ? 'ipe_purple' : 'ipe_yellow') : const ['tree_a', 'tree_b', 'tree_c', 'tree'][h % 4]);
    return CityTile(roads: tile.roads, greens: tile.greens, waters: tile.waters, buildings: tile.buildings, props: [...tile.props, ...planted, ...lamps, ..._labProps(b, mpc, o)]);
  }

  static List<CityProp> _lampsAlong(CityRoad r, double mpc) {
    if (r.cls == 'pedestrian') return const [];
    final out = <CityProp>[];
    final every = (r.cls == 'local' ? 60.0 : 40.0) / mpc, side = (roadWidthM(r.cls) / 2 + sidewalkWidthM(r.cls) / 2) / mpc;
    var acc = 15 / mpc, n = 0;
    for (var i = 0; i + 3 < r.xy.length; i += 2) {
      final ax = r.xy[i], ay = r.xy[i + 1], dx = r.xy[i + 2] - ax, dy = r.xy[i + 3] - ay;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-6) continue;
      while (acc < len) {
        final t = acc / len, sign = n.isEven ? 1 : -1;
        out.add(CityProp('lamp', ax + dx * t - dy / len * side * sign, ay + dy * t + dx / len * side * sign));
        n++;
        acc += every;
      }
      acc -= len;
    }
    return out;
  }

  /// No quarteirão do Laboratório não há pontos do OSM: um ponto de ônibus e uma banca na praça e duas faixas de pedestre,
  /// para a cena mostrar a cara de Campinas.
  static List<CityProp> _labProps(LabBlock b, double mpc, double o) {
    final out = <CityProp>[];
    if (b.greens.isNotEmpty) {
      final g = b.greens.first;
      final c = g.fold((0.0, 0.0), (a, p) => (a.$1 + p.$1 / g.length, a.$2 + p.$2 / g.length));
      out.add(CityProp('newsstand', o + c.$1 / mpc, o + c.$2 / mpc));
    }
    for (final r in b.roads.where((r) => r.cls == 'principal' || r.cls == 'secondary').take(2)) {
      if (r.pts.length < 2) continue;
      final a = r.pts[0], q = r.pts[1];
      final m = ((a.$1 + q.$1) / 2, (a.$2 + q.$2) / 2);
      final ang = math.atan2(q.$2 - a.$2, q.$1 - a.$1);
      out.add(CityProp('crosswalk', o + m.$1 / mpc, o + m.$2 / mpc, angle: ang, widthM: roadWidthM(r.cls)));
      final side = (roadWidthM(r.cls) / 2 + 1.5) / mpc;
      out.add(CityProp('bus_stop', o + m.$1 / mpc + 12 / mpc * math.cos(ang) - side * math.sin(ang), o + m.$2 / mpc + 12 / mpc * math.sin(ang) + side * math.cos(ang)));
    }
    return out;
  }
}
