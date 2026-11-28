/// Destilar Ecos em Essência e fundir (docs/fase0-spec.md, seção 7; docs/GDD.md, "Fusão"). Era a Bancada antiga: na 0.24.0
/// o fabricar foi para a Bancada nova (`ui/craft/bench_screen.dart`), que liga para esta tela.
library;

import 'package:flutter/material.dart';

import '../../crafting/crafting.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import '../type_label.dart';
import 'fusion_screen.dart';
import 'screen_frame.dart';
import '../kit.dart';

class DistillScreen extends StatefulWidget {
  const DistillScreen({required this.state, required this.data, this.openFusion = false, super.key});

  /// Abre já na aba Fundir (o botão do Bestiário).
  final bool openFusion;

  final GameState state;
  final GameData data;

  @override
  State<DistillScreen> createState() => _DistillScreenState();
}

class _DistillScreenState extends State<DistillScreen> {
  bool _distill = true;
  late bool _fusion = widget.openFusion;
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
    final qty = distillQty(widget.state, c.level, widget.data, hidden: c.hidden);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => KitAlertDialog(
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
        title: 'Destilar e fundir',
        subtitle: 'Ecos viram Essência; Ecos iguais viram Espírito',
        children: [
          // Wrap: três abas de 16 pt não cabem lado a lado nas telas estreitas.
          Wrap(spacing: 8, runSpacing: 8, children: [
            PixelButton(label: 'Destilar', color: _distill ? kEssence : kDim, onTap: () => setState(() { _distill = true; _fusion = false; })),
            // Antes do nível da fusão a aba é um ???.
            PixelButton(
              label: widget.state.playerLevel < widget.state.cb.fusionLevel ? '???' : 'Fusão',
              color: _fusion ? kVeil : kDim,
              onTap: () => setState(() { _fusion = true; _distill = false; }),
            ),
          ]),
          const SizedBox(height: 16),
          if (_fusion) FusionPanel(state: widget.state, data: widget.data, sprites: _sprites) else ..._distillTab(),
        ],
      ),
    );
  }

  List<Widget> _distillTab() {
    final s = widget.state, d = widget.data;
    if (s.collection.isEmpty) return [const Text('NENHUMA CRIATURA PARA DESTILAR.', style: TextStyle(fontSize: 8, color: kDim))];
    return [
      const Text('UM ECO VIRA ESSÊNCIA DO TIPO DELE: 3 (NV 1–7), 4 (NV 8–14) OU 5 (NV 15–20). ECOS NO CÍRCULO NÃO SAEM.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
      const SizedBox(height: 12),
      for (final c in s.collection.reversed)
        Builder(builder: (context) {
          final sp = d.species(c.speciesId);
          final blocker = distillBlocker(s, c.uid), locked = blocker != null;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: locked ? () => _say(blocker) : () => _confirmDistill(c),
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
                Text(locked ? (s.home.holds(c.uid) ? 'EM CASA' : (s.inCircle(c.uid) ? 'NO CÍRCULO' : 'SÓ ECO')) : '→ ${distillYield(c.level, s.balance)} ESSÊNCIA', style: TextStyle(fontSize: 8, color: locked ? kDim : kEssence)),
              ]),
            ),
          );
        }),
    ];
  }
}
