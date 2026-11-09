import 'package:flutter/material.dart';

import '../../dev/dev_tools.dart';
import '../../dev/gps_simulator.dart';
import '../../world/places.dart';
import '../colors.dart';

/// As fichas do simulador de GPS: velocidade e teleporte. Moram na folha do selo de modo (barra do topo), para não cobrir
/// o mapa; o joystick fica na zona dele no HUD.
class SimChips extends StatefulWidget {
  const SimChips({required this.tools, super.key});

  final DevTools tools;

  @override
  State<SimChips> createState() => _SimChipsState();
}

class _SimChipsState extends State<SimChips> {
  SimulatedPositionSource get sim => widget.tools.simulator;

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color color = kSignal}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.25) : kOutline.withValues(alpha: 0.85),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: selected ? kText : color)),
        ),
      );

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in SimSpeed.values.reversed)
          _chip('${s.label} ${s.mps.toStringAsFixed(1)} m/s', sim.speedMps == s.mps, () => setState(() => sim.speedMps = s.mps)),
        _chip('Teleporte: Unicamp', false, () => sim.teleport(kUnicamp.$1, kUnicamp.$2), color: kVeil),
        _chip('Teleporte: Centro', false, () => sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2), color: kVeil),
        _chip('Teleporte: Taquaral', false, () => sim.teleport(kTaquaral.$1, kTaquaral.$2), color: kVeil),
        _chip('Ir: Paulista', false, () => sim.teleport(kPaulista.$1, kPaulista.$2), color: kVeil),
        _chip('Ir: Bandeirantes', false, () => sim.teleport(kBandeirantes.$1, kBandeirantes.$2), color: kVeil),
        _chip('Ir: Jundiaí', false, () => sim.teleport(kJundiai.$1, kJundiai.$2), color: kVeil),
      ]);
}
