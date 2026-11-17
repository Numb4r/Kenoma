/// Os coletores plantados com a distância e o estado (cheio, enchendo, esperando), no Radar e em Rotas (docs/GDD.md,
/// "Regras da fase 1"). Só o dono vê: é a camada pessoal.
library;

import 'package:flutter/material.dart';

import '../../crafting/collectors.dart';
import '../../crafting/crafting_state.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import 'bag_screen.dart' show plantedLabel;
import 'craft_context.dart';

class PlantedList extends StatelessWidget {
  const PlantedList({required this.state, required this.data, required this.ctx, super.key});

  final GameState state;
  final GameData data;
  final CraftContext ctx;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final planted = state.crafting.at(VesselPlace.planted).toList();
          final now = ctx.nowUtc();
          final me = ctx.here();
          return Column(key: const Key('planted-list'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('COLETORES PLANTADOS · ${planted.length}', style: const TextStyle(fontSize: 8, color: kSignal)),
            const SizedBox(height: 6),
            if (planted.isEmpty) const Text('NENHUM. PLANTE PELA BOLSA, ABA CONDIÇÕES.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
            for (final v in planted)
              Builder(builder: (_) {
                final st = updatePlanted(v, now, (t) => ctx.hereAt(v.lat, v.lon, t), data.craft);
                final d = metersBetween(me.lat, me.lon, v.lat, v.lon);
                final what = v.content == null ? '' : ' · ${data.itemName(v.content!)} ${v.quality.label}';
                return Text(
                  '${data.itemName(v.kind)} · ${d.round()} m · ${plantedLabel(st)}$what'.toUpperCase(),
                  style: TextStyle(fontSize: 8, color: st == PlantedState.full ? kSignal : (st == PlantedState.filling ? kVeil : kDim), height: 1.8),
                );
              }),
          ]);
        },
      );
}
