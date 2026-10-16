/// Teste do Xamã Urbano: aproximar-se devagar de um Eco arisco até ele parar de fugir. A faixa da direita é a velocidade:
/// quanto mais alto o dedo, mais rápido o passo; acima da linha calma o Eco se assusta e se afasta. Nota: `ShamanTest`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../player/conjurer_balance.dart';
import '../../player/school_tests.dart';
import '../tema.dart';
import 'test_shell.dart';

class ShamanTestScreen extends StatelessWidget {
  const ShamanTestScreen({required this.balance, super.key});

  final ShamanBalance balance;

  @override
  Widget build(BuildContext context) => SchoolTestShell(
        school: School.shaman,
        title: 'Teste da calma',
        intro: 'Um Eco arisco foge de quem anda rápido. Segure o dedo na faixa da direita: quanto mais alto, mais rápido o passo. '
            'Fique abaixo da linha e chegue perto até ele parar.',
        scene: (finish) => ShamanScene(balance: balance, onDone: finish),
      );
}

class ShamanScene extends StatefulWidget {
  const ShamanScene({required this.balance, required this.onDone, super.key});

  final ShamanBalance balance;
  final void Function(int score) onDone;

  @override
  State<ShamanScene> createState() => _ShamanSceneState();
}

class _ShamanSceneState extends State<ShamanScene> with SingleTickerProviderStateMixin {
  late final ShamanTest _test = ShamanTest(widget.balance);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _speed = 0;
  int _shownSpooks = 0;
  double _flash = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration t) {
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = t;
    _test.step(dt, _speed);
    if (_test.spooks != _shownSpooks) {
      _shownSpooks = _test.spooks;
      _flash = 0.5;
    }
    _flash = (_flash - dt).clamp(0.0, 1.0);
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

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    return Row(children: [
      Expanded(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ShamanPainter(distance: _test.distanceM, start: b.startM, spooked: _flash > 0),
        ),
      ),
      LayoutBuilder(
        builder: (context, c) {
          void set(Offset p) => _speed = (1 - p.dy / c.maxHeight).clamp(0.0, 1.0);
          return GestureDetector(
            key: const Key('shaman-pad'),
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => set(d.localPosition),
            onPanUpdate: (d) => set(d.localPosition),
            onPanEnd: (_) => _speed = 0,
            onPanCancel: () => _speed = 0,
            child: SizedBox(
              width: 96,
              height: c.maxHeight,
              child: CustomPaint(painter: _PadPainter(speed: _speed, calm: b.calmSpeedMps / b.maxSpeedMps)),
            ),
          );
        },
      ),
    ]);
  }
}

class _ShamanPainter extends CustomPainter {
  _ShamanPainter({required this.distance, required this.start, required this.spooked});

  final double distance, start;
  final bool spooked;

  @override
  void paint(Canvas canvas, Size size) {
    final px = Paint()..isAntiAlias = false;
    final x = size.width / 2;
    const top = 48.0;
    final bottom = size.height - 48;
    final ecoY = bottom - (bottom - top) * (distance / (start * 1.5)).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTRB(x - 1, ecoY, x + 1, bottom), px..color = KCores.superficie2);
    // O Conjurador (base) e o Eco arisco.
    canvas.drawRect(Rect.fromCenter(center: Offset(x, bottom), width: 20, height: 20), px..color = KCores.veuVioleta);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, ecoY), width: 28, height: 28), px..color = spooked ? KCores.falha : KCores.brasaLaranja);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, ecoY), width: 28, height: 28), px..style = PaintingStyle.stroke..strokeWidth = 3..color = KCores.contorno);
    final tp = TextPainter(text: TextSpan(text: '${distance.toStringAsFixed(1)} M', style: KTexto.rotulo), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x + 24, ecoY - 8));
  }

  @override
  bool shouldRepaint(_ShamanPainter old) => true;
}

class _PadPainter extends CustomPainter {
  _PadPainter({required this.speed, required this.calm});

  final double speed, calm;

  @override
  void paint(Canvas canvas, Size size) {
    final px = Paint()..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(24, 0, size.width - 24, size.height), px..color = KCores.superficie1);
    final calmY = size.height * (1 - calm);
    canvas.drawRect(Rect.fromLTWH(24, calmY, size.width - 24, size.height - calmY), px..color = KCores.brasaLaranja.withValues(alpha: 0.18));
    canvas.drawRect(Rect.fromLTWH(24, calmY - 1, size.width - 24, 3), px..color = KCores.brasaLaranja);
    final y = size.height * (1 - speed);
    canvas.drawRect(Rect.fromLTWH(24, y - 3, size.width - 24, 6), px..color = speed > calm ? KCores.falha : KCores.texto);
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
