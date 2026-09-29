import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../capture/eco_type.dart';
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
    this.vibration,
    super.key,
  });

  final List<EcoSpecies> pool;
  final TuningSetup Function(EcoSpecies species) buildSetup;
  final TuningBalance balance;
  final SessionLogStore store;
  final bool hidden;
  final bool showTarget;

  /// Quem vibra. Por padrão, o motor do aparelho.
  final VibrationPlayer? vibration;

  @override
  State<TuningScreen> createState() => _TuningScreenState();
}

class _TuningScreenState extends State<TuningScreen> {
  late final VibrationPlayer _vibration = widget.vibration ?? DeviceVibration();
  late final TuningGame _game;
  late final RunLogger _logger;
  TuningRun? _run;

  /// Palpite da sintonia em andamento, no modo oculto.
  EcoType? _guess;

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
    setState(() => _run = run);
    _logger.finished(run);
  }

  void _giveGuess(EcoType type) {
    _logger.guessed(type);
    setState(() => _guess = type);
    _game.begin();
  }

  void _again() {
    setState(() {
      _run = null;
      _guess = null;
    });
    _game.restart();
  }

  @override
  void dispose() {
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
            if (widget.hidden)
              ValueListenableBuilder<bool>(
                valueListenable: _game.awaitingGuess,
                builder: (context, waiting, _) =>
                    waiting ? HiddenPrepare(onFeelAgain: _game.feelAgain, onGuess: _giveGuess) : const SizedBox.shrink(),
              ),
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
                guess: widget.hidden ? _guess : null,
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
    required this.onAgain,
    required this.onMenu,
    this.guess,
    super.key,
  });

  final TuningRun run;

  /// Palpite do jogador no modo de tipo oculto. `null` fora desse modo.
  final EcoType? guess;
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
            if (guess != null) ...[
              const SizedBox(height: 16),
              Text('Era ${typeLabel(run.setup.type)}', style: const TextStyle(fontSize: 24, color: kVeil)),
              const SizedBox(height: 4),
              Text(run.species.name, style: const TextStyle(fontSize: 8, color: kDim)),
              const SizedBox(height: 12),
              Text(
                guess == run.setup.type ? 'Você acertou' : 'Você disse ${typeLabel(guess!)}',
                style: TextStyle(fontSize: 16, color: guess == run.setup.type ? kSignal : kEssence),
              ),
            ],
            const SizedBox(height: 20),
            PixelButton(label: 'Repetir', color: color, onTap: onAgain),
            const SizedBox(height: 12),
            PixelButton(label: 'Menu', color: kDim, onTap: onMenu),
          ],
        ),
      ),
    );
  }
}

/// Tela escura do modo de tipo oculto, antes de a sintonia começar: só a vibração e o palpite.
/// Nada aqui depende do tipo sorteado.
class HiddenPrepare extends StatelessWidget {
  const HiddenPrepare({required this.onFeelAgain, required this.onGuess, super.key});

  final VoidCallback onFeelAgain;
  final ValueChanged<EcoType> onGuess;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: kOutline,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Sinta o sinal', style: TextStyle(fontSize: 24, color: kVeil)),
              const SizedBox(height: 12),
              const Text('Qual é o tipo?', style: TextStyle(fontSize: 16, color: kDim)),
              const SizedBox(height: 32),
              PixelButton(label: 'Sentir de novo', color: kDim, onTap: onFeelAgain),
              const SizedBox(height: 40),
              for (final type in EcoType.values) ...[
                SizedBox(width: double.infinity, child: PixelButton(label: typeLabel(type), onTap: () => onGuess(type))),
                const SizedBox(height: 12),
              ],
            ],
          ),
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
