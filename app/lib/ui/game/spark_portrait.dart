/// A Fagulha no Bestiário: a mesma tira do mapa (`assets/art/sparks/`, `SparkArt`), pairando no laço de 4 quadros, com o
/// brilho por cima. Antes o Bestiário mostrava o ícone antigo do tipo (chama, glifo, fantasminha, folha).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../colors.dart' show kPanelLine;
import 'creature_anim.dart' show loopFrame;
import 'traffic_art.dart' show SparkArt;

class SparkPortrait extends StatefulWidget {
  const SparkPortrait({required this.type, required this.size, this.silhouette = false, super.key});

  /// O tipo da Fagulha (`fire`, `water`...), a chave da tira no `sparks.json`.
  final String type;
  final double size;

  /// Só a forma, na cor da linha do painel: a Fagulha que o jogador ainda não viu.
  final bool silhouette;

  @override
  State<SparkPortrait> createState() => _SparkPortraitState();
}

class _SparkPortraitState extends State<SparkPortrait> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6));
  double _t = 0;

  @override
  void initState() {
    super.initState();
    if (SparkArt.current == null) SparkArt.load().then((_) => mounted ? setState(() {}) : null);
    if (!widget.silhouette) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = SparkArt.current;
    final strip = art?.strips[widget.type];
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: art == null || strip == null ? null : CustomPaint(painter: _SparkPainter(art, strip, _t, widget.silhouette)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.art, this.strip, this.t, this.silhouette);

  final SparkArt art;
  final (ui.Image, ui.Image?) strip;
  final double t;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final f = art.frame.toDouble();
    // Escala inteira, para o pixel de arte não borrar; o quadro fica no centro.
    final k = (size.shortestSide / f).floorToDouble().clamp(1.0, double.infinity);
    final dst = Rect.fromCenter(center: size.center(Offset.zero), width: f * k, height: f * k);
    final frame = silhouette ? 0 : loopFrame(t, art.frames, art.fps);
    final src = Rect.fromLTWH(frame * f, 0, f, f);
    final p = Paint()..filterQuality = FilterQuality.none;
    if (silhouette) p.colorFilter = const ColorFilter.mode(kPanelLine, BlendMode.srcIn);
    canvas.drawImageRect(strip.$1, src, dst, p);
    if (!silhouette && strip.$2 != null) canvas.drawImageRect(strip.$2!, src, dst, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.strip != strip || old.silhouette != silhouette;
}
