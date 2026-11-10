/// As marcas da borda da tela depois de um pulso do Radar (docs/GDD.md, "Rastros e scanner"). Não há rastreador fixo: por
/// `edge_marks_s` (2 minutos) depois do pulso, uma marca fina na borda aponta a direção de cada coisa que ele achou (rastro
/// ou distorção) e que não está na tela, e some no fim. Sem pulso, nada: antes do Radar o jogador só vê o que está na tela.
/// Dart puro.
library;

import 'dart:math' as math;

import 'radar.dart';
import 'spawn_field.dart';

/// Uma marca da borda: a direção no mundo ([angle], radianos, x leste e y sul como `atan2(dy, dx)`; a tela soma a rotação
/// do mapa), se é distorção ou Brilhante e a opacidade de 0 a 1 (some nos últimos segundos).
class EdgeMark {
  const EdgeMark({required this.uid, required this.angle, required this.alpha, this.distortion = false, this.shiny = false});

  final int uid;
  final double angle;
  final double alpha;
  final bool distortion;
  final bool shiny;
}

/// As marcas em [nowUtc] do pulso de [pulseUtc] (`null`: nenhum pulso): uma por achado de [finds] que a onda já alcançou
/// ([pulseSpeedMps]) e que não está na tela ([onScreen]), por [showS] segundos, apagando nos últimos [fadeS].
List<EdgeMark> edgeMarks({
  required List<({WorldSpawn eco, SonarEcho echo})> finds,
  required int? pulseUtc,
  required double nowUtc,
  required double showS,
  required double pulseSpeedMps,
  required bool Function(WorldSpawn) onScreen,
  double fadeS = 15,
}) {
  if (pulseUtc == null) return const [];
  final age = nowUtc - pulseUtc;
  if (age < 0 || age >= showS) return const [];
  final alpha = math.min(1.0, (showS - age) / fadeS);
  return [
    for (final f in finds)
      if (f.echo.distanceM <= age * pulseSpeedMps && !onScreen(f.eco))
        EdgeMark(uid: f.echo.uid, angle: f.echo.angleRad, alpha: alpha, distortion: f.echo.distortion, shiny: f.echo.shiny),
  ];
}

/// Onde o raio que sai de ([cx], [cy]) no ângulo de tela [a] cruza a borda do retângulo `[0, w] × [0, h]` recuado [inset].
(double, double) edgePoint(double cx, double cy, double a, double w, double h, {double inset = 0}) {
  final dx = math.cos(a), dy = math.sin(a);
  var t = double.infinity;
  if (dx > 1e-9) t = math.min(t, (w - inset - cx) / dx);
  if (dx < -1e-9) t = math.min(t, (inset - cx) / dx);
  if (dy > 1e-9) t = math.min(t, (h - inset - cy) / dy);
  if (dy < -1e-9) t = math.min(t, (inset - cy) / dy);
  if (!t.isFinite || t < 0) t = 0;
  return (cx + dx * t, cy + dy * t);
}
