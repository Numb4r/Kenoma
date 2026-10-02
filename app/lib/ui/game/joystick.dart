
import 'package:flutter/material.dart';

import '../colors.dart';

/// Joystick na tela do simulador de GPS. Arrastar dentro do círculo manda a direção ([onChanged] com
/// `x` para leste e `y` para norte, de -1 a 1); soltar volta ao centro e manda (0, 0).
class Joystick extends StatefulWidget {
  const Joystick({required this.onChanged, this.size = 140, super.key});

  final void Function(double x, double y) onChanged;
  final double size;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero; // -1 a 1, y para baixo na tela

  void _set(Offset local) {
    final r = widget.size / 2;
    var v = (local - Offset(r, r)) / r;
    final len = v.distance;
    if (len > 1) v = v / len;
    setState(() => _knob = v);
    widget.onChanged(v.dx, -v.dy); // para cima na tela é norte
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _set(d.localPosition),
      onPanUpdate: (d) => _set(d.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _JoystickPainter(_knob, r)),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter(this.knob, this.r);

  final Offset knob;
  final double r;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(r, r);
    canvas.drawCircle(c, r - 2, Paint()..color = kOutline.withValues(alpha: 0.7));
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = kVeil,
    );
    canvas.drawLine(c.translate(-r + 14, 0), c.translate(r - 14, 0), Paint()..color = kPanelLine);
    canvas.drawLine(c.translate(0, -r + 14), c.translate(0, r - 14), Paint()..color = kPanelLine);
    final k = c + knob * (r - 28);
    canvas.drawCircle(k, 22, Paint()..color = kSignal.withValues(alpha: 0.9));
    canvas.drawCircle(k, 22, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = kText);
    // Marca a direção como um traço do centro ao botão: dá para ler sem olhar a velocidade.
    if (knob.distance > 0.05) {
      canvas.drawLine(c, k, Paint()
        ..strokeWidth = 2
        ..color = kSignal.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.knob != knob;
}
