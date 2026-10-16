/// A fase da lua no canto do mapa: um disco pequeno com a parte iluminada e o nome da fase. No hemisfério sul a lua
/// aparece espelhada em relação ao norte, e o disco acompanha isso.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/astro.dart';
import '../../core/weather.dart';
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

class MoonHud extends StatefulWidget {
  const MoonHud({required this.nowUtc, required this.lat, this.weather, super.key});

  final int Function() nowUtc;

  /// O clima que se vê agora, ao lado da lua. Sem ele, só a lua.
  final Weather Function()? weather;

  /// A latitude do jogador (o sinal decide o espelhamento).
  final double Function() lat;

  @override
  State<MoonHud> createState() => _MoonHudState();
}

class _MoonHudState extends State<MoonHud> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.nowUtc();
    final phase = moonPhase(t);
    return Container(
      key: const Key('moon-hud'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: kPanelLine, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(size: const Size(24, 24), painter: _MoonPainter(moonCycle(t), widget.lat() < 0)),
        const SizedBox(width: 8),
        Text(moonPhaseNames[phase]!.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText)),
        if (widget.weather != null) ...[
          const SizedBox(width: 10),
          CustomPaint(key: const Key('weather-glyph'), size: const Size(18, 18), painter: _WeatherPainter(widget.weather!())),
          const SizedBox(width: 6),
          Text(widget.weather!().label.toUpperCase(), key: const Key('weather-label'), style: const TextStyle(fontSize: 8, color: kText)),
        ],
      ]),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.cycle, this.southern);

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
  bool shouldRepaint(_MoonPainter old) => old.cycle != cycle || old.southern != southern;
}

/// O clima em um glifo de pixels de 18 × 18: sol, nuvem, chuva ou raio.
class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.weather);

  final Weather weather;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    void r(double x, double y, double w, double h, Color c) => canvas.drawRect(Rect.fromLTWH(x, y, w, h), p..color = c);
    const cloud = kText, sun = kEssence, drop = kSignal;
    switch (weather) {
      case Weather.clear:
        r(5, 5, 8, 8, sun);
        r(8, 1, 2, 3, sun);
        r(8, 14, 2, 3, sun);
        r(1, 8, 3, 2, sun);
        r(14, 8, 3, 2, sun);
      case Weather.cloudy:
        r(3, 8, 12, 6, cloud.withValues(alpha: 0.75));
        r(5, 5, 7, 4, cloud.withValues(alpha: 0.75));
      case Weather.rain:
        r(3, 4, 12, 6, kDim);
        r(5, 2, 7, 3, kDim);
        for (final x in [4.0, 8.0, 12.0]) {
          r(x, 11, 2, 3, drop);
        }
      case Weather.storm:
        r(3, 3, 12, 6, kDim);
        r(5, 1, 7, 3, kDim);
        r(8, 9, 3, 3, sun);
        r(6, 12, 3, 3, sun);
        r(8, 15, 2, 2, sun);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.weather != weather;
}
