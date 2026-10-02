import 'package:flutter/material.dart';

import '../../dev/dev_tools.dart';
import '../../dev/gps_simulator.dart';
import '../../world/places.dart';
import '../colors.dart';
import 'joystick.dart';

/// Controles do simulador de GPS por cima do mapa do jogo: joystick, velocidade e teleporte. Só aparece
/// com o simulador ligado: dá para testar tudo sentado, sem sair do mapa.
class SimOverlay extends StatefulWidget {
  const SimOverlay({required this.tools, super.key});

  final DevTools tools;

  @override
  State<SimOverlay> createState() => _SimOverlayState();
}

class _SimOverlayState extends State<SimOverlay> {
  SimulatedPositionSource get sim => widget.tools.simulator;

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color color = kSignal}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.25) : kOutline.withValues(alpha: 0.85),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: selected ? kText : color)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 132,
          child: Joystick(onChanged: sim.setJoystick),
        ),
        Positioned(
          right: 12,
          bottom: 132,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final s in SimSpeed.values.reversed)
                _chip('${s.label} ${s.mps.toStringAsFixed(1)} m/s', sim.speedMps == s.mps, () => setState(() => sim.speedMps = s.mps)),
              _chip('Teleporte: Unicamp', false, () => sim.teleport(kUnicamp.$1, kUnicamp.$2), color: kVeil),
              _chip('Teleporte: Centro', false, () => sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2), color: kVeil),
            ],
          ),
        ),
      ],
    );
  }
}
