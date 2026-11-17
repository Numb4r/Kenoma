/// O Experimentar (proposta aprovada): até três espaços para juntar materiais e o botão Tentar. Nada se gasta: acerta e
/// a receita entra no grimório, chega perto e vem uma pista, ou nada acontece. Embaixo, as receitas ainda desconhecidas
/// que usam o que o jogador já tem, como silhueta com o degrau e a pista.
library;

import 'package:flutter/material.dart';

import '../../crafting/collectors.dart';
import '../../crafting/crafting_data.dart';
import '../../crafting/crafting_state.dart';
import '../../crafting/grimoire.dart';
import '../../crafting/quality.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import 'craft_context.dart';
import 'ui_art.dart';

Future<void> showExperimentSheet(BuildContext context, {required GameState state, required GameData data, required CraftContext ctx, required void Function(String) say}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UiFrame(name: 'sheet', padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), child: _Experiment(state: state, data: data, ctx: ctx)),
    );

class _Experiment extends StatefulWidget {
  const _Experiment({required this.state, required this.data, required this.ctx});

  final GameState state;
  final GameData data;
  final CraftContext ctx;

  @override
  State<_Experiment> createState() => _ExperimentState();
}

class _ExperimentState extends State<_Experiment> {
  late final List<String?> _slots = List.filled(widget.data.craft.balance.experimentSlots, null);
  String? _result;
  int? _picking;

  CraftingBook get _book => widget.data.craft;

  /// O que dá para pôr num espaço: os materiais e os conteúdos engarrafados que o jogador tem.
  List<String> _options() {
    final s = widget.state;
    final ids = <String>{
      for (final e in s.inventory.entries)
        if (e.value > 0 && _book.item(e.key)?.tab == BagTab.materials) parseStack(e.key).id,
      for (final v in s.crafting.vessels)
        if (v.place != VesselPlace.planted && v.content != null) v.content!,
    };
    return ids.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state, d = widget.data;
    final shadows = silhouettes(s, d.recipes.values);
    // 0.24.4: Voltar com a escolha de material aberta só fecha a escolha (um nível), depois fecha o experimento.
    return PopScope(
      canPop: _picking == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _picking = null);
      },
      child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('EXPERIMENTAR', style: TextStyle(fontSize: 16, color: kVeil)),
        const Text('ERRAR NUNCA GASTA MATERIAL.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < _slots.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                key: Key('experiment-slot-$i'),
                onTap: () => setState(() => _picking = _picking == i ? null : i),
                onLongPress: () => setState(() => _slots[i] = null),
                child: UiFrame(
                  name: _picking == i ? 'cell_selected' : 'cell',
                  padding: const EdgeInsets.all(6),
                  fallbackLine: _picking == i ? kVeil : kPanelLine,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _slots[i] == null
                        ? const Center(child: Text('+', style: TextStyle(fontSize: 16, color: kDim)))
                        : ItemIcon(itemId: _slots[i]!, name: d.itemName(_slots[i]!), tint: itemTint(_book, _slots[i]!)),
                  ),
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            key: const Key('experiment-try'),
            onTap: () {
              final h = widget.ctx.here();
              final res = experiment(s, [for (final x in _slots) ?x], d.recipes.values, _book, h);
              setState(() => _result = res.learned == null ? res.text : '${res.text}: ${d.itemName(res.learned!.outId)}');
            },
            child: UiFrame(name: 'button', padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), fallbackLine: kVeil, child: const Text('TENTAR', style: TextStyle(fontSize: 16, color: kVeil))),
          ),
        ]),
        if (_picking != null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final id in _options())
              GestureDetector(
                key: Key('experiment-pick-$id'),
                onTap: () => setState(() {
                  _slots[_picking!] = id;
                  _picking = null;
                }),
                child: UiFrame(name: 'cell', padding: const EdgeInsets.all(2), child: ItemIcon(itemId: id, name: d.itemName(id), size: 32, tint: itemTint(_book, id))),
              ),
          ]),
        ],
        if (_result != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_result!.toUpperCase(), key: const Key('experiment-result'), style: const TextStyle(fontSize: 8, color: kSignal, height: 1.8))),
        const SizedBox(height: 16),
        Text('DESCONHECIDAS COM O QUE VOCÊ TEM · ${shadows.length}', style: const TextStyle(fontSize: 8, color: kSignal)),
        const SizedBox(height: 6),
        for (final r in shadows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              ItemIcon(itemId: r.outId, name: '?', size: 24, silhouette: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_book.items[r.outId]?.tier.label ?? '?'} · ${r.hint} · ${r.inputs.keys.where((id) => s.count(id) > 0 || carriedWith(s, id).isNotEmpty).map(d.itemName).join(', ')}'.toUpperCase(),
                  style: const TextStyle(fontSize: 8, color: kDim, height: 1.6),
                ),
              ),
            ]),
          ),
      ]),
    ),
    );
  }
}
