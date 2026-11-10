/// O que o mapa do jogo liga à Patrulha do Véu: incorporar o diário ao abrir, ao voltar e a cada `journal_read_s` com ela
/// ligada; abrir o Eco do aviso raro; e o atalho do HUD. O mapa só chama [PatrolHooks.tick] e [PatrolHooks.sync].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../patrol/patrol_balance.dart';
import '../../patrol/patrol_controller.dart';
import '../../patrol/patrol_launch.dart';
import '../../player/game_state.dart';
import '../../player/mark.dart';
import '../colors.dart';
import '../game/hud_bar.dart' show ShortcutChip;

class PatrolHooks {
  PatrolHooks({required this.state, required this.balance, required this.nowUtc, required this.onMessage, required this.onFocus}) {
    patrolFocusUid.addListener(_onFocusAsked);
  }

  final GameState state;
  final PatrolBalance balance;
  final int Function() nowUtc;
  final void Function(String message) onMessage;

  /// O jogador tocou no aviso de um Eco raro: o mapa abre o encontro com a marca dele.
  final void Function(Mark mark) onFocus;

  PatrolController get controller => PatrolController.instance;

  /// Com a Patrulha ligada, quem coleta é o serviço: o mapa fica calado e só mostra.
  bool get active => controller.running;
  int _readIn = 0;

  /// Um tique por segundo com o mapa à vista.
  void tick() {
    if (!active || _readIn-- > 0) return;
    _readIn = balance.journalReadS;
    unawaited(sync());
  }

  /// Incorpora o diário e avisa o que entrou.
  Future<void> sync() async {
    try {
      final r = await controller.incorporate(state, nowUtc: nowUtc(), onCell: _visited);
      final got = [
        if (r.sparks > 0) '+${r.sparks} ${r.sparks == 1 ? 'Fagulha' : 'Fagulhas'}',
        if (r.materials > 0) '+${r.materials} ${r.materials == 1 ? 'material' : 'materiais'}',
        if (r.marks > 0) '${r.marks} ${r.marks == 1 ? 'Eco marcado' : 'Ecos marcados'}',
      ];
      if (got.isNotEmpty) onMessage('Patrulha: ${got.join(', ')}');
      if (r.ended) onMessage('A Patrulha acabou. O resumo está no Chat');
    } catch (_) {
      // sem disco ou sem plugin: tenta no próximo
    }
    _openFocused();
  }

  /// Uma célula z17 por onde a Patrulha passou.
  void _visited(int x17, int y17, int tUtc) => state.markVisited(x17, y17);

  void _onFocusAsked() => unawaited(sync()); // a marca pode ainda estar só no diário

  void _openFocused() {
    final uid = patrolFocusUid.value;
    if (uid == null) return;
    final m = state.markOf(uid);
    if (m == null) return;
    patrolFocusUid.value = null;
    onFocus(m);
  }

  void dispose() => patrolFocusUid.removeListener(_onFocusAsked);
}

/// O atalho da Patrulha na faixa de atalhos do HUD: só existe com ela ligada, mostra os minutos e abre o app Patrulha.
class PatrolShortcut extends StatelessWidget {
  const PatrolShortcut({required this.hooks, required this.onOpen, super.key});

  final PatrolHooks hooks;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: hooks.controller,
        builder: (context, _) => !hooks.controller.running
            ? const SizedBox.shrink()
            : ShortcutChip(key: const Key('patrol-hud'), label: 'PATRULHA · ${hooks.controller.status['min'] ?? 0} MIN', color: kSignal, onTap: onOpen),
      );
}
