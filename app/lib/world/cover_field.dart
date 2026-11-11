/// A cobertura do clima como um campo por pixel (docs/clima-auditoria.md, "Cobertura por campo"): neve, gelo, fuligem e a
/// água do Dilúvio. Cada bloco do mapa ([coverBlockCells] células z21 de lado) rasteriza todas as ruas, calçadas e caminhos
/// numa máscara única (a união das formas: cruzamentos e vielas não têm pontas sobrepostas) e, por cima dela, um campo de
/// profundidade em forma fechada: função da fase do clima (o tempo desde o começo, igual em todos os aparelhos), da
/// superfície, do vento e do ruído preso ao chão. A cor sai da profundidade em faixas e as bordas de um limiar com
/// pontilhado ordenado, em pixel, sem contorno. Dart puro.
///
/// Só as trilhas do tráfego ([CoverStreet.wear]) são locais: vêm da simulação do tráfego deste aparelho.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'climate_form.dart';
import 'street_cover.dart' show StreetCoverKind;

/// Pixels do campo por célula z21 (~0,55 m cada) e o lado do bloco, em células e em pixels.
const int coverRes = 32, coverBlockCells = 4, coverSize = coverRes * coverBlockCells;

/// As superfícies da máscara, na ordem em que a neve chega: a grama e o chão (com os telhados) primeiro, depois as
/// calçadas, os caminhos, as ruas locais e por último as avenidas. Na água não acumula nada.
enum CoverSurface { water, green, ground, sidewalk, path, local, secondary, principal }

/// Uma rua que toca o bloco: pontos em células z21, meia largura em metros, a classe (0 caminho de pedestre, 1 local,
/// 2 secundária, 3 principal), quanto a cobertura a pega (0 a 1; alagamento, fuligem) e o desgaste do tráfego local (0 a 1).
class CoverStreet {
  const CoverStreet(this.xy, this.halfWidthM, this.rank, {this.level = 1, this.wear = 0});

  final List<double> xy;
  final double halfWidthM;
  final int rank;
  final double level, wear;
}

class CoverInput {
  const CoverInput({
    required this.bx,
    required this.by,
    required this.mpc,
    required this.kind,
    required this.amount,
    required this.seed,
    this.streets = const [],
    this.green = const [],
    this.water = const [],
    this.peak = 1,
    this.melting = false,
    this.windX = 0,
    this.windY = 0,
    this.sunX = -0.7,
    this.sunY = -0.7,
    this.color = 0xFFFFFFFF,
    this.alpha = 1,
  });

  /// O bloco: começa na célula `(bx, by) * coverBlockCells`.
  final int bx, by;
  final double mpc;
  final StreetCoverKind kind;

  /// Quanto da cobertura se formou (0 a 1, `climate_form.dart`), o máximo a que chegou e se já está derretendo.
  final double amount, peak;
  final bool melting;
  final int seed;
  final List<CoverStreet> streets;

  /// Os anéis das áreas verdes e da água (pares x, y em células z21; par-ímpar).
  final List<List<double>> green, water;

  /// Para onde o vento sopra e de onde vem o sol (vetores unitários, x leste, y sul).
  final double windX, windY, sunX, sunY;

  /// Gelo, fuligem e água: a cor (ARGB) e a opacidade da camada.
  final int color;
  final double alpha;
}

class CoverBlock {
  CoverBlock(this.surface, this.edge, this.depth, this.rgba);

  /// A superfície de cada pixel (índice de [CoverSurface]).
  final Uint8List surface;

  /// Distância à borda da união das ruas, em metros: negativa dentro, positiva fora.
  final Float32List edge;

  /// Profundidade da cobertura (neve: 0 a ~1,6; as outras: 0 a 1).
  final Float32List depth;

  /// A imagem do bloco, RGBA com alfa pré-multiplicado, [coverSize] por [coverSize].
  final Uint8List rgba;

  int get painted {
    var n = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 0) n++;
    }
    return n;
  }
}

/// Pontilhado ordenado 4x4 (Bayer), preso ao chão: o limiar de 0 a 1 do pixel global ([gx], [gy]).
double coverDither(int gx, int gy) => (_bayer[(gy & 3) * 4 + (gx & 3)] + 0.5) / 16;

const List<int> _bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

double _hash(int x, int y, int seed) {
  var h = (x * 0x27D4EB2D) ^ (y * 0x165667B1) ^ seed;
  h = (h ^ (h >>> 15)) * 0x2C1B3C6D & 0xFFFFFFFF;
  h = (h ^ (h >>> 12)) * 0x297A2D39 & 0xFFFFFFFF;
  return ((h ^ (h >>> 15)) & 0xFFFF) / 65536;
}

/// Ruído de valor suave (0 a 1) nas coordenadas ([x], [y]) de uma grade de passo 1.
double _noise(double x, double y, int seed) {
  final ix = x.floor(), iy = y.floor();
  var fx = x - ix, fy = y - iy;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  final a = _hash(ix, iy, seed), b = _hash(ix + 1, iy, seed), c = _hash(ix, iy + 1, seed), d = _hash(ix + 1, iy + 1, seed);
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

/// O mesmo ruído de [_noise] para um bloco inteiro: os valores da grade são sorteados uma vez e cada pixel só interpola.
class _Lattice {
  _Lattice(this.gx0, this.gy0, this.period, int seed) {
    ix0 = (gx0 / period).floor();
    iy0 = (gy0 / period).floor();
    w = ((gx0 + coverSize) / period).floor() - ix0 + 2;
    final h = ((gy0 + coverSize) / period).floor() - iy0 + 2;
    v = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        v[y * w + x] = _hash(ix0 + x, iy0 + y, seed);
      }
    }
  }

  final int gx0, gy0;
  final double period;
  late final int ix0, iy0, w;
  late final Float32List v;

  double at(int px, int py) {
    final x = (gx0 + px) / period, y = (gy0 + py) / period;
    final ix = x.floor(), iy = y.floor();
    var fx = x - ix, fy = y - iy;
    fx = fx * fx * (3 - 2 * fx);
    fy = fy * fy * (3 - 2 * fy);
    final i = (iy - iy0) * w + ix - ix0;
    final a = v[i], b = v[i + 1], c = v[i + w], d = v[i + w + 1];
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }
}

/// Os limiares da fase em que a neve começa e acaba de cobrir cada superfície (a ordem de [CoverSurface]).
const List<(double, double)> snowStageOf = [(2, 3), (0.08, 0.40), (0.18, 0.55), (0.32, 0.66), (0.42, 0.74), (0.52, 0.82), (0.62, 0.90), (0.72, 0.98)];

/// A profundidade da neve numa superfície lisa, sem ruído, tráfego nem vento: forma fechada da fase [amount].
double snowBaseDepth(CoverSurface s, double amount) {
  final (a, b) = snowStageOf[s.index];
  return stage(amount, a, b) * (s.index >= CoverSurface.path.index ? 0.7 : (s == CoverSurface.sidewalk ? 0.85 : 1.0));
}

/// Quanto de banco de neve há no meio-fio: cresce quando as ruas já têm neve para o tráfego empurrar e, no degelo, é o
/// último a sumir (as ruas limpam antes).
double snowBankAmount(double amount, double peak, bool melting) {
  if (!melting) return stage(amount, 0.56, 0.9);
  final top = stage(peak, 0.56, 0.9);
  return top * stage(amount, 0.22 * peak, 0.6 * peak);
}

const double _sidewalkM = 1.6, _bankM = 2.2, _ditherM = 1.1;
const int _snow = 0xE9EEF8, _snowShadow = 0xA9B5CF, _snowLight = 0xFFFFFF, _slush = 0xB9BECE, _slushDark = 0x5E6478;

/// Monta o bloco: a máscara única, o campo de profundidade e a imagem.
CoverBlock buildCover(CoverInput c) {
  const n = coverSize;
  final surface = Uint8List(n * n)..fillRange(0, n * n, CoverSurface.ground.index);
  final edge = Float32List(n * n)..fillRange(0, n * n, 99);
  final depth = Float32List(n * n);
  final cdist = Float32List(n * n)..fillRange(0, n * n, 99); // distância ao eixo da rua mais próxima que cobre o pixel
  final lat = Float32List(n * n), wear = Float32List(n * n), lvl = Float32List(n * n), cov = Float32List(n * n);
  final rank = Int8List(n * n)..fillRange(0, n * n, -1);
  if (c.kind != StreetCoverKind.snow) cov.fillRange(0, n * n, 99);
  final x0 = c.bx * coverBlockCells, y0 = c.by * coverBlockCells;
  final tm = c.mpc / coverRes; // metros por pixel
  final snow = c.kind == StreetCoverKind.snow;

  // Áreas (verde e água) por varredura par-ímpar.
  void fill(List<List<double>> rings, CoverSurface s) {
    if (rings.isEmpty) return;
    final xs = <double>[];
    for (var py = 0; py < n; py++) {
      final y = y0 + (py + 0.5) / coverRes;
      xs.clear();
      for (final r in rings) {
        for (var i = 0, j = r.length - 2; i < r.length; j = i, i += 2) {
          final ay = r[i + 1], by = r[j + 1];
          if ((ay > y) != (by > y)) xs.add(r[i] + (y - ay) / (by - ay) * (r[j] - r[i]));
        }
      }
      if (xs.length < 2) continue;
      xs.sort();
      for (var k = 0; k + 1 < xs.length; k += 2) {
        final a = math.max(0, ((xs[k] - x0) * coverRes - 0.5).ceil()), b = math.min(n - 1, ((xs[k + 1] - x0) * coverRes - 0.5).floor());
        for (var px = a; px <= b; px++) {
          surface[py * n + px] = s.index;
        }
      }
    }
  }

  fill(c.green, CoverSurface.green);
  fill(c.water, CoverSurface.water);

  // A máscara única das ruas: cada pixel guarda a menor distância à borda de qualquer rua (a união) e a maior classe que
  // o cobre. Nada é desenhado por rua: cruzamentos e pontas não se somam.
  final reachM = _sidewalkM + _bankM + _ditherM;
  for (final st in c.streets) {
    final hw = st.halfWidthM;
    // A água sobe: estreita no começo, de borda a borda no fim.
    final cover = c.kind == StreetCoverKind.flood ? hw * (0.6 + 0.55 * st.level) : (c.kind == StreetCoverKind.soot ? hw * 1.2 : hw);
    final pad = (hw + reachM) / tm, pad2 = pad * pad;
    for (var k = 0; k + 3 < st.xy.length; k += 2) {
      final ax = (st.xy[k] - x0) * coverRes, ay = (st.xy[k + 1] - y0) * coverRes;
      final bx = (st.xy[k + 2] - x0) * coverRes, by = (st.xy[k + 3] - y0) * coverRes;
      final px0 = math.max(0, (math.min(ax, bx) - pad).floor()), px1 = math.min(n - 1, (math.max(ax, bx) + pad).ceil());
      final py0 = math.max(0, (math.min(ay, by) - pad).floor()), py1 = math.min(n - 1, (math.max(ay, by) + pad).ceil());
      if (px0 > px1 || py0 > py1) continue;
      final ex = bx - ax, ey = by - ay, len2 = ex * ex + ey * ey;
      for (var py = py0; py <= py1; py++) {
        for (var px = px0; px <= px1; px++) {
          final qx = px + 0.5 - ax, qy = py + 0.5 - ay;
          final u = len2 <= 0 ? 0.0 : ((qx * ex + qy * ey) / len2).clamp(0.0, 1.0);
          final dx = qx - ex * u, dy = qy - ey * u;
          final d2 = dx * dx + dy * dy;
          if (d2 > pad2) continue;
          final dist = math.sqrt(d2) * tm;
          final i = py * n + px, d = dist - hw;
          if (d < edge[i]) edge[i] = d;
          if (d <= 0) {
            if (st.rank > rank[i]) rank[i] = st.rank;
            if (dist < cdist[i]) {
              cdist[i] = dist;
              lat[i] = dist / hw;
              wear[i] = st.wear;
            }
          }
          if (!snow && st.level > 0 && dist - cover < cov[i]) {
            cov[i] = dist - cover; // a distância à borda da cobertura mais próxima (a união, de novo)
            lvl[i] = st.level;
          }
        }
      }
    }
  }
  for (var i = 0; i < n * n; i++) {
    if (rank[i] >= 0) {
      surface[i] = CoverSurface.path.index + rank[i];
    } else if (edge[i] <= _sidewalkM && surface[i] != CoverSurface.water.index) {
      surface[i] = CoverSurface.sidewalk.index;
    }
  }

  final rgba = Uint8List(n * n * 4);
  void put(int i, int rgb, double a) {
    final al = a.clamp(0.0, 1.0);
    rgba[i * 4] = (((rgb >>> 16) & 0xff) * al).round();
    rgba[i * 4 + 1] = (((rgb >>> 8) & 0xff) * al).round();
    rgba[i * 4 + 2] = ((rgb & 0xff) * al).round();
    rgba[i * 4 + 3] = (al * 255).round();
  }

  final gx0 = x0 * coverRes, gy0 = y0 * coverRes;
  if (!snow) {
    // Gelo, fuligem e água: um limiar sobre a cobertura da máscara, com o pontilhado ordenado na borda.
    final rgb = c.color & 0xFFFFFF;
    final wob = _Lattice(gx0, gy0, 7, c.seed ^ 0x30B);
    final soot = c.kind == StreetCoverKind.soot ? _Lattice(gx0, gy0, 5, c.seed ^ 0x5007) : null;
    for (var py = 0; py < n; py++) {
      for (var px = 0; px < n; px++) {
        final i = py * n + px;
        if (cov[i] > 3 || surface[i] == CoverSurface.water.index) continue;
        final th = coverDither(gx0 + px, gy0 + py);
        // A borda não segue a régua da rua: um ruído preso ao chão a entorta (sem tubo, sem ponta redonda nem corte reto),
        // e o pontilhado a desfaz. No começo a cobertura é rala.
        var cv = (0.5 - (cov[i] + (wob.at(px, py) - 0.5) * 2.8) / _ditherM).clamp(0.0, 1.0) * math.min(1.0, c.amount * 4);
        if (soot != null) cv *= 0.7 + 0.5 * soot.at(px, py);
        if (cv <= th) continue;
        final lv = c.kind == StreetCoverKind.flood ? lvl[i] : c.amount;
        depth[i] = lv;
        put(i, rgb, c.alpha * (c.kind == StreetCoverKind.flood ? 0.4 + 0.6 * lv : lv));
      }
    }
    return CoverBlock(surface, edge, depth, rgba);
  }

  // Neve. A profundidade de cada pixel, em forma fechada da fase.
  final bank = snowBankAmount(c.amount, c.peak, c.melting);
  final wl = math.sqrt(c.windX * c.windX + c.windY * c.windY);
  final wx = wl <= 0 ? 0.0 : c.windX / wl, wy = wl <= 0 ? 0.0 : c.windY / wl;
  final l1 = _Lattice(gx0, gy0, 9, c.seed), l2 = _Lattice(gx0, gy0, 4, c.seed ^ 0xBA4C), l3 = _Lattice(gx0, gy0, 13, c.seed ^ 0x307D);
  for (var py = 0; py < n; py++) {
    for (var px = 0; px < n; px++) {
      final i = py * n + px, s = surface[i];
      if (s == CoverSurface.water.index) continue;
      final gx = gx0 + px, gy = gy0 + py;
      final n1 = l1.at(px, py);
      // A neve da calçada avança sobre a beirada da rua de um jeito irregular: a borda não é a régua da rua.
      final kerb = s >= CoverSurface.path.index && edge[i] > -(0.2 + 1.7 * l2.at(px, py));
      final (a, b) = snowStageOf[kerb ? CoverSurface.sidewalk.index : s];
      var d = stage(c.amount + (n1 - 0.5) * 0.14, a, b);
      if (kerb) {
        d *= 0.85;
      } else if (s >= CoverSurface.path.index) {
        d *= 0.7;
        final r = s - CoverSurface.path.index;
        if (r > 0) {
          // O tráfego limpa as faixas: duas trilhas nas avenidas, uma no meio das ruas locais; mais onde os carros
          // deste aparelho passaram de verdade.
          final l = lat[i], t = r == 1 ? l / 0.38 : (l - 0.5) / 0.3;
          final track = math.max(0.0, 1 - t * t);
          final clear = (r == 3 ? 0.85 : r == 2 ? 0.65 : 0.22) * track * (0.45 + 0.55 * wear[i]);
          d *= 1 - clear;
          lvl[i] = clear; // a sujeira
        }
      } else {
        if (s == CoverSurface.sidewalk.index) d *= 0.85;
        // Montes baixos (a sombra do lado oposto ao sol dá o relevo) e, com vento, faixas compridas na direção dele.
        d *= 0.82 + 0.36 * l3.at(px, py);
        if (wl > 0) d *= 0.9 + 0.2 * _noise((gx * wx + gy * wy) / 60, (gy * wx - gx * wy) / 12, c.seed ^ 0x717D);
      }
      depth[i] = d;
    }
  }
  if (bank > 0) {
    for (var py = 0; py < n; py++) {
      for (var px = 0; px < n; px++) {
        final i = py * n + px, e = edge[i];
        if (e > _bankM || e < -0.9 || surface[i] == CoverSurface.water.index) continue;
        // O banco fica no meio-fio: alto na borda da rua, caindo para a calçada; e um pouco para dentro da sarjeta.
        final shape = e >= 0 ? math.pow(1 - e / _bankM, 0.8).toDouble() : 1 + e / 0.9;
        // O gradiente da distância aponta para fora da rua: o banco do lado para onde o vento sopra fica mais alto.
        final ex = edge[py * n + math.min(n - 1, px + 1)] - edge[py * n + math.max(0, px - 1)];
        final ey = edge[math.min(n - 1, py + 1) * n + px] - edge[math.max(0, py - 1) * n + px];
        final el = math.sqrt(ex * ex + ey * ey);
        final lee = el <= 0 ? 0.0 : math.max(0.0, (ex * wx + ey * wy) / el);
        final n2 = l2.at(px, py);
        depth[i] += bank * shape * 0.75 * (0.8 + 0.4 * n2) * (1 + 0.8 * lee);
      }
    }
  }
  // A cor por faixas de profundidade; a borda é o limiar com o pontilhado; a sombra fica do lado oposto ao sol.
  final sx = (c.sunX * 2).round(), sy = (c.sunY * 2).round();
  for (var py = 0; py < n; py++) {
    for (var px = 0; px < n; px++) {
      final i = py * n + px, d = depth[i];
      if (d <= 0.02) continue;
      final th = coverDither(gx0 + px, gy0 + py);
      // Neve fina: o pontilhado deixa ver o chão; some de vez abaixo do limiar.
      if (d < 0.34 && (d - 0.04) / 0.30 <= th) continue;
      final street = surface[i] > CoverSurface.path.index && edge[i] <= -(0.2 + 1.7 * l2.at(px, py));
      final toSun = depth[(py + sy).clamp(0, n - 1) * n + (px + sx).clamp(0, n - 1)];
      final slope = d - toSun; // negativo: o vizinho do lado do sol é mais alto e faz sombra aqui
      int rgb;
      if (street) {
        final dirt = lvl[i];
        rgb = dirt > 0.25 + 0.3 * th ? _slushDark : _slush;
        if (d > 0.85) rgb = _snow; // o banco que avançou sobre a sarjeta
      } else {
        rgb = d + (th - 0.5) * 0.2 > 0.95 ? _snowLight : _snow;
      }
      if (slope < (street ? -0.16 : -0.035) - 0.05 * th) {
        rgb = street && d <= 0.85 ? _slushDark : _snowShadow;
      } else if (slope > 0.05 + 0.06 * th && !street) {
        rgb = _snowLight;
      }
      put(i, rgb, c.alpha);
    }
  }
  return CoverBlock(surface, edge, depth, rgba);
}
