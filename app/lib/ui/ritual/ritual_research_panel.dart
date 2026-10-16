/// A seção "Ritual" do detalhe da espécie no Bestiário: os espaços da receita, escritos se a pesquisa já os revelou e ???
/// se não. Abrir a seção marca a novidade como vista (some a bolinha do Bestiário).
library;

import 'package:flutter/material.dart';

import '../../crafting/ritual.dart';
import '../../data/game_data.dart';
import '../../data/tuning_data.dart';
import '../../player/game_state.dart';
import '../tema.dart';
import 'ritual_text.dart';

class RitualResearchPanel extends StatefulWidget {
  const RitualResearchPanel({required this.state, required this.data, required this.species, super.key});

  final GameState state;
  final GameData data;
  final EcoSpecies species;

  @override
  State<RitualResearchPanel> createState() => _RitualResearchPanelState();
}

class _RitualResearchPanelState extends State<RitualResearchPanel> {
  @override
  void initState() {
    super.initState();
    // Depois do quadro: marcar como visto mexe no estado, que a própria tela escuta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markRitualViewed(widget.state, widget.species.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.data.ritual.of(widget.species.id);
    if (r == null) return const SizedBox.shrink();
    final revealed = ritualRevealed(widget.state, r);
    const labels = ['Condição', 'Material', 'Círculo'];
    return Padding(
      key: Key('ritual-research-${widget.species.id}'),
      padding: const EdgeInsets.only(top: KEspaco.s1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RITUAL · $revealed/${r.slotCount}', style: KTexto.rotulo.copyWith(color: KCores.veuClaro, fontSize: 10)),
        for (var i = 0; i < r.slotCount; i++)
          Text(
            '${labels[i == 0 ? 0 : (i == r.circleIndex ? 2 : 1)]}: ${ritualSlotText(r, i, revealed, widget.species.type, widget.data.itemName)}',
            key: Key('ritual-research-${widget.species.id}-$i'),
            style: KTexto.corpoPequeno.copyWith(fontSize: 12, color: i < revealed ? KCores.texto : KCores.textoMudo),
          ),
      ]),
    );
  }
}
