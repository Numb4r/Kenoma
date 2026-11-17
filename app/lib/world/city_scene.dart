/// A cena do estilo Completo do mapa (0.22.0, `docs/art/estilo-mapa.md`): por tile z15, as ruas, verdes, água, prédios,
/// árvores, postes e props (ponto de ônibus, banca, faixa de pedestre) em células z21. Os prédios e as árvores do OSM vêm do
/// arquivo de prédios; postes, árvores plantadas e props saem de hash do tile e da posição, iguais em todo aparelho e em
/// qualquer recorte (a tela, o bloco do cache). Só cenário: nada da lógica lê. Dart puro.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/fnv.dart';
import '../data/building_pack.dart';
import '../data/traffic_pack.dart';
import '../data/visual_pack.dart';
import '../data/ground_pack.dart';

/// Classe da rua pelo nome do estilo.
String roadClassKey(RoadClass c) => switch (c) {
      RoadClass.principal => 'principal',
      RoadClass.secondary => 'secondary',
      RoadClass.local => 'local',
      RoadClass.pedestrian => 'pedestrian',
    };

class CityRoad {
  CityRoad(this.cls, this.xy);

  final String cls;

  /// `x0, y0, x1, y1, ...` em células z21.
  final Float64List xy;

  late final (double, double, double, double) bounds = boundsOf(xy);
}

/// O retângulo `(esquerda, topo, direita, baixo)` de uma lista `x0, y0, x1, y1, ...`.
(double, double, double, double) boundsOf(Float64List xy) {
  var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
  for (var i = 0; i + 1 < xy.length; i += 2) {
    if (xy[i] < l) l = xy[i];
    if (xy[i] > r) r = xy[i];
    if (xy[i + 1] < t) t = xy[i + 1];
    if (xy[i + 1] > b) b = xy[i + 1];
  }
  return (l, t, r, b);
}

bool _touches((double, double, double, double) a, double l, double t, double r, double b) => a.$1 <= r && a.$3 >= l && a.$2 <= b && a.$4 >= t;

/// O visual de um prédio: o bioma do estilo, o tipo para `wallStyleFor` e a altura falsa em pixels de arte (por metro de
/// zoom). As mesmas regras do Laboratório (`lab_block.dart`).
typedef BuildingLook = ({String biome, String styleType, int fakeHeightPx});

const _sacredTypes = {'church', 'chapel', 'cathedral', 'temple'};
const _shopTypes = {'commercial', 'retail', 'supermarket', 'kiosk'};
const _houseTypes = {'house', 'residential', 'detached', 'semidetached_house', 'terrace'};

/// [gridBiome]: a chave do bioma da grade sob o prédio (`lit` faz o comércio das avenidas, como o `onAvenue` do laboratório).
BuildingLook buildingLook({required String type, required bool shop, required double areaM2, required double? levels, required String gridBiome}) {
  final biome = _sacredTypes.contains(type)
      ? 'sacred'
      : (shop || _shopTypes.contains(type) || (type == 'yes' && gridBiome == 'lit'))
          ? 'lit'
          : _houseTypes.contains(type)
              ? 'residential'
              : const {'construction', 'ruins', 'roof'}.contains(type)
                  ? 'empty'
                  // O prédio sem tipo fora do Centro: casa no Residencial e no Vazio (o bairro da grade é quase todo Vazio).
                  : (type == 'yes' && areaM2 < 260 && (gridBiome == 'residential' || gridBiome == 'void'))
                      ? 'residential'
                      : 'urban';
  final styleType = (type != 'yes' || biome != 'urban') ? (shop && type == 'yes' ? 'retail' : (biome == 'residential' && type == 'yes' ? 'house' : type)) : (areaM2 < 150 ? 'house' : (areaM2 > 2500 ? 'warehouse' : 'yes'));
  final base = switch (biome) {
    'sacred' => 16,
    'residential' => 5,
    'lit' => 8,
    'empty' => 3,
    _ => switch (type) {
        _ when type == 'yes' && areaM2 < 150 => 5,
        _ when type == 'yes' && areaM2 > 2500 => 9,
        'apartments' || 'office' || 'hotel' || 'school' || 'hospital' || 'public' || 'civic' => 14,
        'industrial' || 'warehouse' || 'garage' || 'garages' => 9,
        _ => 10,
      },
  };
  final lv = levels;
  final h = (lv != null && lv > 3) ? math.min(32, math.max(base, (6 + lv * 1.5).round())) : (lv != null && lv >= 2 && biome == 'residential' ? 8 : base);
  return (biome: biome, styleType: styleType, fakeHeightPx: h);
}

class CityBuilding {
  CityBuilding(this.xy, this.look, this.hash, {this.levels = 0});

  final Float64List xy;
  final BuildingLook look;
  final int hash;
  final int levels;

  int get length => xy.length ~/ 2;

  late final (double, double) centroid = () {
    var x = 0.0, y = 0.0;
    for (var i = 0; i < xy.length; i += 2) {
      x += xy[i];
      y += xy[i + 1];
    }
    return (x / length, y / length);
  }();

  late final (double, double, double, double) bounds = () {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (var i = 0; i < xy.length; i += 2) {
      l = math.min(l, xy[i]);
      r = math.max(r, xy[i]);
      t = math.min(t, xy[i + 1]);
      b = math.max(b, xy[i + 1]);
    }
    return (l, t, r, b);
  }();
}

/// Um objeto de pé do cenário: árvore (`tree_a`..., `ipe_purple`, `ipe_yellow`), poste (`lamp`), ponto de ônibus
/// (`bus_stop`), banca (`newsstand`); e a faixa de pedestre (`crosswalk`, deitada no chão, com o ângulo da rua [angle]).
/// O abrigo de ônibus do OSM: prédio de até tantos m² a até tantos metros de um ponto de ônibus (sai dos prédios).
const double kShelterMaxM2 = 40, kShelterNearM = 10;

/// Um prédio de [areaM2] a [distM] de um ponto de ônibus é o abrigo dele (sai dos prédios; o ponto fica de pé).
bool isBusShelter(double areaM2, double distM) => areaM2 <= kShelterMaxM2 && distM <= kShelterNearM;

class CityProp {
  const CityProp(this.kind, this.x, this.y, {this.angle = 0, this.widthM = 0, this.hash = 0});

  final String kind;
  final double x, y;
  final double angle;
  final double widthM;
  final int hash;
}

class CityTile {
  CityTile({required this.roads, required this.greens, required this.waters, required this.buildings, required this.props, this.areas = const []});

  final List<CityRoad> roads;

  /// 0.23.1: o uso do solo do OSM (`_ground.bin`) que toca o tile: estacionamento, baldio, lote, comércio, piso de pedestre e
  /// a zona da calçada portuguesa.
  final List<GroundArea> areas;

  /// Anéis em células z21 (o primeiro é o contorno; os outros, buracos).
  final List<List<Float64List>> greens, waters;
  final List<CityBuilding> buildings;
  final List<CityProp> props;

  /// 0.22.0: só o que toca o retângulo `[l, r] × [t, b]` (células z21). O bloco do cache desenha isto, não o tile inteiro:
  /// um tile z15 tem mais de um quilômetro de ruas e prédios.
  CityTile within(double l, double t, double r, double b) => CityTile(
        roads: [for (final x in roads) if (_touches(x.bounds, l, t, r, b)) x],
        greens: [for (final g in greens) if (g.isNotEmpty && _touches(boundsOf(g.first), l, t, r, b)) g],
        waters: [for (final g in waters) if (g.isNotEmpty && _touches(boundsOf(g.first), l, t, r, b)) g],
        buildings: [for (final x in buildings) if (_touches(x.bounds, l, t, r, b)) x],
        props: [for (final p in props) if (p.x >= l && p.x <= r && p.y >= t && p.y <= b) p],
        areas: [for (final a in areas) if (_touches((a.l, a.t, a.r, a.b), l, t, r, b)) a],
      );

  static final empty = CityTile(roads: const [], greens: const [], waters: const [], buildings: const [], props: const []);
}

int cityHash(List<int> parts) => fnv1a64([...parts, 0x43495459]) >>> 33; // CITY

/// Monta o [CityTile] do tile z15 `(tx, ty)`. [biomeAt]: a chave do bioma da grade numa célula z21. [mpc]: metros por
/// célula z21 (a largura das ruas e o espaço entre postes). [plantTrees]: árvores plantadas nos verdes sem árvore do OSM.
CityTile buildCityTile({
  required int tx,
  required int ty,
  required VisualTile? visual,
  required int cellsPerTile,
  required int extent,
  required double mpc,
  required String Function(int cx, int cy) biomeAt,
  BuildingSource? buildings,
  TrafficPointSource? points,
  GroundPack? ground,
}) {
  final x0 = tx * cellsPerTile.toDouble(), y0 = ty * cellsPerTile.toDouble(), u = cellsPerTile / extent;
  Float64List cells(Int32List xy) {
    final out = Float64List(xy.length);
    for (var i = 0; i < xy.length; i += 2) {
      out[i] = x0 + xy[i] * u;
      out[i + 1] = y0 + xy[i + 1] * u;
    }
    return out;
  }

  final roads = <CityRoad>[for (final l in visual?.lines ?? const <VisualLine>[]) CityRoad(roadClassKey(l.roadClass), cells(l.xy))];
  final greens = <List<Float64List>>[], waters = <List<Float64List>>[];
  for (final a in visual?.areas ?? const <VisualArea>[]) {
    (a.kind == AreaKind.green ? greens : waters).add([for (final r in a.rings) cells(r)]);
  }
  final x1 = x0 + cellsPerTile, y1 = y0 + cellsPerTile;
  final m2 = mpc * mpc;
  final bs = <CityBuilding>[];
  final occupied = <int>{}; // células z23 com prédio (as árvores plantadas não nascem dentro)
  // 0.24.2: o abrigo do ponto de ônibus vem do OSM como um prédio pequeno (`roof`, `shelter`) e virava um telhado que gira
  // com o chão. Ele sai daqui; o ponto fica de pé (o carimbo) com a base no chão, que gira.
  final stops = [for (final p in points?.pointsIn(x0 - 1, y0 - 1, x1 + 1, y1 + 1) ?? const <TrafficPoint>[]) if (p.kind == TrafficPointKind.busStop) p];
  bool isShelter(PackBuilding b) {
    final (cx, cy) = b.centroid;
    return stops.any((p) => isBusShelter(b.areaCells * m2, math.sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)) * mpc));
  }

  for (final b in buildings?.buildingsIn(x0, y0, x1, y1, margin: 0) ?? const <PackBuilding>[]) {
    final (cx, cy) = b.centroid;
    if (cx < x0 || cx >= x1 || cy < y0 || cy >= y1) continue; // cada prédio num tile só
    if (isShelter(b)) continue;
    final look = buildingLook(type: b.type, shop: b.shop, areaM2: b.areaCells * m2, levels: b.levels == 0 ? null : b.levels.toDouble(), gridBiome: biomeAt(cx.floor(), cy.floor()));
    bs.add(CityBuilding(b.xy, look, cityHash([b.index, b.length]), levels: b.levels));
    final (l, t, r, bb) = b.bounds;
    for (var y = (t * 4).floor(); y <= (bb * 4).floor(); y++) {
      for (var x = (l * 4).floor(); x <= (r * 4).floor(); x++) {
        occupied.add(x * 0x1000000 + y);
      }
    }
  }
  final props = <CityProp>[];
  // Árvores do OSM; perto de uma praça viram ipê (roxo ou amarelo pelo hash).
  final squares = [for (final p in points?.pointsIn(x0 - 4, y0 - 4, x1 + 4, y1 + 4) ?? const <TrafficPoint>[]) if (p.kind == TrafficPointKind.square) p];
  final squareR = 60 / mpc;
  String treeKind(double x, double y, int h) {
    final nearSquare = squares.any((s) => (s.x - x) * (s.x - x) + (s.y - y) * (s.y - y) < squareR * squareR);
    if (nearSquare && h % 100 < 35) return h % 2 == 0 ? 'ipe_purple' : 'ipe_yellow';
    return const ['tree_a', 'tree_b', 'tree_c', 'tree_a', 'tree_b'][h % 5];
  }

  for (final (x, y) in buildings?.treesIn(x0, y0, x1, y1) ?? const <(double, double)>[]) {
    final h = cityHash([(x * 64).round(), (y * 64).round(), 1]);
    props.add(CityProp(treeKind(x, y, h), x, y, hash: h));
  }
  props.addAll(plantTrees(greens, x0, y0, x1, y1, mpc, occupied, treeKind));
  // Postes nas calçadas: a cada 40 m nas principais e secundárias (lados alternados), 60 m nas locais; o passo é ancorado no
  // comprimento acumulado da linha, igual em qualquer recorte.
  final lamps = <(double, double)>[];
  for (final (ri, r) in roads.indexed) {
    if (r.cls == 'pedestrian') continue;
    final every = (r.cls == 'local' ? 60.0 : 40.0) / mpc, side = (roadWidthM(r.cls) / 2 + sidewalkWidthM(r.cls) / 2) / mpc;
    var acc = 15 / mpc, n = cityHash([tx, ty, ri]) % 2;
    for (var i = 0; i + 3 < r.xy.length; i += 2) {
      final ax = r.xy[i], ay = r.xy[i + 1], bx = r.xy[i + 2], by = r.xy[i + 3];
      final dx = bx - ax, dy = by - ay, len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-6) continue;
      while (acc < len) {
        final t = acc / len, sign = n.isEven ? 1 : -1;
        final px = ax + dx * t - dy / len * side * sign, py = ay + dy * t + dx / len * side * sign;
        if (px >= x0 && px < x1 && py >= y0 && py < y1 && !lamps.any((o) => (o.$1 - px) * (o.$1 - px) + (o.$2 - py) * (o.$2 - py) < (18 / mpc) * (18 / mpc))) {
          lamps.add((px, py));
        }
        n++;
        acc += every;
      }
      acc -= len;
    }
  }
  for (final (x, y) in lamps) {
    if (biomeAt(x.floor(), y.floor()) == 'void' && occupied.isEmpty) continue; // terreno baldio sem casa: sem poste
    props.add(CityProp('lamp', x, y, hash: cityHash([(x * 64).round(), (y * 64).round(), 3])));
  }
  // Pontos do OSM: ponto de ônibus na calçada, banca na praça (um em três), faixa de pedestre atravessando a rua mais perto.
  for (final p in points?.pointsIn(x0, y0, x1, y1) ?? const <TrafficPoint>[]) {
    final h = cityHash([(p.x * 64).round(), (p.y * 64).round(), p.kind.index]);
    switch (p.kind) {
      case TrafficPointKind.busStop:
        // O ângulo da rua mais perto: a base no chão (a marca da calçada e o meio-fio) corre ao longo dela.
        props.add(CityProp('bus_stop', p.x, p.y, angle: _nearestRoad(roads, p.x, p.y, 25 / mpc)?.$3 ?? 0, hash: h));
      case TrafficPointKind.square when h % 3 == 0:
        props.add(CityProp('newsstand', p.x, p.y, hash: h));
      case TrafficPointKind.crossing:
        final near = _nearestRoad(roads, p.x, p.y, 4 / mpc);
        if (near != null) props.add(CityProp('crosswalk', near.$1, near.$2, angle: near.$3, widthM: roadWidthM(near.$4), hash: h));
      default:
        break;
    }
  }
  // 0.24.2: a placa de rua nas esquinas, onde uma rua com nome (só as principais e secundárias têm nome no pacote) cruza
  // outra; na calçada da esquina. Tocar mostra o nome (cenário, igual ao do mapa).
  final ends = <(int, int), int>{};
  final named = <(int, int)>{};
  for (final l in visual?.lines ?? const <VisualLine>[]) {
    for (var i = 0; i < l.xy.length; i += 2) {
      final k = (l.xy[i], l.xy[i + 1]);
      ends[k] = (ends[k] ?? 0) + 1;
      if (l.name != null) named.add(k);
    }
  }
  final corner = 3 / mpc;
  for (final k in named) {
    if ((ends[k] ?? 0) < 2) continue;
    final x = x0 + k.$1 * u + corner, y = y0 + k.$2 * u + corner;
    if (x < x0 || x >= x1 || y < y0 || y >= y1) continue;
    props.add(CityProp('street_sign', x, y, hash: cityHash([(x * 64).round(), (y * 64).round(), 5])));
  }
  return CityTile(roads: roads, greens: greens, waters: waters, buildings: bs, props: props, areas: ground?.areasIn(tx, ty) ?? const []);
}

/// Árvores plantadas nos verdes: uma a cada ~14 m numa grade por hash, 38% das casas da grade, dentro do verde, fora de prédio
/// ([occupied]: células z23 com prédio) e só no retângulo `[x0, x1) × [y0, y1)`. [kind]: o carimbo pela posição e o hash.
List<CityProp> plantTrees(List<List<Float64List>> greens, double x0, double y0, double x1, double y1, double mpc, Set<int> occupied, String Function(double x, double y, int h) kind) {
  final props = <CityProp>[];
  final step = 14 / mpc;
  for (final g in greens) {
    final outer = g.first;
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (var i = 0; i < outer.length; i += 2) {
      l = math.min(l, outer[i]);
      r = math.max(r, outer[i]);
      t = math.min(t, outer[i + 1]);
      b = math.max(b, outer[i + 1]);
    }
    l = math.max(l, x0);
    t = math.max(t, y0);
    r = math.min(r, x1);
    b = math.min(b, y1);
    for (var gy = (t / step).floor(); gy * step < b; gy++) {
      for (var gx = (l / step).floor(); gx * step < r; gx++) {
        final h = cityHash([gx, gy, 2]);
        if (h % 100 > 38) continue;
        final x = (gx + 0.2 + (h >>> 8) % 60 / 100) * step, y = (gy + 0.2 + (h >>> 14) % 60 / 100) * step;
        if (x < x0 || x >= x1 || y < y0 || y >= y1) continue;
        if (occupied.contains((x * 4).floor() * 0x1000000 + (y * 4).floor())) continue;
        if (!pointInRings(x, y, g)) continue;
        props.add(CityProp(kind(x, y, h), x, y, hash: h));
      }
    }
  }
  return props;
}

/// O ponto mais perto de `(x, y)` nas ruas de carro, a até [maxD] células: `(x, y, ângulo da rua, classe)`.
(double, double, double, String)? _nearestRoad(List<CityRoad> roads, double x, double y, double maxD) {
  (double, double, double, String)? best;
  var bd = maxD * maxD;
  for (final r in roads) {
    if (r.cls == 'pedestrian') continue;
    for (var i = 0; i + 3 < r.xy.length; i += 2) {
      final ax = r.xy[i], ay = r.xy[i + 1], dx = r.xy[i + 2] - ax, dy = r.xy[i + 3] - ay, l2 = dx * dx + dy * dy;
      if (l2 < 1e-12) continue;
      final t = (((x - ax) * dx + (y - ay) * dy) / l2).clamp(0.0, 1.0);
      final qx = ax + dx * t, qy = ay + dy * t, d = (qx - x) * (qx - x) + (qy - y) * (qy - y);
      if (d < bd) {
        bd = d;
        best = (qx, qy, math.atan2(dy, dx), r.cls);
      }
    }
  }
  return best;
}

bool pointInRings(double x, double y, List<Float64List> rings) {
  var inside = false;
  for (final ring in rings) {
    final n = ring.length ~/ 2;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final ax = ring[2 * i], ay = ring[2 * i + 1], bx = ring[2 * j], by = ring[2 * j + 1];
      if ((ay > y) != (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) inside = !inside;
    }
  }
  return inside;
}

/// A largura da rua de cada classe, em metros (asfalto), e a da calçada de cada lado (as do laboratório).
double roadWidthM(String cls) => switch (cls) {
      'principal' => 14,
      'secondary' => 10,
      'local' => 7,
      _ => 3,
    };
double sidewalkWidthM(String cls) => switch (cls) {
      'principal' || 'secondary' => 3,
      'local' => 2,
      _ => 0,
    };
