/// Tráfego do Véu ambiente (docs/GDD.md, "Mapa vivo"): carros e pedestres fantasmas que circulam pelas ruas reais.
/// Só visual: nada aqui é spawn, coleta nem Aura. Cada fantasma sai de `hash(seed, tile, linha, janela)`, então o
/// grupo vê o mesmo tráfego na mesma hora; a densidade segue a hora real do lugar (cheio no rush, vazio de
/// madrugada) e os carros respeitam a mão única do OSM e andam pela direita. Dart puro.
library;

import 'dart:math' as math;

import '../core/fnv.dart';
import '../core/pcg32.dart';
import '../data/visual_pack.dart';

/// Quanto dura uma janela de tráfego, em segundos. Dentro dela o conjunto de fantasmas de uma rua não muda.
const int trafficWindowS = 1200;

/// Quanto os fantasmas aparecem e somem no começo e no fim da janela, e nas pontas da rua (no máximo [_fadeEndM], e
/// um quarto do trecho nos curtos: o pacote parte as ruas em trechos de dezenas de metros).
const double _fadeS = 8;
const double _fadeEndM = 15;

/// Espaço vazio depois do fim da rua antes de o fantasma reaparecer no começo, em metros (no máximo [_loopGapM], e
/// metade do trecho nos curtos).
const double _loopGapM = 60;

enum GhostKind { car, pedestrian }

/// Uma polilinha do pacote visual pronta para o tráfego: pontos em células z21 e o comprimento acumulado.
class GhostLine {
  GhostLine({required this.key, required this.roadClass, required this.oneway, required this.xy, required this.cum})
      : lengthCells = cum.last {
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < xy.length; i += 2) {
      x0 = math.min(x0, xy[i]);
      x1 = math.max(x1, xy[i]);
      y0 = math.min(y0, xy[i + 1]);
      y1 = math.max(y1, xy[i + 1]);
    }
    minX = x0;
    minY = y0;
    maxX = x1;
    maxY = y1;
  }

  /// Retângulo que contém a rua, em células, para descartar rápido o que está fora da tela.
  late final double minX, minY, maxX, maxY;

  /// Identifica a rua na geração: tile e índice da linha dentro dele.
  final (int, int, int) key;
  final RoadClass roadClass;
  final OneWay oneway;

  /// Pontos `x0, y0, x1, y1, ...` em células z21 fracionárias.
  final List<double> xy;

  /// Comprimento acumulado até cada ponto, em células.
  final List<double> cum;
  final double lengthCells;

  bool get isPedestrian => roadClass == RoadClass.pedestrian;
}

/// As linhas de tráfego de um tile: cada polilinha com duas ou mais pontas distintas.
List<GhostLine> ghostLinesOfTile(VisualTile tile, int tx, int ty, {required int cellsPerTile, required int extent}) {
  final unit = cellsPerTile / extent;
  final out = <GhostLine>[];
  for (var i = 0; i < tile.lines.length; i++) {
    final l = tile.lines[i];
    final n = l.xy.length ~/ 2;
    if (n < 2) continue;
    final xy = <double>[], cum = <double>[0.0];
    for (var k = 0; k < n; k++) {
      xy
        ..add(tx * cellsPerTile + l.xy[2 * k] * unit)
        ..add(ty * cellsPerTile + l.xy[2 * k + 1] * unit);
      if (k > 0) {
        final dx = xy[2 * k] - xy[2 * k - 2], dy = xy[2 * k + 1] - xy[2 * k - 1];
        cum.add(cum.last + math.sqrt(dx * dx + dy * dy));
      }
    }
    if (cum.last <= 0) continue;
    out.add(GhostLine(key: (tx, ty, i), roadClass: l.roadClass, oneway: l.oneway, xy: xy, cum: cum));
  }
  return out;
}

/// A hora local média do lugar, de 0 a 24: o instante UTC mais a longitude (15° por hora). Determinística: não usa o
/// fuso do aparelho, então o grupo inteiro vê a mesma hora.
double localHour(int utcSeconds, double lonDeg) {
  final h = ((utcSeconds % 86400) / 3600 + lonDeg / 15) % 24;
  return h < 0 ? h + 24 : h;
}

double _bump(double h, double center, double width) {
  var d = (h - center).abs();
  if (d > 12) d = 24 - d;
  return math.exp(-(d * d) / (2 * width * width));
}

/// Densidade do tráfego de carros pela hora local, de 0,05 (madrugada) a 1 (rush das 8 e das 18).
double carDensity(double hour) => (0.05 + 0.7 * _bump(hour, 8, 1.3) + 0.7 * _bump(hour, 18, 1.5) + 0.3 * _bump(hour, 13, 3.5) + 0.12 * _bump(hour, 22, 1.8)).clamp(0.05, 1.0);

/// Densidade dos pedestres: sobe no almoço e no fim da tarde, quase some de madrugada.
double pedestrianDensity(double hour) => (0.03 + 0.35 * _bump(hour, 9, 1.5) + 0.5 * _bump(hour, 12.5, 1.6) + 0.55 * _bump(hour, 18, 1.8) + 0.15 * _bump(hour, 21, 1.5)).clamp(0.03, 1.0);

/// Fantasmas por 100 m de rua com a densidade em 1, por classe: as avenidas enchem mais que as ruas calmas.
double _ratePer100m(RoadClass c) => switch (c) {
      RoadClass.principal => 3.5,
      RoadClass.secondary => 2.4,
      RoadClass.local => 1.2,
      RoadClass.pedestrian => 1.0,
    };

/// Velocidade em m/s de um fantasma, sorteada na faixa da classe.
(double, double) _speedRange(RoadClass c) => switch (c) {
      RoadClass.principal => (9.0, 14.0),
      RoadClass.secondary => (6.0, 10.0),
      RoadClass.local => (3.5, 7.0),
      RoadClass.pedestrian => (1.1, 1.7),
    };

class Ghost {
  const Ghost({required this.kind, required this.x, required this.y, required this.heading, required this.alpha, required this.lengthM, required this.seed});

  final GhostKind kind;

  /// Posição em células z21 fracionárias, já com o deslocamento da faixa.
  final double x;
  final double y;

  /// Direção em radianos (x leste, y sul; horário na tela).
  final double heading;

  /// 0 a 1: nasce e some suave, no começo e no fim da janela e nas pontas da rua.
  final double alpha;

  /// Comprimento do corpo, em metros: o carro e o pedestre têm tamanhos diferentes.
  final double lengthM;

  /// Sorteio estável do fantasma (para variar a cor sem piscar).
  final int seed;
}

/// Quantos fantasmas a [line] tem na janela [window]: o esperado (densidade × taxa × comprimento) com a parte
/// fracionária sorteada, então as ruas não ficam todas iguais.
int ghostCount(GhostLine line, int seed, int window, double hour, double metersPerCell) {
  final lenM = line.lengthCells * metersPerCell;
  final dens = line.isPedestrian ? pedestrianDensity(hour) : carDensity(hour);
  final expected = dens * _ratePer100m(line.roadClass) * lenM / 100;
  final rng = Pcg32(fnv1a64([seed, line.key.$1, line.key.$2, line.key.$3, window, saltTraf]), saltKenoma);
  final n = expected.floor() + (rng.nextFloat() < expected - expected.floor() ? 1 : 0);
  return math.min(n, 8);
}

/// Os fantasmas da [line] no instante [tUtc]. Cada um anda `velocidade × tempo` desde o começo da janela, dando
/// a volta (com um vazio no fim) para o fluxo não parar. O sentido vem do OSM: mão única fixa; mão dupla sorteia
/// e o carro anda pela direita da pista.
List<Ghost> ghostsOn(GhostLine line, {required int seed, required int tUtc, required double hour, required double metersPerCell}) {
  final window = tUtc ~/ trafficWindowS;
  final n = ghostCount(line, seed, window, hour, metersPerCell);
  if (n == 0) return const [];
  final rng = Pcg32(fnv1a64([seed, line.key.$1, line.key.$2, line.key.$3, window, saltTraf, 1]), saltKenoma);
  final lenM = line.lengthCells * metersPerCell;
  final loopM = lenM + math.min(_loopGapM, lenM * 0.5);
  final into = (tUtc - window * trafficWindowS).toDouble();
  final fadeWindow = math.min(1.0, math.min(into / _fadeS, (trafficWindowS - into) / _fadeS));
  final (vLo, vHi) = _speedRange(line.roadClass);
  final out = <Ghost>[];
  for (var i = 0; i < n; i++) {
    final speed = vLo + (vHi - vLo) * rng.nextFloat();
    final start = rng.nextFloat() * loopM;
    final dirDraw = rng.nextFloat();
    final tag = rng.next();
    final forward = switch (line.oneway) {
      OneWay.forward => true,
      OneWay.reverse => false,
      OneWay.twoWay => dirDraw < 0.5,
    };
    var along = (start + speed * into) % loopM; // distância andada no sentido do movimento
    if (along > lenM) continue; // no vazio do fim da rua: ainda não voltou
    final s = forward ? along : lenM - along; // posição ao longo da linha, no sentido dos pontos
    final edge = math.min(along, lenM - along);
    final fade = fadeWindow * math.min(1.0, edge / math.min(_fadeEndM, lenM * 0.25));
    if (fade <= 0.01) continue;
    final p = _pointAt(line, s / metersPerCell);
    var heading = p.heading;
    if (!forward) heading += math.pi;
    var x = p.x, y = p.y;
    if (!line.isPedestrian && line.oneway == OneWay.twoWay) {
      // Mão dupla: anda pela direita (no Brasil), deslocado 1,5 m do eixo. A direita de quem vai a leste é o sul (y+).
      final off = 1.5 / metersPerCell;
      x += -math.sin(heading) * off;
      y += math.cos(heading) * off;
    } else if (line.isPedestrian) {
      final off = (rng.nextFloat() - 0.5) * 1.2 / metersPerCell; // calçada larga: espalha um pouco
      x += -math.sin(heading) * off;
      y += math.cos(heading) * off;
    }
    out.add(Ghost(kind: line.isPedestrian ? GhostKind.pedestrian : GhostKind.car, x: x, y: y, heading: heading, alpha: fade, lengthM: line.isPedestrian ? 0.8 : 4.2, seed: tag));
  }
  return out;
}

({double x, double y, double heading}) _pointAt(GhostLine line, double cells) {
  final c = cells.clamp(0.0, line.lengthCells);
  var lo = 0, hi = line.cum.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (line.cum[mid] <= c) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final seg = line.cum[hi] - line.cum[lo];
  final t = seg <= 0 ? 0.0 : (c - line.cum[lo]) / seg;
  final x0 = line.xy[2 * lo], y0 = line.xy[2 * lo + 1], x1 = line.xy[2 * hi], y1 = line.xy[2 * hi + 1];
  return (x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t, heading: math.atan2(y1 - y0, x1 - x0));
}
