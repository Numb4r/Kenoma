/// O quarteirão fixo do Laboratório visual (0.21.0, só debug): prédios, ruas, verdes, água, lotes e árvores de um pedaço do
/// Centro de Campinas (`assets/lab/centro_bloco.json`, do OpenStreetMap), em metros a partir do centro, x para leste
/// e y para o sul. E a geometria do estilo novo: a altura falsa de cada prédio, o telhado deslocado a partir do centro da
/// tela (GTA 2), as paredes que aparecem e a sombra pelo sol. Não muda o mundo; nada disso entra no mapa principal até o
/// estilo ser aprovado. Dart puro.
library;

import 'dart:math' as math;

export 'city_scene.dart' show roadWidthM, sidewalkWidthM;

typedef Pt = (double, double);

class LabBuilding {
  LabBuilding({required this.pts, required this.type, required this.heightM, required this.shop, required this.levels, required this.index, this.onAvenue = false});

  final List<Pt> pts;
  final String type;

  /// A altura do OSM (`height` ou `building:levels` × 3 m), ou a estimada pelo tipo.
  final double heightM;
  final double? levels;
  final bool shop;
  final int index;

  /// Prédio sem tipo a até 25 m de uma rua principal ou 20 m de uma secundária: o comércio das ruas do Centro (o OSM quase
  /// não marca loja no prédio, só em ponto).
  final bool onAvenue;

  /// A área da planta (m²).
  double get areaM2 {
    var a = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i], q = pts[(i + 1) % pts.length];
      a += p.$1 * q.$2 - q.$1 * p.$2;
    }
    return a.abs() / 2;
  }

  /// O tipo para o estilo: o prédio sem tipo do Urbano vira casa se é pequeno (< 150 m²) e galpão se é enorme
  /// (> 1200 m²), para o Centro não ser só laje.
  String get styleType {
    if (type != 'yes' || biome != 'urban') return shop && type == 'yes' ? 'retail' : type;
    final a = areaM2;
    return a < 150 ? 'house' : (a > 1200 ? 'warehouse' : 'yes');
  }

  /// O bioma do estilo: Sagrado na igreja, Iluminado no comércio com loja, Residencial na casa, Urbano no resto.
  String get biome {
    if (const {'church', 'chapel', 'cathedral', 'temple'}.contains(type)) return 'sacred';
    if (shop || const {'commercial', 'retail', 'supermarket', 'kiosk'}.contains(type) || (type == 'yes' && onAvenue)) return 'lit';
    if (const {'house', 'residential', 'detached', 'semidetached_house', 'terrace'}.contains(type)) return 'residential';
    if (const {'construction', 'ruins', 'roof'}.contains(type)) return 'empty';
    return 'urban';
  }

  /// A altura falsa em pixels de arte (`docs/art/estilo-mapa.md`, Prédios): por tipo, com os andares do OSM nos blocos,
  /// nunca acima de 32.
  int get fakeHeightPx {
    final lv = levels;
    final base = switch (biome) {
      'sacred' => 16,
      'residential' => 5,
      'lit' => 8,
      'empty' => 3,
      _ => switch (type) {
          _ when type == 'yes' && areaM2 < 150 => 5,
          _ when type == 'yes' && areaM2 > 1200 => 9,
          'apartments' || 'office' || 'hotel' || 'school' || 'hospital' || 'public' || 'civic' => 14,
          'industrial' || 'warehouse' || 'garage' || 'garages' => 9,
          _ => 10, // o prédio sem tipo do Centro: dois a quatro andares
        },
    };
    if (lv != null && lv > 3) return math.min(32, math.max(base, (6 + lv * 1.5).round()));
    return base;
  }

  /// O centro do contorno.
  Pt get centroid {
    var x = 0.0, y = 0.0;
    for (final p in pts) {
      x += p.$1;
      y += p.$2;
    }
    return (x / pts.length, y / pts.length);
  }

  /// Um número fixo do prédio (variações: parede, cor do neon, janelas acesas).
  int get hash => (index * 2654435761 + pts.length * 40503) & 0x7fffffff;
}

double estimateHeightM(String type, double? levels, double? heightM) {
  if (heightM != null && heightM > 0) return heightM;
  if (levels != null && levels > 0) return levels * 3;
  return switch (type) {
    'house' || 'residential' || 'detached' => 4.5,
    'church' || 'cathedral' => 15,
    'apartments' => 24,
    'commercial' || 'retail' => 7,
    _ => 6,
  };
}

class LabBlock {
  LabBlock({required this.sizeM, required this.buildings, required this.roads, required this.greens, required this.waters, required this.trees, required this.lots});

  factory LabBlock.fromJson(Map<String, dynamic> j) {
    List<Pt> pts(Object? v) => [for (final p in v as List<dynamic>) ((p[0] as num).toDouble(), (p[1] as num).toDouble())];
    double? n(Object? v) => (v as num?)?.toDouble();
    final size = j['size_m'] as List<dynamic>;
    final mains = [for (final r in (j['roads'] as List<dynamic>).cast<Map<String, dynamic>>()) if (r['cls'] == 'principal') pts(r['pts'])];
    final secs = [for (final r in (j['roads'] as List<dynamic>).cast<Map<String, dynamic>>()) if (r['cls'] == 'secondary') pts(r['pts'])];
    bool onAvenue(List<Pt> b) {
      var x = 0.0, y = 0.0;
      for (final p in b) {
        x += p.$1;
        y += p.$2;
      }
      final c = (x / b.length, y / b.length);
      return mains.any((m) => distanceToPolyline(c, m) < 25) || secs.any((m) => distanceToPolyline(c, m) < 20);
    }

    return LabBlock(
      sizeM: ((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      buildings: [
        for (final (i, b) in (j['buildings'] as List<dynamic>).cast<Map<String, dynamic>>().indexed)
          LabBuilding(
            pts: pts(b['pts']),
            type: (b['type'] as String?) ?? 'yes',
            levels: n(b['levels']),
            heightM: estimateHeightM((b['type'] as String?) ?? 'yes', n(b['levels']), n(b['height_m'])),
            shop: b['shop'] == true,
            index: i,
            onAvenue: onAvenue(pts(b['pts'])),
          ),
      ],
      roads: [for (final r in (j['roads'] as List<dynamic>).cast<Map<String, dynamic>>()) (cls: r['cls'] as String, pts: pts(r['pts']))],
      greens: [for (final g in (j['greens'] as List<dynamic>).cast<Map<String, dynamic>>()) pts(g['pts'])],
      waters: [for (final g in (j['waters'] as List<dynamic>).cast<Map<String, dynamic>>()) pts(g['pts'])],
      trees: pts(j['trees']),
      lots: [for (final g in ((j['lots'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>()) pts(g['pts'])],
    );
  }

  final Pt sizeM;
  final List<LabBuilding> buildings;
  final List<({String cls, List<Pt> pts})> roads;
  final List<List<Pt>> greens, waters, lots;
  final List<Pt> trees;
}

/// GTA 2: o ponto do telhado de um ponto da base [p] (na tela, pixels de arte), com o prédio de altura [heightPx], visto de
/// uma câmera a [cameraPx] pixels de altura sobre o centro da tela [center]. No centro, deslocamento zero; para fora, o
/// telhado se afasta na direção do ponto, proporcional à altura. Como sai do centro da tela, vale com o mapa girando.
/// O deslocamento é limitado a [maxPx] (o `criativo`: prédio alto na borda virava uma cunha de parede maior que o telhado).
Pt roofPoint(Pt p, Pt center, double heightPx, {double cameraPx = 160, double maxPx = 16, Pt? halfScreen}) {
  final dx = p.$1 - center.$1, dy = p.$2 - center.$2, d = math.sqrt(dx * dx + dy * dy);
  var k = heightPx / math.max(heightPx + 1, cameraPx);
  if (d * k > maxPx) k = maxPx / d;
  if (halfScreen != null && d > 0) {
    // 0.23.1: o telhado anda no máximo um quarto da distância do centro da tela até a borda, na direção em que ele sai (prédio
    // alto não joga parede por cima da rua inteira). Medido do centro, igual para todo ponto: um prédio na borda ou fora dela
    // continua com parede.
    final ux = (dx / d).abs(), uy = (dy / d).abs();
    final edge = math.min(ux > 0 ? halfScreen.$1 / ux : double.infinity, uy > 0 ? halfScreen.$2 / uy : double.infinity);
    final cap = kRoofEdgeShare * edge;
    if (d * k > cap) k = cap / d;
  }
  return (p.$1 + dx * k, p.$2 + dy * k);
}

/// A parte da distância do centro da tela até a borda que o telhado pode andar (0.23.1).
const double kRoofEdgeShare = 0.25;

/// A parede da aresta `a → b` aparece: a normal de fora dela aponta para longe do centro da tela. [clockwise] é a orientação
/// do contorno na tela.
bool wallVisible(Pt a, Pt b, Pt center, {required bool clockwise}) {
  final ex = b.$1 - a.$1, ey = b.$2 - a.$2;
  // Na tela (y para baixo), a normal de fora do contorno horário é (ey, -ex).
  final nx = clockwise ? ey : -ey, ny = clockwise ? -ex : ex;
  final mx = (a.$1 + b.$1) / 2 - center.$1, my = (a.$2 + b.$2) / 2 - center.$2;
  return nx * mx + ny * my > 0;
}

/// O contorno é horário na tela (y para baixo): a área com sinal é positiva.
bool isClockwise(List<Pt> pts) {
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.$1 * q.$2 - q.$1 * p.$2;
  }
  return a > 0;
}

/// A sombra de um prédio de [heightPx] com o sol a [altDeg] de altura e [azDeg] de azimute (a partir do norte, horário),
/// na tela girada de [rotationRad] (o norte do mapa a [rotationRad] do topo da tela): o deslocamento da sombra em pixels de
/// arte, no máximo 3 vezes a altura. `null` com o sol abaixo do horizonte.
Pt? shadowOffset(double altDeg, double azDeg, double heightPx, {double rotationRad = 0}) {
  if (altDeg <= 0) return null;
  final len = math.min(heightPx / math.tan(altDeg * math.pi / 180), 3 * heightPx);
  final away = (azDeg + 180) * math.pi / 180 + rotationRad; // a sombra vai para o lado oposto ao sol
  return (math.sin(away) * len, -math.cos(away) * len);
}

/// A face da aresta `a → b` está virada para o sol (parede clara) com a sombra indo para [shadow].
bool facesSun(Pt a, Pt b, Pt? shadow, {required bool clockwise}) {
  if (shadow == null) return false;
  final ex = b.$1 - a.$1, ey = b.$2 - a.$2;
  final nx = clockwise ? ey : -ey, ny = clockwise ? -ex : ex;
  return nx * -shadow.$1 + ny * -shadow.$2 > 0;
}

/// A distância (metros) de [p] à linha [line].
double distanceToPolyline(Pt p, List<Pt> line) {
  var best = double.infinity;
  for (var i = 0; i + 1 < line.length; i++) {
    final a = line[i], b = line[i + 1];
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2, l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / l2).clamp(0.0, 1.0);
    final ex = a.$1 + dx * t - p.$1, ey = a.$2 + dy * t - p.$2;
    best = math.min(best, math.sqrt(ex * ex + ey * ey));
  }
  return best;
}
