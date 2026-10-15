/// A Bancada (docs/fase0-spec.md, seção 7): fabricar selos e tônico, e destilar Ecos em Essência. As receitas
/// são improviso: valem em qualquer lugar.
library;

import 'package:flutter/material.dart';

import '../../crafting/crafting.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import '../type_label.dart';
import 'screen_frame.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  bool _distill = false;
  Map<String, EcoSprite> _sprites = {};

  @override
  void initState() {
    super.initState();
    loadSpecies(widget.data).then((m) {
      if (mounted) setState(() => _sprites = m);
    });
  }

  void _say(String text) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _confirmDistill(CreatureInstance c) async {
    final d = widget.data;
    final sp = d.species(c.speciesId);
    if (sp == null) return;
    final qty = distillYield(c.level, widget.state.balance);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: kEssence, width: 3)),
        title: Text('DESTILAR ${sp.name.toUpperCase()}?', style: const TextStyle(fontSize: 16, color: kEssence)),
        content: Text('Vira $qty × ${d.itemName('item.essence.${sp.type.name}')}. A criatura sai da coleção.', style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR', style: TextStyle(fontSize: 8, color: kDim))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('DESTILAR', style: TextStyle(fontSize: 8, color: kEssence))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final got = distill(widget.state, c.uid, d);
    if (got != null) _say('+${got.qty} ${d.itemName(got.itemId)}');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => ScreenFrame(
        title: 'Bancada',
        subtitle: 'Improviso: vale em qualquer lugar',
        children: [
          Row(children: [
            Expanded(child: PixelButton(label: 'Fabricar', color: _distill ? kDim : kSignal, onTap: () => setState(() => _distill = false))),
            const SizedBox(width: 8),
            Expanded(child: PixelButton(label: 'Destilar', color: _distill ? kEssence : kDim, onTap: () => setState(() => _distill = true))),
          ]),
          const SizedBox(height: 16),
          if (_distill) ..._distillTab() else ..._craftTab(),
        ],
      ),
    );
  }

  List<Widget> _craftTab() {
    final s = widget.state, d = widget.data;
    return [
      for (final r in d.recipes.values)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: panelBox(line: canCraft(s, r) ? kSignal : kPanelLine),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.itemName(r.outId).toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
            const SizedBox(height: 6),
            for (final e in r.inputs.entries) _need(d.itemName(e.key), s.count(e.key), e.value),
            if (r.anyEssence > 0) _need('Essência (qualquer tipo)', essenceTotal(s), r.anyEssence),
            const SizedBox(height: 8),
            PixelButton(
              label: 'Fabricar',
              color: canCraft(s, r) ? kSignal : kDim,
              onTap: () => craftRecipe(s, r) ? _say('+${r.outQty} ${d.itemName(r.outId)}') : _say('Falta ingrediente'),
            ),
          ]),
        ),
    ];
  }

  Widget _need(String name, int have, int need) => Text(
        '${name.toUpperCase()}  $have/$need',
        style: TextStyle(fontSize: 8, height: 1.8, color: have >= need ? kSignal : kEssence),
      );

  List<Widget> _distillTab() {
    final s = widget.state, d = widget.data;
    if (s.collection.isEmpty) return [const Text('NENHUMA CRIATURA PARA DESTILAR.', style: TextStyle(fontSize: 8, color: kDim))];
    return [
      const Text('UM ECO VIRA ESSÊNCIA DO TIPO DELE: 3 (NV 1–7), 4 (NV 8–14) OU 5 (NV 15–20). ECOS NO CÍRCULO NÃO SAEM.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
      const SizedBox(height: 12),
      for (final c in s.collection.reversed)
        Builder(builder: (context) {
          final sp = d.species(c.speciesId);
          final locked = distillBlocker(s, c.uid) != null;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: locked ? () => _say('Tire do Círculo antes de destilar') : () => _confirmDistill(c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: panelBox(line: locked ? kPanelLine : kEssence),
              child: Row(children: [
                SpeciesImage(sprite: _sprites[c.speciesId], size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sp?.name ?? c.speciesId, style: const TextStyle(fontSize: 16, color: kText)),
                    Text('NV ${c.level}${sp == null ? '' : ' · ${typeLabel(sp.type).toUpperCase()}'}', style: const TextStyle(fontSize: 8, color: kDim)),
                  ]),
                ),
                Text(locked ? 'NO CÍRCULO' : '→ ${distillYield(c.level, s.balance)} ESSÊNCIA', style: TextStyle(fontSize: 8, color: locked ? kDim : kEssence)),
              ]),
            ),
          );
        }),
    ];
  }
}
