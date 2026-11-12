/// Tráfego do Véu ambiente (docs/GDD.md, "Tráfego do Véu"): o que se desenha de um carro, moto, passante ou ciclista
/// fantasma, a roupa pelo clima e a densidade pela hora. Onde cada um está sai da simulação local
/// (`sim/traffic_sim.dart`): é cenário e difere entre aparelhos. Dart puro.
library;

import 'dart:math' as math;

import '../core/fnv.dart';
import 'traffic_graph.dart';

export 'traffic_graph.dart' show GhostLine, TrafficGraph, ghostLinesOfTile;

/// Quanto dura a costura do Véu quando um fantasma nasce ou morre, em segundos.
const double veilFadeS = 0.3;

enum GhostKind { car, pedestrian }

enum GhostModel {
  hatch(GhostKind.car, 6),
  sedan(GhostKind.car, 6),
  pickup(GhostKind.car, 5),
  moto(GhostKind.car, 4),
  adult(GhostKind.pedestrian, 5),
  childPair(GhostKind.pedestrian, 5),
  elder(GhostKind.pedestrian, 4),
  cyclist(GhostKind.pedestrian, 4);

  const GhostModel(this.kind, this.paletteCount);

  final GhostKind kind;

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
    this.line,
    this.sitting = false,
    this.dog = false,
    this.bus = false,
  });

  /// Vida urbana (só desenho): sentado na praça, passeando com cachorro, e o carro que é ônibus.
  final bool sitting, dog, bus;

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

  /// A rua em que está agora (o clima: carro em rua alagada vira barco).
  final GhostLine? line;

  GhostKind get kind => model.kind;

  /// Opacidade de 0 a 1 implícita pela fase.
  double get alpha => switch (phase) { GhostPhase.alive => 1.0, GhostPhase.fadeIn => phaseT, GhostPhase.fadeOut => 1 - phaseT };
}

/// A roupa do passante conforme o clima (só desenho): acessório por cima do sprite ou troca de paleta.
enum GhostOutfit { none, umbrella, raincoat, coat, beanie, scarf, light, cap, hat, mask }

/// O que cada grupo de roupa do `clima.json` (`outfit`) veste, com o peso de cada peça.
const Map<String, List<(GhostOutfit, int)>> outfitWeights = {
  'rain': [(GhostOutfit.umbrella, 70), (GhostOutfit.raincoat, 25), (GhostOutfit.none, 5)],
  'cold': [(GhostOutfit.coat, 40), (GhostOutfit.beanie, 30), (GhostOutfit.scarf, 30)],
  'heat': [(GhostOutfit.light, 40), (GhostOutfit.cap, 35), (GhostOutfit.hat, 25)],
  'mask': [(GhostOutfit.mask, 85), (GhostOutfit.none, 15)],
};

final int _saltOutfit = salt('OUTF');

/// A roupa do passante [ghostId] no grupo [group] (`null` ou desconhecido: nenhuma). Sai da identidade do fantasma, então
/// é a mesma nos dois aparelhos e não muda de um quadro para o outro; cada passante veste uma peça diferente.
GhostOutfit ghostOutfit(String? group, int ghostId) {
  final w = outfitWeights[group];
  if (w == null) return GhostOutfit.none;
  final total = w.fold(0, (a, e) => a + e.$2);
  var r = (fnv1a64([ghostId, _saltOutfit]) >>> 32) % total;
  for (final (o, n) in w) {
    if (r < n) return o;
    r -= n;
  }
  return GhostOutfit.none;
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
