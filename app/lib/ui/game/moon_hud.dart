/// Os desenhos da lua e do clima da barra do HUD, do celular e do Céu: o disco com a parte iluminada (no hemisfério sul a
/// lua aparece espelhada em relação ao norte, e o disco acompanha isso) e o glifo de pixels do clima.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/climate_catalog.dart';
import '../colors.dart';

/// O contorno da parte iluminada, em coordenadas do disco de raio [r] centrado na origem. [cycle] vai de 0 (nova) a 1.
/// Crescente acende a direita (no norte); minguante, a esquerda; [southern] espelha tudo.
List<Offset> moonLitPolygon(double cycle, double r, {bool southern = false, int steps = 32}) {
  final waxing = cycle < 0.5;
  final w = waxing ? cycle : 1 - cycle;
  final k = math.cos(2 * math.pi * w); // 1 na nova, 0 no quarto, -1 na cheia
  final mirror = waxing == southern; // crescente no sul acende a esquerda
  final pts = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final a = -math.pi / 2 + math.pi * i / steps;
    pts.add(Offset(r * math.cos(a), r * math.sin(a)));
  }
  for (var i = steps; i >= 0; i--) {
    final a = -math.pi / 2 + math.pi * i / steps;
    pts.add(Offset(k * r * math.cos(a), r * math.sin(a)));
  }
  return mirror ? [for (final p in pts) Offset(-p.dx, p.dy)] : pts;
}

class MoonPainter extends CustomPainter {
  MoonPainter(this.cycle, this.southern);

  final double cycle;
  final bool southern;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    canvas.drawCircle(c, r, Paint()..color = kPanel..isAntiAlias = false);
    final lit = Path()..addPolygon([for (final p in moonLitPolygon(cycle, r, southern: southern)) p + c], true);
    canvas.drawPath(lit, Paint()..color = const Color(0xFFE8E4F4)..isAntiAlias = false);
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kVeil..isAntiAlias = false);
  }

  @override
  bool shouldRepaint(MoonPainter old) => old.cycle != cycle || old.southern != southern;
}

/// O clima em um glifo de pixels de 18 × 18, montado com as partes que o `clima.json` lista (`icon`): sol, nuvem, gotas,
/// raio, floco... O código só conhece as partes.
class WeatherGlyphPainter extends CustomPainter {
  WeatherGlyphPainter(this.info);

  final ClimateInfo info;

  static const _veil = kVeil, _sun = kEssence, _drop = kSignal, _cloud = kText;
  static const _red = Color(0xFFD0344A), _green = Color(0xFFA8E36A), _sand = Color(0xFFE0C27A), _dark = Color(0xFF3A3350);

  /// Cada parte: retângulos (x, y, largura, altura) e a cor.
  static final Map<String, List<(double, double, double, double, Color)>> parts = {
    'sun': [(5, 5, 8, 8, _sun), (8, 1, 2, 3, _sun), (8, 14, 2, 3, _sun), (1, 8, 3, 2, _sun), (14, 8, 3, 2, _sun)],
    'sun_black': [(5, 5, 8, 8, kOutline), (4, 4, 10, 1, _veil), (4, 13, 10, 1, _veil), (4, 4, 1, 10, _veil), (13, 4, 1, 10, _veil)],
    'heat': [(2, 15, 3, 1, _sun), (7, 16, 4, 1, _sun), (13, 15, 3, 1, _sun)],
    'cloud': [(3, 8, 12, 6, Color(0xBFE8E4F4)), (5, 5, 7, 4, Color(0xBFE8E4F4))],
    'cloud_dark': [(3, 4, 12, 6, kDim), (5, 2, 7, 3, kDim)],
    'drops': [(4, 11, 2, 3, _drop), (8, 12, 2, 3, _drop), (12, 11, 2, 3, _drop)],
    'drops_fine': [(5, 15, 1, 2, _drop), (9, 15, 1, 2, _drop), (13, 15, 1, 2, _drop)],
    'drops_green': [(4, 11, 2, 3, _green), (8, 12, 2, 3, _green), (12, 11, 2, 3, _green)],
    'drops_red': [(4, 11, 2, 3, _red), (8, 12, 2, 3, _red), (12, 11, 2, 3, _red)],
    'drops_prism': [(4, 15, 2, 2, _sun), (8, 15, 2, 2, _drop), (12, 15, 2, 2, _veil)],
    'drops_up': [(4, 6, 2, 3, _drop), (8, 3, 2, 3, _drop), (12, 7, 2, 3, _drop), (8, 12, 2, 4, _cloud)],
    'bolt': [(8, 9, 3, 3, _sun), (6, 12, 3, 3, _sun), (8, 15, 2, 2, _sun)],
    'bolt_veil': [(8, 9, 3, 3, _veil), (6, 12, 3, 3, _veil), (8, 15, 2, 2, _veil)],
    'hail': [(4, 12, 3, 3, _cloud), (9, 14, 3, 3, _cloud), (13, 11, 3, 3, _cloud)],
    'rainbow': [(2, 10, 14, 2, _red), (3, 8, 12, 2, _sun), (4, 6, 10, 2, _drop), (5, 4, 8, 2, _veil)],
    'fog': [(1, 5, 16, 2, _cloud), (3, 9, 14, 2, Color(0xBFE8E4F4)), (1, 13, 13, 2, Color(0x80E8E4F4))],
    'snowflake': [(8, 2, 2, 14, _cloud), (2, 8, 14, 2, _cloud), (4, 4, 2, 2, _cloud), (12, 12, 2, 2, _cloud), (12, 4, 2, 2, _cloud), (4, 12, 2, 2, _cloud)],
    'snowflake_veil': [(8, 2, 2, 14, Color(0xFFB8A8D8)), (2, 8, 14, 2, Color(0xFFB8A8D8)), (4, 4, 2, 2, _veil), (12, 12, 2, 2, _veil)],
    'wind': [(1, 5, 11, 2, _cloud), (11, 3, 2, 2, _cloud), (3, 9, 14, 2, _cloud), (1, 13, 9, 2, _cloud), (9, 15, 2, 2, _cloud)],
    'wind_veil': [(1, 5, 11, 2, _veil), (3, 9, 14, 2, _veil), (1, 13, 9, 2, _veil)],
    'dust': [(3, 12, 2, 2, _sand), (7, 9, 2, 2, _sand), (11, 13, 2, 2, _sand), (14, 8, 2, 2, _sand), (5, 15, 2, 2, _sand)],
    'smoke': [(4, 9, 10, 6, kDim), (6, 6, 6, 4, kDim), (3, 3, 4, 2, _sun), (11, 2, 3, 2, _sun)],
    'spiral': [(4, 2, 10, 3, _dark), (6, 6, 7, 3, _dark), (7, 10, 4, 3, _dark), (8, 14, 2, 3, _dark)],
    'aurora': [(1, 4, 16, 2, Color(0xFF6BD36A)), (2, 7, 14, 2, _veil), (1, 10, 16, 2, _drop)],
    'stars': [(3, 3, 2, 2, _cloud), (12, 5, 2, 2, _cloud), (7, 9, 6, 1, Color(0xFFFFE9A8)), (13, 9, 2, 2, Color(0xFFFFE9A8))],
    'ember': [(4, 4, 3, 3, _sun), (11, 7, 3, 3, Color(0xFFFFB36B)), (6, 12, 3, 3, _sun)],
    'glitch': [(2, 4, 8, 2, _drop), (8, 8, 9, 2, _veil), (3, 12, 6, 2, _drop), (12, 14, 4, 2, _cloud)],
    'silence': [(4, 6, 4, 6, _cloud), (8, 4, 2, 10, _cloud), (12, 6, 2, 2, _red), (14, 8, 2, 2, _red), (12, 10, 2, 2, _red)],
    'ash_veil': [(4, 4, 2, 2, _veil), (10, 7, 2, 2, _veil), (6, 11, 2, 2, _veil), (13, 13, 2, 2, _veil)],
    'figure': [(13, 6, 3, 9, _dark), (13, 3, 3, 3, _dark)],
    'wave': [(1, 15, 4, 2, _drop), (5, 14, 4, 2, _drop), (9, 15, 4, 2, _drop), (13, 14, 4, 2, _drop)],
    'wave_veil': [(1, 6, 5, 2, _veil), (6, 4, 5, 2, _veil), (11, 6, 6, 2, _veil), (1, 12, 5, 2, _veil), (6, 10, 5, 2, _veil), (11, 12, 6, 2, _veil)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    for (final name in info.icon) {
      for (final (x, y, w, h, c) in parts[name] ?? const <(double, double, double, double, Color)>[]) {
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), p..color = c);
      }
    }
  }

  @override
  bool shouldRepaint(WeatherGlyphPainter old) => old.info.id != info.id;
}
