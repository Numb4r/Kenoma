/// Teste do Selador: traçar com o dedo um sigilo simples em volta de um Eco. O anel claro é só a guia; vale a forma (um
/// círculo fechado em volta do Eco, tolerante a mão tremida). A nota vem de `sealerScore`.
library;

import 'package:flutter/material.dart';

import '../../player/conjurer_balance.dart';
import '../../player/school_tests.dart';
import '../tema.dart';
import 'test_shell.dart';

class SealerTestScreen extends StatelessWidget {
  const SealerTestScreen({required this.balance, super.key});

  final SealerBalance balance;

  @override
  Widget build(BuildContext context) => SchoolTestShell(
        school: School.sealer,
        title: 'Teste do sigilo',
        intro: 'Desenhe com o dedo um círculo fechado em volta do Eco, de uma vez só. O anel é só uma guia: a mão pode tremer.',
        scene: (finish) => SealerScene(balance: balance, onDone: finish),
      );
}

class SealerScene extends StatefulWidget {
  const SealerScene({required this.balance, required this.onDone, super.key});

  final SealerBalance balance;
  final void Function(int score) onDone;

  @override
  State<SealerScene> createState() => _SealerSceneState();
}

class _SealerSceneState extends State<SealerScene> {
  final List<Offset> _pts = [];

  static double _ref(Size s) => (s.shortestSide / 2) * 0.55;

  void _end(Size size) {
    final c = size.center(Offset.zero);
    if (_pts.length < widget.balance.minPoints) {
      setState(_pts.clear); // um toque solto não conta como traço
      return;
    }
    final ref = _ref(size);
    widget.onDone(sealerScore([for (final p in _pts) ((p.dx - c.dx) / ref, (p.dy - c.dy) / ref)], widget.balance));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            key: const Key('sealer-canvas'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() => _pts..clear()..add(d.localPosition)),
            onPanUpdate: (d) => setState(() => _pts.add(d.localPosition)),
            onPanEnd: (_) => _end(size),
            child: CustomPaint(size: Size.infinite, painter: _SealerPainter(points: List.of(_pts), ref: _ref(size))),
          );
        },
      );
}

class _SealerPainter extends CustomPainter {
  _SealerPainter({required this.points, required this.ref});

  final List<Offset> points;
  final double ref;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final px = Paint()..isAntiAlias = false;
    canvas.drawCircle(c, ref, px..style = PaintingStyle.stroke..strokeWidth = 2..color = KCores.veuVioleta.withValues(alpha: 0.25));
    canvas.drawRect(Rect.fromCenter(center: c, width: 28, height: 28), px..style = PaintingStyle.fill..color = KCores.brasaLaranja);
    canvas.drawRect(Rect.fromCenter(center: c, width: 28, height: 28), px..style = PaintingStyle.stroke..strokeWidth = 3..color = KCores.contorno);
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()..isAntiAlias = false..style = PaintingStyle.stroke..strokeWidth = 4..strokeJoin = StrokeJoin.round..color = KCores.veuVioleta);
  }

  @override
  bool shouldRepaint(_SealerPainter old) => true;
}
