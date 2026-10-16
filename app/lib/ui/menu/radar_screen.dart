/// O app Radar do celular (docs/GDD.md, "Rastros e scanner"): um toque faz uma varredura, com recarga de 2 minutos. No
/// nível 1 revela os rastros dos Ecos raros por perto e os Ocultos a até 60 m; no nível 2 (nível 5 do Conjurador) o
/// rastro mostra também o tipo.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../player/game_state.dart';
import '../../world/radar.dart';
import '../../world/street_life_balance.dart';
import '../colors.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'screen_frame.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({required this.state, required this.street, required this.nowUtc, required this.onSweep, super.key});

  final GameState state;
  final StreetLifeBalance street;
  final int Function() nowUtc;

  /// Faz a varredura no mapa e devolve o que ela achou.
  final RadarOutcome Function() onSweep;

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  Timer? _tick;
  RadarOutcome? _last;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  void _sweep() {
    final wait = radarWaitS(lastUtc: widget.state.radarLastUtc, nowUtc: widget.nowUtc(), balance: widget.street);
    if (wait > 0) return;
    setState(() => _last = widget.onSweep());
  }

  @override
  Widget build(BuildContext context) {
    final level = scannerLevel(widget.state.playerLevel, widget.street);
    final wait = radarWaitS(lastUtc: widget.state.radarLastUtc, nowUtc: widget.nowUtc(), balance: widget.street);
    final last = _last;
    return ScreenFrame(
      title: 'Radar',
      subtitle: 'Scanner nível $level',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: panelBox(),
          child: Text(
            level >= 2
                ? 'NÍVEL 2: AS PEGADAS MOSTRAM O TIPO DO ECO. OS OCULTOS A ATÉ ${widget.street.radarRadiusM.round()} M APARECEM.'
                : 'NÍVEL 1: PEGADAS E DIREÇÃO DOS ECOS RAROS (VARIANTES, BRILHANTES, OCULTOS E MAIS FORTES QUE VOCÊ) A ATÉ ${widget.street.traceRangeM.round()} M. OS OCULTOS A ATÉ ${widget.street.radarRadiusM.round()} M APARECEM. O NÍVEL 2 VEM NO NÍVEL ${widget.street.radarLevel2PlayerLevel}.',
            style: const TextStyle(fontSize: 8, color: kText, height: 1.8),
          ),
        ),
        const SizedBox(height: 16),
        PixelButton(label: wait > 0 ? 'Recarregando ${_clock(wait)}' : 'Varrer', color: wait > 0 ? kDim : kSignal, onTap: _sweep),
        const SizedBox(height: 16),
        if (last != null)
          Container(
            key: const Key('radar-result'),
            padding: const EdgeInsets.all(12),
            decoration: panelBox(line: last.isEmpty ? kPanelLine : kSignal),
            child: Text(
              last.isEmpty
                  ? 'NADA RARO POR PERTO.'
                  : '${last.traces.length} RASTRO(S) NO MAPA · ${last.revealed.length} OCULTO(S) REVELADO(S).\nSIGA AS PEGADAS: ELAS APONTAM PARA O ECO COM UM ERRO DE ATÉ ${widget.street.traceErrorDeg.round()}°.',
              style: const TextStyle(fontSize: 8, color: kText, height: 1.8),
            ),
          ),
      ],
    );
  }
}
