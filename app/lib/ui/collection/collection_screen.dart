/// Coleção e bolsa: as criaturas capturadas e o que o jogador carrega. O Círculo, o bestiário e a
/// bancada têm telas próprias.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
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
    return Scaffold(
      backgroundColor: kOutline,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final s = widget.state;
            final items = [for (final e in s.inventory.entries) if (e.value > 0) e]..sort((a, b) => a.key.compareTo(b.key));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(width: 48, height: 48, child: Center(child: Text('<', style: TextStyle(fontSize: 24, color: kText)))),
                  ),
                  const Expanded(child: Text('COLEÇÃO', style: TextStyle(fontSize: 24, color: kVeil))),
                ]),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kPanelLine, width: 2)),
      child: Row(children: [
        SizedBox(
          width: 64,
          height: 64,
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
            if (variant != null)
              Text('VARIANTE ${variant.name.toUpperCase()} · ${variant.trait.toUpperCase()}', key: Key('variant-${creature.uid}'), style: TextStyle(fontSize: 8, color: Color(variant.tint), height: 1.8)),
            Text('CAPTURADO $date', style: const TextStyle(fontSize: 8, color: kDim)),
          ]),
        ),
      ]),
    );
  }
}
