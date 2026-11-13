/// O mundo em três camadas, por célula: pacote de região (Campinas nos assets, as outras baixadas), bloco do fallback
/// Overpass e o piso sem dados (Vazio, que spawna como Residencial, sem caminhos: posição crua do sorteio). Dart puro.
///
/// Entre um tile que cruza a borda de um pacote, o pacote sempre vence no desenho e nos caminhos: quem está dentro dele vê o
/// mesmo com ou sem bloco, e Campinas não muda.
library;

import '../data/traffic_pack.dart';
import '../data/relief_pack.dart';
import 'dart:collection';

import '../core/tiles.dart';
import '../data/access_pack.dart';
import '../data/map_sources.dart';
import '../data/nowalk_pack.dart';
import '../data/region_pack.dart';
import '../data/visual_pack.dart';
import 'fallback/block.dart';
import 'region_map.dart' show voidBiomeId;

/// De onde vem o mapa num lugar.
enum MapSourceKind { pack, overpass, floor }

/// Um pacote de região já lido e conferido.
class LoadedRegion {
  const LoadedRegion({required this.id, required this.grid, required this.visual, this.noWalk, this.access, this.relief, this.traffic});

  /// Os pontos do OSM da região (postes, marquises, becos, semáforos). `null`: sem pontos.
  final TrafficPack? traffic;

  LoadedRegion copyWith({AccessPack? access, TrafficPack? traffic}) =>
      LoadedRegion(id: id, grid: grid, visual: visual, noWalk: noWalk, access: access ?? this.access, relief: relief, traffic: traffic ?? this.traffic);

  /// O relevo da região (época 9 em diante). `null`: terreno plano.
  final ReliefPack? relief;

  final String id;
  final RegionPack grid;
  final VisualPack visual;
  final NoWalkPack? noWalk;

  /// O arquivo de rota (`_noaccess.bin`). `null`: a rota segue sem ele.
  final AccessPack? access;

  bool contains(int x, int y) => x >= grid.x0 && y >= grid.y0 && x < grid.x0 + grid.width && y < grid.y0 + grid.height;
}

class LayeredWorld implements BiomeGrid, VisualSource, NoWalkSource, RouteAccessSource, ReliefSource, TrafficPointSource {
  // Os pontos de todas as regiões (as áreas não se sobrepõem). Fora delas, nenhum.
  @override
  List<TrafficPoint> pointsIn(double left, double top, double right, double bottom) => [
        for (final r in _regions) ...?r.traffic?.pointsIn(left, top, right, bottom),
      ];

  // O relevo: o da primeira região que cobre o ponto. Fora delas (blocos do fallback), terreno plano.
  @override
  double? heightAt(double x21, double y21) {
    for (final r in _regions) {
      final h = r.relief?.heightAt(x21, y21);
      if (h != null) return h;
    }
    return null;
  }

  @override
  int? h16At(int cx, int cy) {
    for (final r in _regions) {
      final h = r.relief?.h16At(cx, cy);
      if (h != null) return h;
    }
    return null;
  }

  LayeredWorld({required List<LoadedRegion> regions, this.maxBlocks = 32}) : _regions = [...regions] {
    assert(regions.isNotEmpty, 'o mundo começa com a região embutida');
  }

  final List<LoadedRegion> _regions;

  /// Blocos em memória, do mais antigo para o mais novo. O que sai daqui continua no disco.
  final LinkedHashMap<(int, int), FallbackBlock> _blocks = LinkedHashMap();
  final int maxBlocks;
  int _revision = 0;

  @override
  int get revision => _revision;

  LoadedRegion get _base => _regions.first;

  bool hasRegion(String id) => _regions.any((r) => r.id == id);

  /// A região [id] já tem o arquivo de rota.
  bool hasAccess(String id) => _regions.any((r) => r.id == id && r.access != null);

  /// O arquivo de rota de uma região que já está no mundo (baixado depois dela). Só a rota lê: o desenho não muda.
  void setAccess(String id, AccessPack access) {
    final i = _regions.indexWhere((r) => r.id == id);
    if (i < 0) return;
    _regions[i] = _regions[i].copyWith(access: access);
  }

  /// A região [id] já tem os pontos do OSM.
  bool hasTraffic(String id) => _regions.any((r) => r.id == id && r.traffic != null);

  /// Os pontos do OSM de uma região que já está no mundo (baixados depois dela).
  void setTraffic(String id, TrafficPack traffic) {
    final i = _regions.indexWhere((r) => r.id == id);
    if (i >= 0) _regions[i] = _regions[i].copyWith(traffic: traffic);
  }

  void addRegion(LoadedRegion region) {
    if (hasRegion(region.id)) return;
    _regions.add(region);
    _revision++;
  }

  /// O bloco do tile z15, se está em memória.
  FallbackBlock? block(int tx, int ty) => _blocks[(tx, ty)];

  /// Chegou um bloco (da rede ou do disco): substitui o que havia.
  void putBlock(FallbackBlock b) {
    _blocks.remove((b.tx, b.ty));
    _blockAccess.remove((b.tx, b.ty));
    _blocks[(b.tx, b.ty)] = b;
    while (_blocks.length > maxBlocks) {
      _blockAccess.remove(_blocks.keys.first);
      _blocks.remove(_blocks.keys.first);
    }
    _revision++;
  }

  LoadedRegion? _regionOf(int x, int y) {
    for (final r in _regions) {
      if (r.contains(x, y)) return r;
    }
    return null;
  }

  /// A fonte da célula z21 `(x, y)`.
  MapSourceKind sourceAtCell(int x, int y) {
    if (_regionOf(x, y) != null) return MapSourceKind.pack;
    return _blocks.containsKey((x >>> 6, y >>> 6)) ? MapSourceKind.overpass : MapSourceKind.floor;
  }

  MapSourceKind sourceAt(double lat, double lon) {
    final (x, y) = latLonToTile(lat, lon, biomeZoom);
    return sourceAtCell(x, y);
  }

  /// O tile z15 tem alguma célula fora dos pacotes: um bloco acrescenta algo.
  bool needsBlock(int tx, int ty) {
    final x0 = tx * blockCells, y0 = ty * blockCells, x1 = x0 + blockCells - 1, y1 = y0 + blockCells - 1;
    return !_regions.any((r) => r.contains(x0, y0) && r.contains(x1, y1));
  }

  /// Nada a desenhar no tile z15: o desenho marca o piso com a grade fraca.
  bool isFloorTile(int tx, int ty) {
    if (_blocks.containsKey((tx, ty))) return false;
    final x0 = tx * blockCells, y0 = ty * blockCells, x1 = x0 + blockCells, y1 = y0 + blockCells;
    return !_regions.any((r) => r.visual.hasTile(tx, ty) || (x0 < r.grid.x0 + r.grid.width && x1 > r.grid.x0 && y0 < r.grid.y0 + r.grid.height && y1 > r.grid.y0));
  }

  @override
  int get x0 => _base.grid.x0;
  @override
  int get y0 => _base.grid.y0;
  @override
  int get width => _base.grid.width;
  @override
  int get height => _base.grid.height;

  @override
  int biomeAt(int x, int y) {
    final r = _regionOf(x, y);
    if (r != null) return r.grid.biomeAt(x, y);
    return _blocks[(x >>> 6, y >>> 6)]?.biomeAt(x, y) ?? voidBiomeId;
  }

  @override
  List<int> quadOf(int cellX, int cellY) {
    final x = cellX * 2, y = cellY * 2;
    return [biomeAt(x, y), biomeAt(x + 1, y), biomeAt(x, y + 1), biomeAt(x + 1, y + 1)];
  }

  @override
  int get version => _base.visual.version;
  @override
  int get tileZoom => _base.visual.tileZoom;
  @override
  int get extent => _base.visual.extent;

  LoadedRegion? _regionWithTile(int x, int y) {
    for (final r in _regions) {
      if (r.visual.hasTile(x, y)) return r;
    }
    return null;
  }

  @override
  bool hasTile(int x, int y) => _regionWithTile(x, y) != null || _blocks.containsKey((x, y));

  @override
  VisualTile? decode(int x, int y) => _regionWithTile(x, y)?.visual.decode(x, y) ?? _blocks[(x, y)]?.visual;

  /// Segue quem desenha o tile da célula z20 `(cx, cy)`.
  @override
  List<double> near(int cx, int cy) {
    final tx = cx >>> 5, ty = cy >>> 5;
    final r = _regionWithTile(tx, ty);
    if (r != null) return r.noWalk?.near(cx, cy) ?? const [];
    // ponytail: devolve o bloco inteiro, não só a vizinhança; a conta dá igual e a célula fica em cache. Indexar por célula
    // como o NoWalkPack só se um bloco de trevo de rodovia pesar.
    return _blocks[(tx, ty)]?.noWalk ?? const [];
  }

  /// O índice por célula z20 do acesso de cada bloco, montado na primeira consulta.
  final Map<(int, int), Map<(int, int), List<double>>> _blockAccess = {};

  /// Segue quem desenha o tile da célula z20 `(cx, cy)`, como [near].
  @override
  List<double> accessNear(int cx, int cy) {
    final tx = cx >>> 5, ty = cy >>> 5;
    final r = _regionWithTile(tx, ty);
    if (r != null) return r.access?.accessNear(cx, cy) ?? const [];
    final b = _blocks[(tx, ty)];
    if (b == null || b.access.isEmpty) return const [];
    final index = _blockAccess[(tx, ty)] ??= () {
      final m = <(int, int), List<double>>{};
      for (var i = 0; i + 4 < b.access.length; i += 5) {
        addAccessSegment(m, b.access[i], b.access[i + 1], b.access[i + 2], b.access[i + 3], b.access[i + 4]);
      }
      return m;
    }();
    return index[(cx, cy)] ?? const [];
  }
}
