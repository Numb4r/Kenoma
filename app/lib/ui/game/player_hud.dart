/// O que o mapa mostra do Conjurador: o retrato com o nível e uma barra fina de XP no canto de baixo à esquerda,
/// e as fichas das marcações ativas com a contagem regressiva.
library;

import '../pressable.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../player/game_state.dart';
import '../../player/mark.dart';
import '../colors.dart';

class PortraitHud extends StatelessWidget {
  const PortraitHud({required this.state, required this.frame, this.onTap, super.key});

  final GameState state;

  /// Tocar no retrato abre o Perfil.
  final VoidCallback? onTap;

  /// O quadro parado do Conjurador. `null` nos testes sem sprites.
  final ui.Image? frame;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final p = state.progress;
        final overridden = state.levelOverride != null;
        return GestureDetector(
          key: const Key('portrait-hud'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.9), border: Border.all(color: kVeil, width: 3)),
              child: frame == null ? null : RawImage(image: frame, filterQuality: FilterQuality.none, fit: BoxFit.contain),
            ),
            const SizedBox(height: 2),
            Container(
              width: size,
              color: kOutline.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('NV ${state.playerLevel}${overridden ? '*' : ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: kText)),
            ),
            Container(
              key: const Key('xp-bar'),
              width: size,
              height: 4,
              color: kPanelLine,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: p.fraction.clamp(0.0, 1.0), child: Container(color: kSignal)),
            ),
          ],
        ));
      },
    );
  }
}

/// As marcações ativas: um sprite pequeno com o tempo que falta. Tocar numa abre o encontro.
class MarkChips extends StatefulWidget {
  const MarkChips({required this.state, required this.nowUtc, required this.sprites, required this.onTap, super.key});

  final GameState state;
  final int Function() nowUtc;
  final Map<String, ui.Image> sprites;
  final void Function(Mark mark) onTap;

  @override
  State<MarkChips> createState() => _MarkChipsState();
}

class _MarkChipsState extends State<MarkChips> {
  Timer? _tick;

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final now = widget.nowUtc();
        final marks = widget.state.activeMarks(now);
        if (marks.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in marks)
              Pressable(
                onTap: () => widget.onTap(m),
                child: Container(
                  key: Key('mark-${m.uid}'),
                  width: 56,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.9), border: Border.all(color: kVeil, width: 2)),
                  child: Column(children: [
                    SizedBox(height: 32, child: widget.sprites[m.speciesId] == null ? null : RawImage(image: widget.sprites[m.speciesId], filterQuality: FilterQuality.none)),
                    Text(_clock(m.secondsLeft(now)), style: const TextStyle(fontSize: 8, color: kSignal)),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
