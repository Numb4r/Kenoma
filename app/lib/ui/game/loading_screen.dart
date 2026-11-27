/// A tela de carregamento do jogo (0.26.2): depois do splash do Android, no mesmo fundo escuro, o nome Kenoma e uma
/// costura violeta do Véu que se fecha conforme o mapa, o kit do HUD, as Fagulhas e as criaturas da região carregam.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../colors.dart';

class KenomaLoading extends StatefulWidget {
  const KenomaLoading({required this.progress, super.key});

  /// De 0 a 1.
  final ValueListenable<double> progress;

  @override
  State<KenomaLoading> createState() => _KenomaLoadingState();
}

class _KenomaLoadingState extends State<KenomaLoading> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  double _shown = 0, _t = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  /// O fecho anda até o progresso sem saltar (um passo grande vira um deslizar de ~0,3 s).
  void _tick(Duration d) {
    final dt = (d - _last).inMicroseconds / 1e6;
    _last = d;
    setState(() {
      _t += dt;
      _shown += (widget.progress.value - _shown) * math.min(1, dt * 10);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: kOutline,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('KENOMA', style: TextStyle(fontSize: 36, color: kText, letterSpacing: 6)),
              const SizedBox(height: 28),
              SizedBox(width: 240, height: 60, child: CustomPaint(painter: SeamPainter(_shown, _t))),
              const SizedBox(height: 20),
              const Text('Carregando mapa...', style: TextStyle(fontSize: 12, color: kDim)),
            ],
          ),
        ),
      );
}

/// A costura do Véu: uma fenda violeta deitada, aberta no começo, que os pontos vão fechando da esquerda para a direita
/// conforme [progress]. Em pixels de 3 dp, sem suavização; o brilho de dentro respira devagar ([t], segundos).
class SeamPainter extends CustomPainter {
  const SeamPainter(this.progress, this.t);

  final double progress;
  final double t;

  static const double px = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final cols = (size.width / px).floor(), cy = (size.height / px / 2).floor();
    final open = (cy - 1) * (1 - p); // a abertura no meio, em pixels de arte: fecha com o progresso
    final edge = Paint()..color = kVeil..isAntiAlias = false;
    final inner = Paint()..color = kVeil.withValues(alpha: 0.18 + 0.08 * math.sin(t * 2))..isAntiAlias = false;
    final stitch = Paint()..color = kText..isAntiAlias = false;
    void cell(int x, int y, Paint paint) => canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), paint);
    for (var x = 0; x < cols; x++) {
      final u = (x + 0.5) / cols;
      final h = (open * math.sin(math.pi * u)).round(); // a fenda é uma lente: mais aberta no meio
      for (var y = cy - h + 1; y < cy + h; y++) {
        cell(x, y, inner);
      }
      cell(x, cy - h, edge);
      if (h > 0) cell(x, cy + h, edge);
      // Os pontos da costura, a cada 4 colunas, até onde o progresso chegou.
      if (x % 4 == 2 && u <= p) {
        for (var y = cy - h - 1; y <= cy + h + 1; y++) {
          cell(x, y, stitch);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SeamPainter old) => old.progress != progress || old.t != t;
}
