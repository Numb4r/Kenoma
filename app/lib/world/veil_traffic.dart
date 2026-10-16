/// Tráfego do Véu ambiente (docs/GDD.md, "Tráfego do Véu"): carros, motos, passantes e ciclistas fantasmas que
/// circulam pelas ruas reais. Só visual: nada aqui é spawn, coleta nem Aura. Dart puro.
///
/// Cada fantasma é uma viagem: nasce numa ponta de rua num instante sorteado por `hash(seed, tile, rua, fatia)`,
/// segue as ruas ligadas (carro na pista pela direita, passante na calçada, ciclista só em caminho de pedestre) e
/// some no fim. A posição é função contínua do tempo UTC; nada depende de câmera, tela, aparelho ou latitude do GPS,
/// então dois aparelhos com a mesma seed veem os mesmos fantasmas nos mesmos lugares. Quem nasce ou morre é
/// sempre desenhado com [GhostPhase.fadeIn] / [GhostPhase.fadeOut] (costura do Véu de [veilFadeS]); quem entra na
/// tela andando já existia fora dela.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../core/fnv.dart';
import '../core/pcg32.dart';
import '../core/tiles.dart';
import '../data/visual_pack.dart';
import 'traffic_graph.dart';
import 'traffic_route.dart';

export 'traffic_graph.dart' show GhostLine, TrafficGraph, ghostLinesOfTile;
export 'traffic_route.dart' show RiderKind, TrafficPath;

/// Duração das fatias de nascimento, em segundos. Uma viagem dura no máximo [_backSlots] fatias.
const int trafficSlotS = 120;
const int _backSlots = 4;
const double _maxLifeS = trafficSlotS * _backSlots * 1.0;

/// Quanto dura a costura do Véu quando um fantasma nasce ou morre, em segundos.
const double veilFadeS = 0.3;

enum GhostKind { car, pedestrian }

enum GhostModel {
  hatch(GhostKind.car, RiderKind.car, 6),
  sedan(GhostKind.car, RiderKind.car, 6),
  pickup(GhostKind.car, RiderKind.car, 5),
  moto(GhostKind.car, RiderKind.car, 4),
  adult(GhostKind.pedestrian, RiderKind.walker, 5),
  childPair(GhostKind.pedestrian, RiderKind.walker, 5),
  elder(GhostKind.pedestrian, RiderKind.walker, 4),
  cyclist(GhostKind.pedestrian, RiderKind.bike, 4);

  const GhostModel(this.kind, this.rider, this.paletteCount);

  final GhostKind kind;
  final RiderKind rider;

  /// Quantas paletas o modelo tem (4 a 6).
  final int paletteCount;
}

/// Em que ponto da vida o fantasma está: nasce e morre pela costura do Véu, no resto está inteiro.
enum GhostPhase { alive, fadeIn, fadeOut }

class Ghost {
  const Ghost({
    required this.id,
    required this.model,
    required this.palette,
    required this.x,
    required this.y,
    required this.heading,
    required this.speedMps,
    required this.phase,
    required this.phaseT,
    required this.travelledM,
  });

  /// Identidade estável: a mesma nos dois aparelhos e em todos os quadros.
  final int id;
  final GhostModel model;
  final int palette;

  /// Posição em células z21 fracionárias, já no lugar da pista ou da calçada.
  final double x;
  final double y;

  /// Direção em radianos (x leste, y sul; horário na tela).
  final double heading;
  final double speedMps;
  final GhostPhase phase;

  /// Progresso da costura de 0 a 1 em [GhostPhase.fadeIn] (se forma) e [GhostPhase.fadeOut] (se desfaz); 1 se inteiro.
  final double phaseT;

  /// Distância andada desde o nascimento, em metros (para o passo do pedestre).
  final double travelledM;

  GhostKind get kind => model.kind;

  /// Opacidade de 0 a 1 implícita pela fase.
  double get alpha => switch (phase) { GhostPhase.alive => 1.0, GhostPhase.fadeIn => phaseT, GhostPhase.fadeOut => 1 - phaseT };
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

/// Carros presentes por 100 m de rua com a densidade em 1: as avenidas enchem mais que as ruas calmas.
double _carConc(RoadClass c) => switch (c) { RoadClass.principal => 3.5, RoadClass.secondary => 2.4, RoadClass.local => 1.2, RoadClass.pedestrian => 0 };

/// Passantes presentes por 100 m de calçada (ou de caminho, na classe pedestre).
double _walkConc(RoadClass c) => switch (c) { RoadClass.principal => 0.7, RoadClass.secondary => 0.6, RoadClass.local => 0.45, RoadClass.pedestrian => 1.0 };

const double _bikeConc = 0.25; // só nos caminhos de pedestre

/// Velocidade do carro em m/s, por classe da rua onde nasce.
(double, double) _carSpeed(RoadClass c) => switch (c) { RoadClass.principal => (9.0, 14.0), RoadClass.secondary => (6.0, 10.0), _ => (3.5, 7.0) };

const double _carTripM = 400, _carTripSpan = 400; // comprimento da viagem: 400 a 800 m
const double _walkTripM = 100, _walkTripSpan = 200;
const double _bikeTripM = 250, _bikeTripSpan = 300;

const double _maxSeedsPerLine = 12;

/// Velocidade máxima de qualquer fantasma, em m/s (os testes usam como teto de salto).
const double maxGhostSpeedMps = 14;

class _Seed {
  _Seed(this.id, this.line, this.fromFirst, this.tBirth, this.model, this.palette, this.speed, this.targetM, this.side, this.jitter, this.pick, this.mpc);

  final int id;
  final GhostLine line;
  final bool fromFirst;
  final double tBirth;
  final GhostModel model;
  final int palette;
  final double speed, targetM;
  final int side;
  final double jitter;
  final int pick;
  final double mpc;

  /// O caminho, construído na primeira vez que a viagem chega perto da vista (e guardado junto com a fatia).
  TrafficPath? path;
  bool built = false;
}

/// O campo de fantasmas: sorteia as viagens por tile e fatia, constrói os caminhos sob demanda e diz quem está onde.
class TrafficField {
  TrafficField({
    required this.graph,
    required this.seed,
    this.roadWidthM = const {'principal': 12, 'secondary': 9, 'local': 6, 'pedestrian': 2},
    this.cacheSlots = 160,
  });

  final TrafficGraph graph;
  final int seed;

  /// Largura da via por classe, em metros (`map.road_width_m` do balance). O pacote visual não guarda a tag `width`.
  final Map<String, double> roadWidthM;
  final int cacheSlots;

  final LinkedHashMap<(int, int, int), List<_Seed>> _seeds = LinkedHashMap();

  double _width(RoadClass c) => roadWidthM[c.name] ?? 6;

  /// Largura (m) da via da classe [c] segundo este campo.
  double widthOf(RoadClass c) => _width(c);

  List<_Seed> _seedsOf(int tx, int ty, int slot) {
    final key = (tx, ty, slot);
    final cached = _seeds.remove(key);
    if (cached != null) {
      _seeds[key] = cached;
      return cached;
    }
    final out = _makeSeeds(tx, ty, slot);
    _seeds[key] = out;
    while (_seeds.length > cacheSlots) {
      _seeds.remove(_seeds.keys.first);
    }
    return out;
  }

  List<_Seed> _makeSeeds(int tx, int ty, int slot) {
    final lines = graph.linesOfTile(tx, ty);
    if (lines.isEmpty) return const [];
    final half = graph.cellsPerTile / 2;
    final (lat, lon) = tileFractionToLatLon(tx * graph.cellsPerTile + half, ty * graph.cellsPerTile + half, biomeZoom);
    final mpc = metersPerCell(lat);
    final slotStart = slot * trafficSlotS;
    final hour = localHour(slotStart, lon);
    final carD = carDensity(hour), walkD = pedestrianDensity(hour);
    final out = <_Seed>[];
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final lenM = line.lengthCells * mpc;
      final cls = line.roadClass;
      if (!line.isPedestrian) _stream(out, tx, ty, li, slot, 0, line, mpc, slotStart, carD * _carConc(cls) * lenM / 100 * trafficSlotS / ((_carTripM + _carTripSpan / 2) / _meanCarSpeed(cls)));
      _stream(out, tx, ty, li, slot, 1, line, mpc, slotStart, walkD * _walkConc(cls) * lenM / 100 * trafficSlotS / ((_walkTripM + _walkTripSpan / 2) / 1.3));
      if (line.isPedestrian) _stream(out, tx, ty, li, slot, 2, line, mpc, slotStart, walkD * _bikeConc * lenM / 100 * trafficSlotS / ((_bikeTripM + _bikeTripSpan / 2) / 4.5));
    }
    return out;
  }

  double _meanCarSpeed(RoadClass c) {
    final (lo, hi) = _carSpeed(c);
    return (lo + hi) / 2;
  }

  void _stream(List<_Seed> out, int tx, int ty, int li, int slot, int stream, GhostLine line, double mpc, int slotStart, double expected) {
    if (expected < 0.002) return;
    final rng = Pcg32(fnv1a64([seed, tx, ty, li, slot, saltTraf, stream]), saltKenoma);
    final n = math.min(expected.floor() + (rng.nextFloat() < expected - expected.floor() ? 1 : 0), _maxSeedsPerLine.toInt());
    for (var i = 0; i < n; i++) {
      final tBirth = slotStart + rng.nextFloat() * trafficSlotS;
      final modelDraw = rng.nextFloat();
      final palette = rng.nextInt(6);
      final speedDraw = rng.nextFloat();
      final tripDraw = rng.nextFloat();
      final endDraw = rng.nextFloat();
      final sideDraw = rng.nextFloat();
      final jitter = rng.nextFloat() * 2 - 1;
      final pick = rng.next();
      final id = fnv1a64([seed, tx, ty, li, slot, stream, i, saltTraf]) & 0x7fffffffffffffff;
      final GhostModel model;
      final double speed, target;
      switch (stream) {
        case 0:
          model = modelDraw < 0.4 ? GhostModel.hatch : modelDraw < 0.7 ? GhostModel.sedan : modelDraw < 0.85 ? GhostModel.pickup : GhostModel.moto;
          final (lo, hi) = _carSpeed(line.roadClass);
          speed = lo + (hi - lo) * speedDraw;
          target = _carTripM + _carTripSpan * tripDraw;
        case 1:
          model = modelDraw < 0.6 ? GhostModel.adult : modelDraw < 0.85 ? GhostModel.childPair : GhostModel.elder;
          speed = switch (model) { GhostModel.elder => 0.7 + 0.3 * speedDraw, GhostModel.childPair => 0.9 + 0.4 * speedDraw, _ => 1.1 + 0.6 * speedDraw };
          target = _walkTripM + _walkTripSpan * tripDraw;
        default:
          model = GhostModel.cyclist;
          speed = 3.5 + 2.0 * speedDraw;
          target = _bikeTripM + _bikeTripSpan * tripDraw;
      }
      final fromFirst = switch (line.oneway) {
        // Carro: a mão única manda. Passante e ciclista não têm mão.
        OneWay.forward when stream == 0 => true,
        OneWay.reverse when stream == 0 => false,
        _ => endDraw < 0.5,
      };
      out.add(_Seed(id, line, fromFirst, tBirth, model, palette % model.paletteCount, speed, target, sideDraw < 0.5 ? 1 : -1, jitter, pick, mpc));
    }
  }

  TrafficPath? _pathOf(_Seed s) {
    if (s.built) return s.path;
    s.built = true;
    return s.path = buildTrafficPath(
      graph,
      start: s.line,
      fromFirst: s.fromFirst,
      kind: s.model.rider,
      targetM: s.targetM,
      side: s.side,
      jitter: s.jitter,
      pick: s.pick,
      speed: s.speed,
      mpc: s.mpc,
      widthM: _width,
      maxLifeS: _maxLifeS,
    );
  }

  /// Os fantasmas vivos em [tUtc] (segundos UTC, fracionário) cuja posição cai no retângulo
  /// `[left, right] × [top, bottom]` em células z21. No máximo [maxGhosts]; se passar, ficam os de menor `id`
  /// (um corte que não depende da câmera, então ninguém pisca ao sair do teto).
  List<Ghost> ghostsIn(double tUtc, double left, double top, double right, double bottom, {int maxGhosts = 160}) {
    final n = graph.cellsPerTile.toDouble();
    final (lat, _) = tileFractionToLatLon((left + right) / 2, (top + bottom) / 2, biomeZoom);
    final reach = 800 / metersPerCell(lat) * 1.1; // a viagem mais longa, em células
    final slot0 = (tUtc / trafficSlotS).floor();
    final out = <Ghost>[];
    for (var ty = ((top - reach) / n).floor(); ty <= ((bottom + reach) / n).floor(); ty++) {
      for (var tx = ((left - reach) / n).floor(); tx <= ((right + reach) / n).floor(); tx++) {
        for (var slot = slot0 - _backSlots; slot <= slot0; slot++) {
          for (final s in _seedsOf(tx, ty, slot)) {
            final tau = tUtc - s.tBirth;
            if (tau < 0 || tau > _maxLifeS) continue;
            final r = math.min(s.targetM, s.speed * tau) / s.mpc * 1.1 + 2; // não anda mais que a velocidade de cruzeiro
            final l = s.line;
            if (l.maxX + r < left || l.minX - r > right || l.maxY + r < top || l.minY - r > bottom) continue;
            final path = _pathOf(s);
            if (path == null || tau > path.duration) continue;
            final dist = path.sAt(tau);
            final p = path.at(dist);
            if (p.x < left || p.x > right || p.y < top || p.y > bottom) continue;
            final left_ = path.duration - tau;
            final (phase, t) = tau < veilFadeS
                ? (GhostPhase.fadeIn, tau / veilFadeS)
                : left_ < veilFadeS
                    ? (GhostPhase.fadeOut, 1 - left_ / veilFadeS)
                    : (GhostPhase.alive, 1.0);
            out.add(Ghost(id: s.id, model: s.model, palette: s.palette, x: p.x, y: p.y, heading: p.heading, speedMps: path.vAt(tau), phase: phase, phaseT: t, travelledM: dist));
          }
        }
      }
    }
    if (out.length > maxGhosts) {
      out.sort((a, b) => a.id.compareTo(b.id));
      return out.sublist(0, maxGhosts);
    }
    return out;
  }
}
