/// Bestiário básico (docs/fase0-spec.md, seção 9): por espécie, vista e capturada. As desconhecidas aparecem
/// como silhueta.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../ritual/ritual_research_panel.dart';
import '../sprites/sprite_image.dart';
import '../type_label.dart';
import 'screen_frame.dart';

class BestiaryScreen extends StatefulWidget {
  const BestiaryScreen({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  State<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends State<BestiaryScreen> {
  Map<String, EcoSprite> _sprites = {};

  @override
  void initState() {
    super.initState();
    loadSpecies(widget.data).then((m) {
      if (mounted) setState(() => _sprites = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final b = widget.state.bestiary;
        final species = widget.data.tuning.species;
        final seen = species.where((s) => b[s.id]?.seen ?? false).length;
        final captured = species.where((s) => b[s.id]?.captured ?? false).length;
        return ScreenFrame(
          title: 'Bestiário',
          subtitle: 'Vistas $seen/${species.length} · Capturadas $captured/${species.length}',
          children: [
            for (final s in species)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: panelBox(line: (b[s.id]?.captured ?? false) ? kSignal : kPanelLine),
                child: Row(children: [
                  SpeciesImage(sprite: _sprites[s.id], silhouette: !(b[s.id]?.seen ?? false), size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((b[s.id]?.seen ?? false) ? s.name : '???', style: const TextStyle(fontSize: 16, color: kText)),
                      const SizedBox(height: 4),
                      if (b[s.id]?.seen ?? false) Text(typeLabel(s.type).toUpperCase(), style: TextStyle(fontSize: 8, color: typeColor(s.type))),
                      Text(
                        (b[s.id]?.captured ?? false) ? 'CAPTURADA' : ((b[s.id]?.seen ?? false) ? 'VISTA' : 'AINDA NÃO ENCONTRADA'),
                        style: TextStyle(fontSize: 8, color: (b[s.id]?.captured ?? false) ? kSignal : kDim),
                      ),
                      if (s.ritualOnly && (b[s.id]?.seen ?? false)) RitualResearchPanel(state: widget.state, data: widget.data, species: s),
                      // Variantes de bioma e Brilhante: vistas e capturadas por variante.
                      for (final key in widget.data.variants.keys)
                        if (b['${s.id}@$key']?.seen ?? false)
                          Text(
                            '${widget.data.variants[key]!.name.toUpperCase()}: ${(b['${s.id}@$key']?.captured ?? false) ? 'CAPTURADA' : 'VISTA'}',
                            key: Key('bestiary-${s.id}@$key'),
                            style: TextStyle(fontSize: 8, color: Color(widget.data.variants[key]!.tint), height: 1.8),
                          ),
                    ]),
                  ),
                ]),
              ),
          ],
        );
      },
    );
  }
}
