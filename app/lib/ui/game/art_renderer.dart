/// O mapa do jogo em pixels de arte de tamanho fixo de TELA. A cada quadro a área visível é rasterizada
/// direto num buffer de baixa resolução alinhado à tela (cada pixel de arte ocupa um número inteiro de
/// pixels físicos, perto de `map.art_pixel_dp`) e ampliada por vizinho mais próximo. A nitidez é a mesma
/// em qualquer zoom e em qualquer ângulo: girar ou aproximar só muda o que se desenha no buffer.
///
/// Camadas, de baixo para cima: chão neutro com ruído; áreas verdes e água, com borda de 1 pixel de arte;
/// calçada; rua, com a largura da classe em metros. A Aura, as Fagulhas, os Ecos e o Conjurador são
/// desenhados por quem chama, por cima. Só desenho: a grade de biomas continua sendo a única camada lógica.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../data/visual_pack.dart';
import '../../world/map_balance.dart';
import '../../world/map_camera.dart';
import '../../world/visual_map.dart';
import 'art_style.dart';

/// Lado da textura de ruído, em pixels de arte.
const int noiseTexPx = 128;

/// Quantos pixels de arte de cada 100 levam ruído escuro e claro.
const int _noiseDarkPct = 7;
const int _noiseLightPct = 5;

/// Os caminhos de um tile, já montados em unidades do tile. Montados uma vez e guardados: a cada quadro só
/// muda a matriz com que são desenhados.
class _TileArt {
  _TileArt({this.green, this.water, required this.roads});

  final ui.Path? green;
  final ui.Path? water;

  /// Um caminho por classe de rua (na ordem de [RoadClass]), `null` se o tile não tem rua da classe.
  final List<ui.Path?> roads;
}

class ArtRenderer {
  ArtRenderer({required this.visual, required this.style, required this.balance, this.cacheTiles = 48}) {
    _groundNoise = _noiseTexture(style.ground, 1);
    _greenNoise = _noiseTexture(style.green, 2);
    _waterNoise = _noiseTexture(style.water, 3);
  }

  final VisualMap visual;
  final ArtStyle style;
  final MapBalance balance;
  final int cacheTiles;

  late final ui.Image _groundNoise;
  late final ui.Image _greenNoise;
  late final ui.Image _waterNoise;
  final LinkedHashMap<(int, int), _TileArt?> _art = LinkedHashMap();

  /// Tempo médio (média móvel) de rasterizar um quadro, em milissegundos. Quem chama pode usar para cair
  /// numa resolução mais baixa durante um gesto.
  double rasterMs = 0;

  /// O tamanho do pixel de arte no último quadro, em pixels físicos, e o tamanho do buffer.
  int lastPixelSize = 0;
  (int, int) lastBuffer = (0, 0);

  int get cachedTiles => _art.length;

  /// Pixels físicos por pixel de arte: o inteiro mais perto de `art_pixel_dp` dp, vezes [coarse].
  int pixelSize(double dpr, {int coarse = 1}) => math.max(1, (balance.artPixelDp * dpr).round()) * coarse;

  /// Desenha o mundo em [canvas], numa tela de [size] logical px e [dpr] pixels físicos por pixel lógico.
  /// [metersPerCell] vem da latitude (converte a largura das ruas em metros). Com [coarse] maior que 1 o
  /// pixel de arte fica [coarse] vezes maior: é o recurso para segurar o fps durante um gesto.
  void paint(ui.Canvas canvas, ui.Size size, MapCamera cam, {required double dpr, required double metersPerCell, int coarse = 1}) {
    final watch = Stopwatch()..start();
    final k = pixelSize(dpr, coarse: coarse);
    final lowW = (size.width * dpr / k).ceil(), lowH = (size.height * dpr / k).ceil();
    if (lowW <= 0 || lowH <= 0) return;
    lastPixelSize = k;
    lastBuffer = (lowW, lowH);

    final ppcLow = cam.pixelsPerCell * dpr / k; // pixels de arte por célula z21
    final ax = size.width * dpr / 2 / k, ay = size.height * dpr / 2 / k; // centro da tela no buffer
    final cosR = math.cos(cam.rotation), sinR = math.sin(cam.rotation);
    final low = ui.Rect.fromLTWH(0, 0, lowW.toDouble(), lowH.toDouble());

    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec, low);
    c.drawRect(low, ui.Paint()..color = style.ground.base..isAntiAlias = false);

    // Ruído do chão: textura que acompanha o mapa (desliza e gira com ele) mas não cresce com o zoom, para o
    // grão ter sempre o tamanho do pixel de arte. Ancorada numa célula perto do centro; só muda de âncora
    // a cada tile, longe o bastante para ninguém ver.
    final cpt = visual.cellsPerTile;
    final ox = (cam.centerX / cpt).floor() * cpt.toDouble(), oy = (cam.centerY / cpt).floor() * cpt.toDouble();
    final nx = ax + ((ox - cam.centerX) * ppcLow) * cosR - ((oy - cam.centerY) * ppcLow) * sinR;
    final ny = ay + ((ox - cam.centerX) * ppcLow) * sinR + ((oy - cam.centerY) * ppcLow) * cosR;
    final noiseMatrix = Float64List.fromList([cosR, sinR, 0, 0, -sinR, cosR, 0, 0, 0, 0, 1, 0, nx, ny, 0, 1]);
    ui.Paint noisePaint(ui.Image tex) => ui.Paint()
      ..shader = ui.ImageShader(tex, ui.TileMode.repeated, ui.TileMode.repeated, noiseMatrix, filterQuality: ui.FilterQuality.none)
      ..isAntiAlias = false;
    c.drawRect(low, noisePaint(_groundNoise));

    // Os tiles que a tela toca, com folga: as ruas passam ~0,6 célula da borda do tile vizinho.
    final (l, t, r, b) = cam.visibleBounds(size.width, size.height);
    final tiles = <(int, int, _TileArt)>[
      for (final id in visual.tilesIn(l, t, r, b, marginCells: 1))
        if (_artOf(id.$1, id.$2) case final art?) (id.$1, id.$2, art),
    ];

    final unit = cpt / visual.pack.extent; // células por unidade do tile
    final sc = ppcLow * unit; // pixels de arte por unidade do tile
    Float64List tileMatrix(int tx, int ty) {
      final dx = (tx * cpt - cam.centerX) * ppcLow, dy = (ty * cpt - cam.centerY) * ppcLow;
      return Float64List.fromList([sc * cosR, sc * sinR, 0, 0, -sc * sinR, sc * cosR, 0, 0, 0, 0, 1, 0, ax + dx * cosR - dy * sinR, ay + dx * sinR + dy * cosR, 0, 1]);
    }

    // Áreas: verde e depois água. Preenche, põe o ruído do material dentro e contorna com 1 pixel de arte.
    for (final kind in [AreaKind.green, AreaKind.water]) {
      final mat = kind == AreaKind.green ? style.green : style.water;
      final noise = noisePaint(kind == AreaKind.green ? _greenNoise : _waterNoise);
      final fill = ui.Paint()..color = mat.base..isAntiAlias = false;
      final edge = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1 / sc
        ..strokeJoin = ui.StrokeJoin.miter
        ..color = mat.edge
        ..isAntiAlias = false;
      for (final (tx, ty, art) in tiles) {
        final path = kind == AreaKind.green ? art.green : art.water;
        if (path == null) continue;
        final m = tileMatrix(tx, ty);
        c.save();
        c.transform(m);
        c.drawPath(path, fill);
        c.clipPath(path, doAntiAlias: false);
        c.transform(_inverse(m)); // de volta ao buffer, com o recorte da área: o ruído não gira com o tile
        c.drawRect(low, noise);
        c.restore();
        c.save();
        c.transform(m);
        c.drawPath(path, edge);
        c.restore();
      }
    }

    // Ruas: primeiro todas as calçadas, depois o asfalto, do mais estreito para o mais largo. A largura vem
    // em metros; a calçada é de 1 pixel de arte de cada lado e a trilha de pedestre não tem calçada.
    for (final sidewalks in [true, false]) {
      for (final cls in RoadClass.values.reversed) {
        final widthM = balance.roadWidthM[_roadKey(cls)] ?? 0;
        if (widthM <= 0 || (sidewalks && cls == RoadClass.pedestrian)) continue;
        final core = math.max(1.0, widthM / metersPerCell * ppcLow);
        final width = sidewalks ? core + 2 * balance.sidewalkArtPx : core;
        final paint = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = width / sc
          ..strokeCap = ui.StrokeCap.butt
          ..strokeJoin = ui.StrokeJoin.round
          ..color = (sidewalks || cls == RoadClass.pedestrian) ? style.sidewalk : style.asphalt
          ..isAntiAlias = false;
        for (final (tx, ty, art) in tiles) {
          final path = art.roads[cls.index];
          if (path == null) continue;
          c.save();
          c.transform(tileMatrix(tx, ty));
          c.drawPath(path, paint);
          c.restore();
        }
      }
    }

    final image = rec.endRecording().toImageSync(lowW, lowH);
    canvas.drawImageRect(
      image,
      low,
      ui.Rect.fromLTWH(0, 0, lowW * k / dpr, lowH * k / dpr),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..isAntiAlias = false,
    );
    image.dispose();
    rasterMs = rasterMs == 0 ? watch.elapsedMicroseconds / 1000 : rasterMs * 0.9 + watch.elapsedMicroseconds / 1000 * 0.1;
  }

  _TileArt? _artOf(int tx, int ty) {
    final key = (tx, ty);
    if (_art.containsKey(key)) {
      final a = _art.remove(key);
      _art[key] = a;
      return a;
    }
    final tile = visual.tile(tx, ty);
    final art = tile == null || tile.isEmpty ? null : _build(tile);
    _art[key] = art;
    while (_art.length > cacheTiles) {
      _art.remove(_art.keys.first);
    }
    return art;
  }

  /// Monta os caminhos de um tile. Cada área vira um anel externo com sentido positivo e buracos com sentido
  /// negativo, e o caminho do tile usa a regra não-zero: áreas que se sobrepõem se somam em vez de se anular.
  _TileArt _build(VisualTile tile) {
    ui.Path? area(AreaKind kind) {
      ui.Path? path;
      for (final a in tile.areas) {
        if (a.kind != kind) continue;
        path ??= ui.Path()..fillType = ui.PathFillType.nonZero;
        for (var i = 0; i < a.rings.length; i++) {
          final ring = a.rings[i];
          final positive = _signedArea(ring) > 0;
          final reverse = i == 0 ? !positive : positive; // contorno positivo, buraco negativo
          final n = ring.length ~/ 2;
          for (var j = 0; j < n; j++) {
            final p = reverse ? n - 1 - j : j;
            final x = ring[2 * p].toDouble(), y = ring[2 * p + 1].toDouble();
            j == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
          }
          path.close();
        }
      }
      return path;
    }

    final roads = List<ui.Path?>.filled(RoadClass.values.length, null);
    for (final line in tile.lines) {
      final path = roads[line.roadClass.index] ??= ui.Path();
      final xy = line.xy;
      path.moveTo(xy[0].toDouble(), xy[1].toDouble());
      for (var i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i].toDouble(), xy[i + 1].toDouble());
      }
    }
    return _TileArt(green: area(AreaKind.green), water: area(AreaKind.water), roads: roads);
  }

  static double _signedArea(Int32List ring) {
    var sum = 0.0;
    final n = ring.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      sum += ring[2 * i] * ring[2 * j + 1] - ring[2 * j] * ring[2 * i + 1];
    }
    return sum / 2;
  }

  static String _roadKey(RoadClass c) => switch (c) {
        RoadClass.principal => 'principal',
        RoadClass.secondary => 'secondary',
        RoadClass.local => 'local',
        RoadClass.pedestrian => 'pedestrian',
      };

  /// Inversa de uma matriz 4 x 4 que só tem parte afim 2D (as que este renderizador monta).
  static Float64List _inverse(Float64List m) {
    final a = m[0], b = m[1], c = m[4], d = m[5], tx = m[12], ty = m[13];
    final det = a * d - b * c;
    final ia = d / det, ib = -b / det, ic = -c / det, id = a / det;
    return Float64List.fromList([ia, ib, 0, 0, ic, id, 0, 0, 0, 0, 1, 0, -(ia * tx + ic * ty), -(ib * tx + id * ty), 0, 1]);
  }

  /// Textura de ruído de um material: pixels escuros e claros espalhados sobre transparente. Sempre a mesma,
  /// porque o gerador é semeado pelo material.
  ui.Image _noiseTexture(Material3 mat, int seed) {
    final rng = Pcg32(fnv1a64([seed, 0x4152544E]), saltKenoma); // ARTN
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    void specks(int pct, ui.Color color) {
      final n = noiseTexPx * noiseTexPx * pct ~/ 100;
      final pts = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        pts[2 * i] = rng.nextInt(noiseTexPx) + 0.5;
        pts[2 * i + 1] = rng.nextInt(noiseTexPx) + 0.5;
      }
      c.drawRawPoints(
        ui.PointMode.points,
        pts,
        ui.Paint()
          ..strokeWidth = 1
          ..strokeCap = ui.StrokeCap.square
          ..color = color
          ..isAntiAlias = false,
      );
    }

    specks(_noiseDarkPct, mat.dark);
    specks(_noiseLightPct, mat.light);
    return rec.endRecording().toImageSync(noiseTexPx, noiseTexPx);
  }

  void dispose() {
    _groundNoise.dispose();
    _greenNoise.dispose();
    _waterNoise.dispose();
    _art.clear();
  }
}
