import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../capture/tuning_balance.dart';
import '../../capture/tuning_setup.dart';
import '../../data/session_log_store.dart';
import '../../data/tuning_data.dart';
import '../colors.dart';
import '../type_label.dart';
import 'run_logger.dart';
import 'tuning_game.dart';
import 'tuning_layout.dart';
import 'vibration_driver.dart';

/// Sintonia de um Eco: a tela do jogo com o resultado por cima. Cada sintonia terminada grava
/// uma linha no registro.
///
/// Com [hidden], [pool] tem uma espécie de cada tipo e o tipo é sorteado a cada sintonia.
class TuningScreen extends StatefulWidget {
  const TuningScreen({
    required this.pool,
    required this.buildSetup,
    required this.balance,
    required this.store,
    this.hidden = false,
    this.showTarget = false,
    super.key,
  });

  final List<EcoSpecies> pool;
  final TuningSetup Function(EcoSpecies species) buildSetup;
  final TuningBalance balance;
  final SessionLogStore store;
  final bool hidden;
  final bool showTarget;

  @override
  State<TuningScreen> createState() => _TuningScreenState();
}

class _TuningScreenState extends State<TuningScreen> {
  final _vibration = DeviceVibration();
  late final TuningGame _game;
  late final RunLogger _logger;
  TuningRun? _run;
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    _logger = RunLogger(store: widget.store, balance: widget.balance, hidden: widget.hidden);
    _game = TuningGame(
      pool: widget.pool,
      buildSetup: widget.buildSetup,
      balance: widget.balance,
      vibration: _vibration,
      hidden: widget.hidden,
      showTarget: widget.showTarget,
      onFinished: _finished,
    );
  }

  void _finished(TuningRun run) {
    setState(() {
      _run = run;
      _marked = false;
    });
    _logger.finished(run);
  }

  void _guess(bool correct) {
    _logger.guess(correct);
    setState(() => _marked = true);
  }

  void _again() {
    setState(() => _run = null);
    _game.restart();
  }

  @override
  void dispose() {
    _logger.flush();
    _vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
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
            if (run != null)
              TuningResultPanel(
                run: run,
                hidden: widget.hidden,
                marked: _marked,
                onGuess: _guess,
                onAgain: _again,
                onMenu: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Resultado por cima da tela. No modo oculto revela o tipo e pergunta se o jogador acertou.
class TuningResultPanel extends StatelessWidget {
  const TuningResultPanel({
    required this.run,
    required this.hidden,
    required this.marked,
    required this.onGuess,
    required this.onAgain,
    required this.onMenu,
    super.key,
  });

  final TuningRun run;
  final bool hidden;
  final bool marked;
  final ValueChanged<bool> onGuess;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final o = run.outcome;
    final color = o.success ? kSignal : kEssence;
    const line = TextStyle(fontSize: 16, color: kText);
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kPanel, border: Border.all(color: color, width: 3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(o.success ? 'SELADO!' : 'SINAL PERDIDO', style: TextStyle(fontSize: 24, color: color)),
            const SizedBox(height: 16),
            Text('${o.durationS.toStringAsFixed(1)}s', style: line),
            const SizedBox(height: 8),
            if (o.success)
              Text('+${o.ectoplasm} Ectoplasma', style: line)
            else
              Text(o.fled ? 'A criatura fugiu' : 'Ela ainda está aqui', style: line),
            if (hidden) ...[
              const SizedBox(height: 16),
              Text('Era ${typeLabel(run.setup.type)}', style: const TextStyle(fontSize: 24, color: kVeil)),
              const SizedBox(height: 4),
              Text(run.species.name, style: const TextStyle(fontSize: 8, color: kDim)),
            ],
            const SizedBox(height: 20),
            if (hidden && !marked) ...[
              const Text('Você acertou o tipo?', style: line),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: PixelButton(label: 'Sim', color: kSignal, onTap: () => onGuess(true))),
                const SizedBox(width: 12),
                Expanded(child: PixelButton(label: 'Não', color: kEssence, onTap: () => onGuess(false))),
              ]),
            ] else ...[
              PixelButton(label: 'Repetir', color: color, onTap: onAgain),
              const SizedBox(height: 12),
              PixelButton(label: 'Menu', color: kDim, onTap: onMenu),
            ],
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
