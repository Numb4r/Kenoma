import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../capture/hidden_type.dart';
import '../../capture/session.dart';
import '../../capture/tuning_balance.dart';
import '../../capture/tuning_setup.dart';
import '../../capture/vibe.dart';
import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../data/tuning_data.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart';
import 'tuning_layout.dart';
import 'tuning_painter.dart';
import 'vibration_driver.dart';

/// Uma sintonia terminada: o que foi preparado, como correu e o resultado.
class TuningRun {
  const TuningRun({required this.setup, required this.species, required this.session, required this.outcome});

  final TuningSetup setup;
  final EcoSpecies species;
  final TuningSession session;
  final TuningOutcome outcome;
}

/// Tela de sintonia em Flame. Só avança a sessão, desenha e repassa o giro do dial:
/// as regras estão em `capture/`.
///
/// Com [hidden], cada sintonia sorteia o tipo entre as espécies de [pool] e mostra uma silhueta
/// neutra, sem dizer qual é.
class TuningGame extends FlameGame with DragCallbacks {
  TuningGame({
    required this.pool,
    required this.buildSetup,
    required this.balance,
    required this.vibration,
    required this.onFinished,
    this.hidden = false,
    bool showTarget = false,
  }) : showTarget = showTarget && !hidden;

  final List<EcoSpecies> pool;
  final TuningSetup Function(EcoSpecies species) buildSetup;
  final TuningBalance balance;
  final VibrationPlayer vibration;
  final void Function(TuningRun run) onFinished;
  final bool hidden;

  /// Debug: marca o alvo e a tolerância no dial. Fica desligado no modo de tipo oculto.
  final bool showTarget;

  /// No modo oculto, verdadeiro entre o sorteio do tipo e o palpite do jogador. A sintonia só
  /// começa (o tempo só corre) depois do palpite.
  final awaitingGuess = ValueNotifier<bool>(false);

  late TuningSetup setup;
  late EcoSpecies species;
  late TuningSession session;
  late Pcg32 _rng;
  final _sprites = <String, EcoSprite>{};
  EcoSprite? _neutral;
  double _clock = 0;
  double _dial = 0.5;
  double? _lastAngle;
  int _runs = 0;
  bool _reported = false;

  @override
  Color backgroundColor() => kOutline;

  @override
  Future<void> onLoad() async {
    for (final s in pool) {
      _sprites[s.id] = await EcoSprite.load(s.id);
    }
    if (hidden) _neutral = await EcoSprite.loadNeutral();
    restart();
  }

  /// Nova sintonia. No modo oculto, sorteia outro tipo.
  void restart() {
    _rng = Pcg32(fnv1a64([DateTime.now().microsecondsSinceEpoch, _runs++]), saltKenoma);
    species = hidden ? pickHidden(pool, (s) => s.type, _rng) : pool.first;
    setup = buildSetup(species);
    session = setup.start(balance, _rng);
    _dial = 0.5;
    _reported = false;
    awaitingGuess.value = hidden;
    // A vibração da sintonia é só alerta e ritmo, não identifica o tipo. A identidade fica para o
    // modo de tipo oculto, que é ferramenta de debug.
    if (hidden) feelAgain();
  }

  /// Toca a vibração de identidade do tipo (ferramenta de debug do modo de tipo oculto).
  void feelAgain() => vibration.play(identityPattern(setup.type));

  /// O jogador deu o palpite: a sintonia começa.
  void begin() => awaitingGuess.value = false;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    if (!isLoaded || awaitingGuess.value || !session.running) return;
    for (final cue in session.step(math.min(dt, 0.05), dial: _dial)) {
      vibration.play(cue.pattern);
    }
    if (!session.running && !_reported) {
      _reported = true;
      final outcome = resolveTuning(session, _rng);
      vibration.play(outcome.success ? successPattern : failPattern);
      onFinished(TuningRun(setup: setup, species: species, session: session, outcome: outcome));
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isLoaded) return;
    final s = session;
    paintTuning(
      canvas,
      Size(size.x, size.y),
      TuningView(
        dial: _dial,
        target: s.targetFrequency,
        tolerance: s.tolerance,
        progress: s.progress,
        timeRemaining: s.timeRemaining,
        timeLimit: s.timeLimitS,
        aligned: s.running && s.aligned,
        tremble: s.signal.trembleAt(s.t),
        clock: _clock,
        type: setup.type,
        sealLabel: setup.seal.name,
        tonic: setup.tonic != null,
        showTarget: showTarget,
        hidden: hidden,
      ),
      hidden ? _neutral : _sprites[species.id],
    );
  }

  TuningLayout get _layout => TuningLayout(Size(size.x, size.y));

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = Offset(event.canvasPosition.x, event.canvasPosition.y);
    _lastAngle = _layout.isDialTouch(p) ? _layout.angleOf(p) : null;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final last = _lastAngle;
    if (last == null) return;
    final angle = _layout.angleOf(Offset(event.canvasEndPosition.x, event.canvasEndPosition.y));
    _dial = dialAfterTurn(_dial, angleDelta(last, angle));
    _lastAngle = angle;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _lastAngle = null;
  }
}
