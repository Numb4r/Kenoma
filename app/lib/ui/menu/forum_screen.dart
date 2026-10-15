/// O app Fórum do celular: os três pedidos de hoje, escritos como posts do fórum Limen. Entregar um pedido pronto dá
/// XP e materiais; há um reroll por dia. Os pedidos vêm de `story/daily_quests.dart`.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../story/daily_quests.dart';
import '../colors.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'screen_frame.dart';

class ForumScreen extends StatelessWidget {
  const ForumScreen({required this.state, required this.data, required this.nowUtc, required this.epochId, super.key});

  final GameState state;
  final GameData data;
  final int Function() nowUtc;
  final int Function() epochId;

  String _reward(Quest q) => '${q.rewardXp} XP${[for (final e in q.rewardItems.entries) ' · ${e.value}× ${data.itemName(e.key)}'].join()}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final daily = state.story.daily;
        return ScreenFrame(
          title: data.forum.forum,
          subtitle: 'Pedidos de hoje · renovam à meia-noite${daily.canReroll ? ' · 1 troca' : ' · troca usada'}',
          children: [
            if (daily.quests.isEmpty) const Text('SEM PEDIDOS AINDA. ABRA O MAPA UMA VEZ.', style: TextStyle(fontSize: 8, color: kDim)),
            for (final q in daily.quests) _Post(quest: q, reward: _reward(q), state: state, data: data, nowUtc: nowUtc, epochId: epochId),
          ],
        );
      },
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({required this.quest, required this.reward, required this.state, required this.data, required this.nowUtc, required this.epochId});

  final Quest quest;
  final String reward;
  final GameState state;
  final GameData data;
  final int Function() nowUtc;
  final int Function() epochId;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final color = q.claimed ? kDim : (q.claimable ? kSignal : kPanelLine);
    return Container(
      key: Key('quest-${q.slot}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: panelBox(line: color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q.user, style: const TextStyle(fontSize: 16, color: kVeil)),
        const SizedBox(height: 6),
        Text(q.text, style: TextStyle(fontSize: 8, color: q.claimed ? kDim : kText, height: 1.8)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Stack(children: [
              Container(height: 6, color: kPanelLine),
              FractionallySizedBox(widthFactor: (q.progress / q.target).clamp(0.0, 1.0), child: Container(height: 6, color: kSignal)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${q.progress}/${q.target}', style: const TextStyle(fontSize: 8, color: kText)),
        ]),
        const SizedBox(height: 6),
        Text('RECOMPENSA: ${reward.toUpperCase()}', style: const TextStyle(fontSize: 8, color: kEssence, height: 1.8)),
        const SizedBox(height: 8),
        if (q.claimed)
          const Text('ENTREGUE', style: TextStyle(fontSize: 8, color: kDim))
        else
          Row(children: [
            Expanded(
              child: PixelButton(
                label: 'Entregar',
                color: q.claimable ? kSignal : kDim,
                onTap: () {
                  if (!state.claimDaily(q.slot, nowUtc())) {
                    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Ainda não está pronto')));
                  }
                },
              ),
            ),
            if (state.story.daily.canReroll) ...[
              const SizedBox(width: 8),
              Expanded(child: PixelButton(label: 'Trocar', color: kVeil, onTap: () => state.rerollDaily(q.slot, data.forum, epochId()))),
            ],
          ]),
      ]),
    );
  }
}
