/// Coleção e bolsa: as criaturas capturadas e o que o jogador carrega. O Círculo, o bestiário e a
/// bancada têm telas próprias.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../core/species_ids.dart';
import '../../player/attributes.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../menu/phone_shell.dart';
import '../sprites/sprite_image.dart';
import '../type_label.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _sprites = <String, EcoSprite>{};

  @override
  void initState() {
    super.initState();
    _loadSprites();
  }

  Future<void> _loadSprites() async {
    for (final s in widget.data.tuning.species) {
      _sprites[s.id] = await EcoSprite.load(s.id);
    }
    if (mounted) setState(() {});
  }

  static String _date(int utc) {
    final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return PhoneScreen(
      title: 'Coleção',
      child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final s = widget.state;
            final items = [for (final e in s.inventory.entries) if (e.value > 0) e]..sort((a, b) => a.key.compareTo(b.key));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text('GRUPO ${s.groupCode}', style: const TextStyle(fontSize: 8, color: kDim)),
                const SizedBox(height: 16),
                Text('CRIATURAS · ${s.collection.length}', style: const TextStyle(fontSize: 16, color: kSignal)),
                const SizedBox(height: 8),
                if (s.collection.isEmpty)
                  const Text('NENHUMA AINDA. TOQUE NUM ECO DENTRO DA AURA.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
                for (final c in s.collection.reversed) _CreatureTile(creature: c, data: widget.data, sprite: _sprites[c.speciesId], date: _date(c.capturedUtc)),
                const SizedBox(height: 24),
                const Text('BOLSA', style: TextStyle(fontSize: 16, color: kSignal)),
                const SizedBox(height: 8),
                if (items.isEmpty) const Text('VAZIA.', style: TextStyle(fontSize: 8, color: kDim)),
                for (final e in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(widget.data.itemName(e.key).toUpperCase(), style: const TextStyle(fontSize: 8, color: kText))),
                      Text('×${e.value}', style: const TextStyle(fontSize: 8, color: kEssence)),
                    ]),
                  ),
              ],
            );
          },
      ),
    );
  }
}

class _CreatureTile extends StatelessWidget {
  const _CreatureTile({required this.creature, required this.data, required this.sprite, required this.date});

  final CreatureInstance creature;
  final GameData data;
  final EcoSprite? sprite;
  final String date;

  @override
  Widget build(BuildContext context) {
    final species = data.species(creature.speciesId);
    final variant = data.variantInfo(biome: creature.variant, shiny: creature.shiny);
    final attrs = attributesOf(creature, data);
    final spirit = tierOfId(creature.speciesId) == SpeciesTier.spirit;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kPanelLine, width: 2)),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          // A aura do Espírito: o brilho suave do Véu, o único brilho permitido.
          decoration: spirit ? const BoxDecoration(gradient: RadialGradient(colors: [Color(0x669B7BFF), Color(0x009B7BFF)])) : null,
          child: sprite == null
              ? null
              : variant == null
                  ? RawImage(image: sprite!.normal, filterQuality: FilterQuality.none, fit: BoxFit.contain)
                  : ColorFiltered(
                      colorFilter: ColorFilter.mode(Color(variant.tint).withValues(alpha: 0.4), BlendMode.srcATop),
                      child: RawImage(image: sprite!.normal, filterQuality: FilterQuality.none, fit: BoxFit.contain),
                    ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(species?.name ?? creature.speciesId, style: const TextStyle(fontSize: 16, color: kText)),
            const SizedBox(height: 4),
            Text(
              'NV ${creature.level}${species == null ? '' : ' · ${typeLabel(species.type).toUpperCase()}'}',
              style: const TextStyle(fontSize: 8, color: kDim),
            ),
            Text('PODER ${attrs.power}', key: Key('power-${creature.uid}'), style: const TextStyle(fontSize: 8, color: kEssence, height: 1.8)),
            if (attrs.ability != null) Text('HABILIDADE ${attrs.ability!.toUpperCase()}', key: Key('ability-${creature.uid}'), style: const TextStyle(fontSize: 8, color: kSignal, height: 1.8)),
            Text(attrs.traitsCounter.toUpperCase(), key: Key('traits-${creature.uid}'), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
            for (final (i, t) in attrs.traits.indexed)
              Text('VARIANTE ${t.name.toUpperCase()} · ${t.description.toUpperCase()}',
                  key: Key(i == 0 && creature.traits.isEmpty ? 'variant-${creature.uid}' : 'trait-${creature.uid}-${t.key}'), style: TextStyle(fontSize: 8, color: Color(t.tint), height: 1.8)),
            Text('CAPTURADO $date', style: const TextStyle(fontSize: 8, color: kDim)),
          ]),
        ),
      ]),
    );
  }
}
