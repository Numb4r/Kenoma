/// O Círculo (docs/fase0-spec.md, seção 6): 3 espaços ativos escolhidos da coleção. Cada criatura ativa aplica a
/// habilidade de mapa, dá bônus de tolerância se vence o tipo do alvo e ganha XP por sintonia.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../data/tuning_data.dart';
import '../../player/circle.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart';
import '../type_label.dart';
import 'screen_frame.dart';

/// Texto curto da habilidade de uma espécie no nível dado ("Aura +5 m").
String abilityText(EcoSpecies sp, int level, List<(int, int)> bands) {
  final a = sp.ability;
  if (a == null) return '';
  final v = a.bands[abilityBandIndex(level, bands).clamp(0, a.bands.length - 1)];
  return switch (a.kind) {
    'aura_bonus_m' => 'Aura +$v m',
    'spark_pickup_bonus_m' => 'Coleta +$v m',
    'tracker_range_m' => 'Rastreador $v m',
    _ => a.kind,
  };
}

class CircleScreen extends StatefulWidget {
  const CircleScreen({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
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
        final s = widget.state;
        final a = abilitiesOf(s, widget.data);
        final bands = widget.data.tuning.abilityBands;
        return ScreenFrame(
          title: 'Círculo',
          subtitle: 'Até 3 criaturas ativas · ${s.circle.length}/$circleSlots',
          children: [
            Row(children: [
              for (var i = 0; i < circleSlots; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _Slot(creature: i < s.circle.length ? s.creature(s.circle[i]) : null, data: widget.data, sprites: _sprites, bands: bands)),
              ],
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panelBox(),
              child: Text(
                'EFEITO NO MAPA\nAURA +${a.auraBonusM.round()} M · COLETA +${a.pickupBonusM.round()} M · '
                'RASTREADOR ${a.trackerRangeM > 0 ? '${a.trackerRangeM.round()} M' : 'PADRÃO'}',
                style: const TextStyle(fontSize: 8, color: kText, height: 1.8),
              ),
            ),
            const SectionTitle('Coleção'),
            if (s.collection.isEmpty) const Text('NENHUMA CRIATURA AINDA.', style: TextStyle(fontSize: 8, color: kDim)),
            for (final c in s.collection.reversed) _Tile(creature: c, state: s, data: widget.data, sprites: _sprites, bands: bands),
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.creature, required this.data, required this.sprites, required this.bands});

  final CreatureInstance? creature;
  final GameData data;
  final Map<String, EcoSprite> sprites;
  final List<(int, int)> bands;

  @override
  Widget build(BuildContext context) {
    final c = creature;
    final sp = c == null ? null : data.species(c.speciesId);
    return Container(
      height: 116,
      padding: const EdgeInsets.all(6),
      decoration: panelBox(line: c == null ? kPanelLine : kSignal),
      child: c == null || sp == null
          ? const Center(child: Text('VAZIO', style: TextStyle(fontSize: 8, color: kDim)))
          : Column(children: [
              SpeciesImage(sprite: sprites[c.speciesId], size: 56),
              Text('NV ${c.level}', style: const TextStyle(fontSize: 8, color: kText)),
              Text(abilityText(sp, c.level, bands).toUpperCase(), style: const TextStyle(fontSize: 8, color: kSignal), textAlign: TextAlign.center),
            ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.creature, required this.state, required this.data, required this.sprites, required this.bands});

  final CreatureInstance creature;
  final GameState state;
  final GameData data;
  final Map<String, EcoSprite> sprites;
  final List<(int, int)> bands;

  @override
  Widget build(BuildContext context) {
    final sp = data.species(creature.speciesId);
    final active = state.inCircle(creature.uid);
    final next = state.balance.creatureCurvePerLevel * creature.level;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!state.toggleCircle(creature.uid)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O Círculo tem 3 espaços. Tire alguém antes.')));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: panelBox(line: active ? kSignal : kPanelLine),
        child: Row(children: [
          SpeciesImage(sprite: sprites[creature.speciesId]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sp?.name ?? creature.speciesId, style: const TextStyle(fontSize: 16, color: kText)),
              const SizedBox(height: 4),
              Text(
                'NV ${creature.level}${sp == null ? '' : ' · ${typeLabel(sp.type).toUpperCase()}'}'
                '${creature.level >= state.balance.creatureLevelCap ? '' : ' · XP ${creature.xp}/$next'}',
                style: const TextStyle(fontSize: 8, color: kDim),
              ),
              if (sp != null) Text(abilityText(sp, creature.level, bands).toUpperCase(), style: const TextStyle(fontSize: 8, color: kSignal)),
            ]),
          ),
          Text(active ? 'ATIVO' : 'TOCAR', style: TextStyle(fontSize: 8, color: active ? kSignal : kDim)),
        ]),
      ),
    );
  }
}
