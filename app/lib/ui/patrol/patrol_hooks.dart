/// O que o mapa do jogo liga à Patrulha do Véu: incorporar o diário ao abrir, ao voltar e a cada `journal_read_s` com ela
/// ligada; abrir o Eco do aviso raro; e o botão do HUD. O mapa só chama [PatrolHooks.tick] e [PatrolHooks.sync].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../patrol/patrol_balance.dart';
import '../../patrol/patrol_controller.dart';
import '../../patrol/patrol_launch.dart';
import '../../player/game_state.dart';
import '../../player/mark.dart';
import '../colors.dart';
import '../menu/phone_shell.dart' show phoneRoute;
import 'patrol_screen.dart';

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

/// O botão do HUD: desligada abre a tela (na primeira vez) ou liga; ligada mostra os minutos e encerra.
class PatrolHudButton extends StatelessWidget {
  const PatrolHudButton({required this.hooks, super.key});

  final PatrolHooks hooks;

  Future<void> _tap(BuildContext context) async {
    final c = hooks.controller;
    if (c.running) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kPanel,
          shape: const RoundedRectangleBorder(side: BorderSide(color: kSignal, width: 3)),
          title: const Text('ENCERRAR A PATRULHA?', style: TextStyle(fontSize: 16, color: kSignal)),
          content: Text('Ligada há ${c.status['min'] ?? 0} min.', style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CONTINUAR', style: TextStyle(fontSize: 8, color: kDim))),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ENCERRAR', style: TextStyle(fontSize: 8, color: kEssence))),
          ],
        ),
      );
      if (ok != true) return;
      await c.stop();
      await hooks.sync();
      return;
    }
    if (!hooks.state.setting(kPatrolIntroSeenKey)) {
      await Navigator.of(context).push(phoneRoute<void>(PatrolScreen(state: hooks.state, balance: hooks.balance, onMessage: hooks.onMessage)));
      return;
    }
    hooks.onMessage(await startPatrolFlow(state: hooks.state, balance: hooks.balance) ?? 'Patrulha ligada');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: hooks.controller,
        builder: (context, _) {
          final on = hooks.controller.running;
          return GestureDetector(
            key: const Key('patrol-hud'),
            onTap: () => _tap(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: on ? kSignal : kVeil, width: 2)),
              child: Text(on ? 'PATRULHA · ${hooks.controller.status['min'] ?? 0} MIN' : 'PATRULHA', style: TextStyle(fontSize: 8, color: on ? kSignal : kVeil)),
            ),
          );
        },
      );
}
