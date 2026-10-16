/// Teste do Tecnomante: estabilizar um sinal com um gadget improvisado. O jogador arrasta o dedo na trilha para manter o
/// marcador dentro da faixa do sinal; o botão de estabilizar segura o ruído por alguns segundos. A nota vem de `TechnoTest`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../player/conjurer_balance.dart';
import '../../player/school_tests.dart';
import '../tema.dart';
import 'test_shell.dart';

class TechnoTestScreen extends StatelessWidget {
  const TechnoTestScreen({required this.balance, super.key});

  final TechnoBalance balance;

  @override
  Widget build(BuildContext context) => SchoolTestShell(
        school: School.technomancer,
        title: 'Teste do sinal',
        intro: 'O sinal está sujo. Arraste o dedo na trilha para manter o marcador dentro da faixa. '
            'O botão ESTABILIZAR segura o ruído por ${balance.stabilizeS.round()} s, e você tem ${balance.stabilizeCharges} cargas.',
        scene: (finish) => TechnoScene(balance: balance, onDone: finish),
      );
}

class TechnoScene extends StatefulWidget {
  const TechnoScene({required this.balance, required this.onDone, super.key});

  final TechnoBalance balance;
  final void Function(int score) onDone;

  @override
  State<TechnoScene> createState() => _TechnoSceneState();
}

class _TechnoSceneState extends State<TechnoScene> with SingleTickerProviderStateMixin {
  late final TechnoTest _test = TechnoTest(widget.balance);
  late final Ticker _ticker;
  final List<double> _trail = []; // o sinal dos últimos quadros, para o traço
  Duration _last = Duration.zero;
  double _dial = 0.5;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration t) {
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = t;
    _test.step(dt, _dial);
    _trail.add(_test.target);
    if (_trail.length > 120) _trail.removeAt(0);
    if (_test.done) {
      _ticker.stop();
      widget.onDone(_test.score);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _drag(Offset p, double h) => _dial = (1 - p.dy / h).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      LinearProgressIndicator(value: (_test.t / widget.balance.durationS).clamp(0.0, 1.0), minHeight: 6, color: KCores.sinalCiano, backgroundColor: KCores.superficie1),
      Expanded(
        child: LayoutBuilder(
          builder: (context, c) => GestureDetector(
            key: const Key('techno-track'),
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _drag(d.localPosition, c.maxHeight),
            onPanUpdate: (d) => _drag(d.localPosition, c.maxHeight),
            child: CustomPaint(
              size: Size.infinite,
              painter: _TechnoPainter(trail: List.of(_trail), dial: _dial, target: _test.target, band: widget.balance.band, stabilized: _test.stabilized),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(KEspaco.s2),
        child: SchoolButton(
          label: 'Estabilizar (${_test.charges})',
          color: KCores.sinalCiano,
          onTap: _test.canStabilize ? () => setState(_test.stabilize) : null,
        ),
      ),
    ]);
  }
}

class _TechnoPainter extends CustomPainter {
  _TechnoPainter({required this.trail, required this.dial, required this.target, required this.band, required this.stabilized});

  final List<double> trail;
  final double dial, target, band;
  final bool stabilized;

  @override
  void paint(Canvas canvas, Size size) {
    final px = Paint()..isAntiAlias = false;
    double y(double v) => (1 - v) * size.height;
    final inBand = (dial - target).abs() <= band;
    canvas.drawRect(Rect.fromLTRB(0, y(target + band), size.width, y(target - band)), px..color = (stabilized ? KCores.sinalCiano : KCores.veuVioleta).withValues(alpha: 0.22));
    // O traço do sinal: da esquerda (antigo) para a direita (agora).
    final line = Paint()..isAntiAlias = false..style = PaintingStyle.stroke..strokeWidth = 3..color = KCores.sinalCiano;
    final path = Path();
    for (var i = 0; i < trail.length; i++) {
      final x = size.width * 0.15 + (size.width * 0.7) * i / 120;
      i == 0 ? path.moveTo(x, y(trail[i])) : path.lineTo(x, y(trail[i]));
    }
    canvas.drawPath(path, line);
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width * 0.85, y(target)), width: 12, height: 12), px..style = PaintingStyle.fill..color = KCores.sinalCiano);
    // O marcador do jogador.
    final c = inBand ? KCores.texto : KCores.falha;
    canvas.drawRect(Rect.fromLTWH(0, y(dial) - 3, size.width, 6), px..color = c.withValues(alpha: 0.5));
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width * 0.08, y(dial)), width: 18, height: 18), px..color = c);
  }

  @override
  bool shouldRepaint(_TechnoPainter old) => true;
}
