import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../capture/session.dart';
import '../../capture/tuning_balance.dart';
import '../../capture/tuning_setup.dart';
import '../../data/tuning_data.dart';
import '../colors.dart';
import 'tuning_game.dart';
import 'tuning_layout.dart';
import 'vibration_driver.dart';

/// Sintonia de um Eco: a tela do jogo com o resultado por cima.
class TuningScreen extends StatefulWidget {
  const TuningScreen({
    required this.setup,
    required this.species,
    required this.balance,
    this.showTarget = false,
    super.key,
  });

  final TuningSetup setup;
  final EcoSpecies species;
  final TuningBalance balance;
  final bool showTarget;

  @override
  State<TuningScreen> createState() => _TuningScreenState();
}

class _TuningScreenState extends State<TuningScreen> {
  final _outcome = ValueNotifier<TuningOutcome?>(null);
  final _vibration = DeviceVibration();
  late final TuningGame _game;

  @override
  void initState() {
    super.initState();
    _game = TuningGame(
      setup: widget.setup,
      species: widget.species,
      balance: widget.balance,
      vibration: _vibration,
      showTarget: widget.showTarget,
      onFinished: (o) => _outcome.value = o,
    );
  }

  @override
  void dispose() {
    _vibration.cancel();
    _outcome.dispose();
    super.dispose();
  }

  void _again() {
    _outcome.value = null;
    _game.restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOutline,
      body: SafeArea(
        child: Stack(
          children: [
            GameWidget(game: _game),
            Positioned(
              left: 0,
              top: 0,
              width: TuningLayout.hudLeft,
              height: TuningLayout.hudLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const Center(child: Text('<', style: TextStyle(fontSize: 24, color: kText))),
              ),
            ),
            ValueListenableBuilder<TuningOutcome?>(
              valueListenable: _outcome,
              builder: (context, o, _) => o == null ? const SizedBox.shrink() : _ResultPanel(outcome: o, onAgain: _again),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.outcome, required this.onAgain});

  final TuningOutcome outcome;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final ok = outcome.success;
    final color = ok ? kSignal : kEssence;
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kPanel, border: Border.all(color: color, width: 3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ok ? 'SELADO!' : 'SINAL PERDIDO', style: TextStyle(fontSize: 24, color: color)),
            const SizedBox(height: 16),
            Text('${outcome.durationS.toStringAsFixed(1)}s', style: const TextStyle(fontSize: 16, color: kText)),
            const SizedBox(height: 8),
            if (ok)
              Text('+${outcome.ectoplasm} Ectoplasma', style: const TextStyle(fontSize: 16, color: kText))
            else
              Text(outcome.fled ? 'A criatura fugiu' : 'Ela ainda está aqui',
                  style: const TextStyle(fontSize: 16, color: kText)),
            const SizedBox(height: 20),
            PixelButton(label: 'Repetir', color: color, onTap: onAgain),
            const SizedBox(height: 12),
            PixelButton(label: 'Menu', color: kDim, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// Botão retangular no estilo da interface.
class PixelButton extends StatelessWidget {
  const PixelButton({required this.label, required this.onTap, this.color = kVeil, super.key});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 48, minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: color, width: 3)),
        child: Text(label.toUpperCase(), style: TextStyle(fontSize: 16, color: color)),
      ),
    );
  }
}
