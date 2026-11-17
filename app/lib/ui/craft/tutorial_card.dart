/// A quest que ensina o crafting na tela (0.24.1): a lista de tarefas no topo da Bolsa e da Bancada, no jeito das tarefas
/// do Bestiário, e a marca do mentor no que o passo de agora pede.
library;

import 'package:flutter/material.dart';

import '../../crafting/tutorial.dart';
import '../../player/game_state.dart';
import '../../story/mentor_script.dart';
import '../menu/bestiary/bestiary_widgets.dart' show KTick;
import '../tema.dart';

/// A lista de tarefas da quest, enquanto ela está ligada.
class TutorialCard extends StatelessWidget {
  const TutorialCard({required this.state, required this.script, super.key});

  final GameState state;
  final MentorScript script;

  @override
  Widget build(BuildContext context) {
    final now = currentStep(state);
    if (now == null) return const SizedBox.shrink();
    final labels = script.craftTutorialSteps;
    return Container(
      key: const Key('craft-tutorial'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.veuVioleta, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(script.craftTutorialTitle.toUpperCase(), style: KTexto.rotulo.copyWith(fontSize: 8, color: KCores.veuClaro)),
        const SizedBox(height: 8),
        for (final st in TutStep.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                width: 15,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: stepDone(state, st) ? KCores.sinalCiano : KCores.superficie2,
                  border: Border.all(color: st == now ? KCores.veuVioleta : KCores.contorno, width: 2),
                ),
                child: stepDone(state, st) ? const KTick(color: KCores.fundo) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  st.index < labels.length ? labels[st.index] : st.name,
                  style: KTexto.corpoPequeno.copyWith(fontSize: 13, color: stepDone(state, st) || st == now ? KCores.texto : KCores.textoMudo),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Uma linha de ajuda do passo de agora, no violeta do Véu.
class TutorialHint extends StatelessWidget {
  const TutorialHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('◆ ${text.toUpperCase()}', style: const TextStyle(fontSize: 8, color: KCores.veuClaro, height: 1.8)),
      );
}

/// A marca do mentor em volta do que o passo de agora pede (um botão, uma receita).
class TutorialMark extends StatelessWidget {
  const TutorialMark({required this.on, required this.child, super.key});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => on
      ? Container(key: const Key('tutorial-mark'), padding: const EdgeInsets.all(2), decoration: BoxDecoration(border: Border.all(color: KCores.veuVioleta, width: 2)), child: child)
      : child;
}
