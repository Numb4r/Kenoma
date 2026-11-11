/// A água da chuva no relevo (docs/GDD.md, "Simulações do mundo"): **é mundo**. Em cada tile z15, a chuva cai igual em
/// toda célula z21 e escorre em passos fixos para a vizinha mais baixa; as ruas são canais (o leito fica abaixo do
/// terreno), os bueiros tiram um pouco a cada passo conforme a classe da rua, e rios e lagos levam embora o que chega.
/// Onde a água para (as baixadas de verdade) ficam as poças; por onde passa muita água (fundo de vale, beira de córrego),
/// o Dilúvio alaga. As alturas e a água são inteiros, e as ruas vêm do pacote visual que a época fixa: dois aparelhos chegam
/// ao mesmo campo.
/// Dart puro.
library;

import 'dart:collection';
import 'dart:typed_data';

import '../core/water_model.dart';
import '../data/relief_pack.dart';
import '../data/visual_pack.dart';
import 'visual_map.dart';

export '../core/water_model.dart';

const int _rain = 1024, _n = 64;

class WaterTile {
  WaterTile(this.pool, this.flow, this.flood);

  /// Por célula z21 do tile (64 x 64): a água que ficou parada, a que passou, e o alagamento do Dilúvio (0 a 255).
  final Int32List pool, flow;
  final Uint8List flood;
}

typedef WaterSpot = ({int index, double x, double y, double depth});

class WaterField {
  WaterField({required this.relief, required this.visual, this.model = const WaterModel(), this.cacheTiles = 24});

  final ReliefSource relief;
  final VisualMap visual;
  final WaterModel model;
  final int cacheTiles;
  final LinkedHashMap<(int, int), WaterTile?> _tiles = LinkedHashMap();

  /// O campo do tile z15 ([tx], [ty]), ou `null` onde não há relevo (lá vale o sorteio antigo pela seed).
  WaterTile? tile(int tx, int ty) {
    final key = (tx, ty);
    if (_tiles.containsKey(key)) {
      final t = _tiles.remove(key);
      return _tiles[key] = t;
    }
    final t = _build(tx, ty);
    _tiles[key] = t;
    while (_tiles.length > cacheTiles) {
      _tiles.remove(_tiles.keys.first);
    }
    return t;
  }

  WaterTile? _build(int tx, int ty) {
    assert(visual.cellsPerTile == _n);
    final k = model.steps, w = _n + 2 * k, x0 = tx * _n - k, y0 = ty * _n - k;
    final h = Int32List(w * w), rank = Int8List(w * w)..fillRange(0, w * w, -1), sink = Uint8List(w * w);
    for (var y = 0; y < w; y++) {
      for (var x = 0; x < w; x++) {
        final v = relief.h16At(x0 + x, y0 + y);
        if (v == null) return null;
        h[y * w + x] = v;
      }
    }
    // As ruas e a água do pacote visual, nas células do domínio.
    final unit = _n / visual.pack.extent;
    for (final (ttx, tty) in visual.tilesIn(x0.toDouble(), y0.toDouble(), (x0 + w).toDouble(), (y0 + w).toDouble(), marginCells: 1)) {
      final vt = visual.tile(ttx, tty);
      if (vt == null) continue;
      final ox = ttx * _n - x0, oy = tty * _n - y0;
      for (final line in vt.lines) {
        final r = switch (line.roadClass) { RoadClass.pedestrian => 0, RoadClass.local => 1, RoadClass.secondary => 2, RoadClass.principal => 3 };
        for (var i = 0; i + 3 < line.xy.length; i += 2) {
          // Inteiros: o trecho amostrado em 1/8 de célula (as coordenadas do pacote já são inteiras).
          final ax = line.xy[i], ay = line.xy[i + 1], bx = line.xy[i + 2], by = line.xy[i + 3];
          final dx = (bx - ax).abs(), dy = (by - ay).abs();
          final steps = ((dx > dy ? dx : dy) * unit * 8).ceil() + 1;
          for (var s = 0; s <= steps; s++) {
            final cx = ((ax * (steps - s) + bx * s) * unit / steps).floor() + ox, cy = ((ay * (steps - s) + by * s) * unit / steps).floor() + oy;
            if (cx < 0 || cy < 0 || cx >= w || cy >= w) continue;
            if (r > rank[cy * w + cx]) rank[cy * w + cx] = r;
          }
        }
      }
      for (final a in vt.areas) {
        if (a.kind != AreaKind.water) continue;
        _fill(a.rings, unit, ox, oy, w, sink);
      }
    }
    const names = ['pedestrian', 'local', 'secondary', 'principal'];
    final carve = [for (final n in names) (model.carveDm[n] ?? 0) * 16], drain = [for (final n in names) model.drain256[n] ?? 0];
    for (var i = 0; i < w * w; i++) {
      if (rank[i] >= 0) h[i] -= carve[rank[i]];
    }
    // Para onde cada célula escoa: a vizinha mais baixa das oito (na ordem fixa N, L, S, O, NE, SE, SO, NO); -1 se nenhuma.
    final to = Int32List(w * w);
    const dxs = [0, 1, 0, -1, 1, 1, -1, -1], dys = [-1, 0, 1, 0, -1, 1, 1, -1];
    for (var y = 0; y < w; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        var best = h[i], at = -1;
        for (var d = 0; d < 8; d++) {
          final nx = x + dxs[d], ny = y + dys[d];
          if (nx < 0 || ny < 0 || nx >= w || ny >= w) continue;
          final j = ny * w + nx;
          if (h[j] < best) {
            best = h[j];
            at = j;
          }
        }
        to[i] = at;
      }
    }
    var cur = Int32List(w * w)..fillRange(0, w * w, _rain), next = Int32List(w * w);
    final through = Int32List(w * w);
    for (var s = 0; s < k; s++) {
      next.fillRange(0, w * w, 0);
      for (var i = 0; i < w * w; i++) {
        var v = cur[i];
        if (v == 0) continue;
        if (sink[i] != 0) continue; // rio ou lago: leva embora
        if (rank[i] > 0) v -= v * drain[rank[i]] >>> 8; // bueiro
        final j = to[i];
        if (j < 0) {
          next[i] += v; // baixada: fica
        } else {
          final half = v >>> 1; // metade segue, metade ainda está a caminho
          next[j] += half;
          next[i] += v - half;
          through[j] += half;
        }
      }
      final t = cur;
      cur = next;
      next = t;
    }
    final pool = Int32List(_n * _n), flow = Int32List(_n * _n);
    final flood = Uint8List(_n * _n);
    final rise = model.streamRiseDm * 16;
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final i = (y + k) * w + x + k, o = y * _n + x;
        // Onde a água se junta: a baixada (nenhuma vizinha mais baixa) ou o ponto com mais água que as 8 células em redor
        // (o pé de uma ladeira, a sarjeta no ponto baixo da rua). As poças de cada célula z17 são os maiores destes.
        var v = sink[i] == 0 ? cur[i] : 0;
        if (v > 0 && to[i] >= 0) {
          for (var dy = -1; dy <= 1 && v > 0; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final j = i + dy * w + dx;
              if (cur[j] > v || (cur[j] == v && j < i)) {
                v = 0;
                break;
              }
            }
          }
        }
        pool[o] = v;
        flow[o] = through[i];
        var f = through[i] <= model.floodFlow ? 0 : ((through[i] - model.floodFlow) * 255 ~/ (model.floodFull - model.floodFlow)).clamp(0, 255);
        // A margem: até três células de um rio ou lago e pouco acima dele.
        if (f < 255 && sink[i] == 0) {
          for (var dy = -3; dy <= 3 && f < 255; dy++) {
            for (var dx = -3; dx <= 3; dx++) {
              final j = i + dy * w + dx;
              if (sink[j] != 0 && h[i] - h[j] <= rise) {
                f = 255;
                break;
              }
            }
          }
        }
        flood[o] = f;
      }
    }
    return WaterTile(pool, flow, flood);
  }

  /// Marca em [out] as células cujo centro cai dentro dos anéis (par-ímpar), por varredura.
  static void _fill(List<Int32List> rings, double unit, int ox, int oy, int w, Uint8List out) {
    final xs = <double>[];
    for (var y = 0; y < w; y++) {
      final py = (y - oy + 0.5) / unit;
      xs.clear();
      for (final r in rings) {
        for (var i = 0, j = r.length - 2; i < r.length; j = i, i += 2) {
          final ay = r[i + 1], by = r[j + 1];
          if ((ay > py) != (by > py)) xs.add(r[i] + (py - ay) / (by - ay) * (r[j] - r[i]));
        }
      }
      if (xs.length < 2) continue;
      xs.sort();
      for (var q = 0; q + 1 < xs.length; q += 2) {
        final a = (xs[q] * unit + ox - 0.5).ceil(), b = (xs[q + 1] * unit + ox - 0.5).floor();
        for (var x = a < 0 ? 0 : a; x <= b && x < w; x++) {
          out[y * w + x] = 1;
        }
      }
    }
  }

  int _at(int cx, int cy, Int32List Function(WaterTile) f) {
    final t = tile(cx >>> 6, cy >>> 6);
    return t == null ? 0 : f(t)[(cy & 63) * _n + (cx & 63)];
  }

  /// A água parada e a que passou na célula z21 (0 sem relevo).
  int poolAt(int cx, int cy) => _at(cx, cy, (t) => t.pool);
  int flowAt(int cx, int cy) => _at(cx, cy, (t) => t.flow);

  /// Quanto o Dilúvio alaga a célula z21, de 0 a 1 (`null` sem relevo: vale o sorteio antigo).
  double? floodAt(int cx, int cy) {
    final t = tile(cx >>> 6, cy >>> 6);
    return t == null ? null : t.flood[(cy & 63) * _n + (cx & 63)] / 255;
  }

  final Map<(int, int, int), bool?> _lineFlood = {};

  /// A rua (tile z15 e índice da linha no pacote visual) alaga no Dilúvio: pelo menos um terço dela passa por células
  /// alagadas. `null` sem relevo no lugar (vale o sorteio antigo pela seed).
  bool? lineFloods(int tx, int ty, int i) => _lineFlood.putIfAbsent((tx, ty, i), () {
        final line = visual.tile(tx, ty)?.lines.elementAtOrNull(i);
        if (line == null || line.xy.length < 4) return false;
        final unit = _n / visual.pack.extent;
        var wet = 0, all = 0;
        for (var k = 0; k + 3 < line.xy.length; k += 2) {
          final ax = line.xy[k], ay = line.xy[k + 1], bx = line.xy[k + 2], by = line.xy[k + 3];
          final dx = (bx - ax).abs(), dy = (by - ay).abs();
          final steps = ((dx > dy ? dx : dy) * unit).ceil() + 1;
          for (var s = 0; s <= steps; s++) {
            final f = floodAt(tx * _n + ((ax * (steps - s) + bx * s) * unit / steps).floor(), ty * _n + ((ay * (steps - s) + by * s) * unit / steps).floor());
            if (f == null) return null;
            all++;
            if (f >= 0.5) wet++;
          }
        }
        return wet * 3 >= all;
      });

  /// As [n] poças da célula z17 ([cx17], [cy17]): onde mais água parou, da mais funda para a mais rasa (empate: a ordem das
  /// células). `depth` vai de 0 a 1 em relação à mais funda. `null` sem relevo; vazia se a água não para em lugar nenhum.
  List<WaterSpot>? spots(int cx17, int cy17, int n) {
    final t = tile(cx17 >>> 2, cy17 >>> 2);
    if (t == null) return null;
    final bx = (cx17 & 3) * 16, by = (cy17 & 3) * 16;
    final found = <(int, int)>[];
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final v = t.pool[(by + y) * _n + bx + x];
        if (v >= model.poolMin) found.add((v, y * 16 + x));
      }
    }
    found.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    return [
      for (final (i, (v, at)) in found.take(n).indexed)
        (index: i, x: cx17 * 16 + (at & 15) + 0.5, y: cy17 * 16 + (at >>> 4) + 0.5, depth: v / found.first.$1),
    ];
  }
}
