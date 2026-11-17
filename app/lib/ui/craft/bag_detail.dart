/// O detalhe de um item da Bolsa (proposta aprovada, tela Detalhe), numa folha de baixo: de onde veio, quantos de cada
/// qualidade, as receitas conhecidas que usam o item e as silhuetas com pista das desconhecidas, os botões da receita e
/// de fixar no topo, e o descarte no rodapé (quantos, ou "só comuns", e segurar o botão).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../crafting/bag.dart';
import '../../crafting/crafting_data.dart';
import '../../crafting/crafting_state.dart';
import '../../crafting/grimoire.dart';
import '../../crafting/loadout.dart';
import '../../crafting/quality.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import 'craft_context.dart';
import 'ui_art.dart';

Future<void> showBagDetail(
  BuildContext context, {
  required GameState state,
  required GameData data,
  required CraftContext ctx,
  required String itemId,
  void Function(Recipe r)? onOpenRecipe,
  required void Function(String) say,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UiFrame(
        name: 'sheet',
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        fallbackFill: kPanel,
        child: _BagDetail(state: state, data: data, ctx: ctx, itemId: itemId, onOpenRecipe: onOpenRecipe, say: say),
      ),
    );

/// De onde vem um item, em poucas palavras.
String itemOrigin(GameData data, ItemDef? def, String id) {
  if (def == null) return '';
  return switch (def.kind) {
    'material' => 'Coletado no mapa. A qualidade vem do lugar e da lua.',
    'essence' || 'essence_trait' || 'essence_prismatic' || 'essence_crimson' => 'Destilação de Ecos.',
    'essence_dust' => 'Fagulhas e descarte de itens.',
    'condition' => 'Um coletor, numa condição do mundo.',
    _ => () {
        final r = data.recipes.values.where((r) => r.outId == id).firstOrNull;
        return r == null ? '' : 'Receita: ${r.bench ? 'Bancada de casa' : 'improviso'}.';
      }(),
  };
}

class _BagDetail extends StatefulWidget {
  const _BagDetail({required this.state, required this.data, required this.ctx, required this.itemId, required this.say, this.onOpenRecipe});

  final GameState state;
  final GameData data;
  final CraftContext ctx;
  final String itemId;
  final void Function(Recipe r)? onOpenRecipe;
  final void Function(String) say;

  @override
  State<_BagDetail> createState() => _BagDetailState();
}

class _BagDetailState extends State<_BagDetail> {
  int _qty = 1;
  bool _onlyCommon = false;
  double _hold = 0;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  CraftingBook get _book => widget.data.craft;

  void _startHold() {
    _holdTimer?.cancel();
    _hold = 0;
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _hold += 0.05);
      if (_hold < 1) return;
      t.cancel();
      _discard();
    });
  }

  void _endHold() {
    _holdTimer?.cancel();
    if (mounted) setState(() => _hold = 0);
  }

  void _discard() {
    final s = widget.state;
    final key = _onlyCommon ? widget.itemId : _discardKey();
    final n = _onlyCommon ? s.countQ(widget.itemId, Quality.common) : _qty;
    final got = discard(s, _book, key, n);
    _hold = 0;
    if (got == null) return widget.say('Não há tanto');
    widget.say(got.qty > 0 ? 'Descartado. +${got.qty} ${widget.data.itemName(got.dust)}' : 'Descartado');
    if (s.count(widget.itemId) == 0 && mounted) Navigator.of(context).pop();
    if (mounted) setState(() => _qty = 1);
  }

  /// Sem "só comuns", descarta da pior pilha que tenha a quantidade.
  String _discardKey() {
    for (final q in Quality.values) {
      if (widget.state.countQ(widget.itemId, q) >= _qty) return stackKey(widget.itemId, q);
    }
    return widget.itemId;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final s = widget.state, d = widget.data, id = widget.itemId;
          final def = _book.items[id];
          final recipes = d.recipes.values;
          final known = knownUsing(s, recipes, _book, id);
          final shadows = silhouettes(s, recipes, itemId: id);
          final producer = recipes.where((r) => r.outId == id && isKnown(s, r)).firstOrNull;
          final total = s.count(id);
          final maxQ = [for (final q in Quality.values) s.countQ(id, q)].reduce((a, b) => a > b ? a : b);
          return SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                ItemIcon(itemId: id, name: d.itemName(id), tint: itemTint(_book, id)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.itemName(id).toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
                    Text('${def?.tier.label ?? ''} · ×$total'.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
                  ]),
                ),
              ]),
              if ((def?.desc ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(def!.desc, style: const TextStyle(fontSize: 12, color: kText, height: 1.4))),
              const SizedBox(height: 8),
              Text(itemOrigin(d, def, id), style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
              const SizedBox(height: 8),
              for (final q in Quality.values)
                Row(children: [
                  SizedBox(width: 40, child: QualityDots(q)),
                  Text('${q.label.toUpperCase()}  ×${s.countQ(id, q)}', style: TextStyle(fontSize: 8, color: s.countQ(id, q) > 0 ? qualityColor(q) : kDim, height: 2)),
                ]),
              const SizedBox(height: 12),
              const Text('RECEITAS QUE USAM', style: TextStyle(fontSize: 8, color: kSignal)),
              const SizedBox(height: 4),
              if (known.isEmpty && shadows.isEmpty) const Text('NENHUMA AINDA.', style: TextStyle(fontSize: 8, color: kDim)),
              for (final r in known)
                GestureDetector(
                  onTap: widget.onOpenRecipe == null ? null : () => widget.onOpenRecipe!(r),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      ItemIcon(itemId: r.outId, name: d.itemName(r.outId), size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.itemName(r.outId).toUpperCase(), style: const TextStyle(fontSize: 8, color: kText))),
                    ]),
                  ),
                ),
              for (final r in shadows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    ItemIcon(itemId: r.outId, name: '?', size: 24, silhouette: true),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_book.items[r.outId]?.tier.label ?? '?'} · ${r.hint}'.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim, height: 1.6))),
                  ]),
                ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (producer != null && widget.onOpenRecipe != null) _Btn(label: 'Ver receita', onTap: () => widget.onOpenRecipe!(producer)),
                _Btn(key: const Key('bag-pin'), label: s.crafting.pins.contains(id) ? 'Soltar do topo' : 'Fixar no topo', onTap: () => togglePin(s, id)),
                if (def?.equipable ?? false) _Btn(label: 'Equipar', onTap: () => _equip(def!)),
              ]),
              const SizedBox(height: 16),
              UiFrame(
                name: 'panel',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DESCARTAR', style: TextStyle(fontSize: 8, color: kEssence)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _Btn(label: '−', onTap: () => setState(() => _qty = (_qty - 1).clamp(1, maxQ.clamp(1, 999)))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_onlyCommon ? '${s.countQ(id, Quality.common)}' : '$_qty', key: const Key('discard-qty'), style: const TextStyle(fontSize: 16, color: kText))),
                    _Btn(label: '+', onTap: () => setState(() => _qty = (_qty + 1).clamp(1, maxQ.clamp(1, 999)))),
                    const SizedBox(width: 12),
                    _Btn(label: _onlyCommon ? '✓ só comuns' : 'só comuns', onTap: () => setState(() => _onlyCommon = !_onlyCommon)),
                  ]),
                  const SizedBox(height: 6),
                  Text('RENDE ${(_onlyCommon ? s.countQ(id, Quality.common) : _qty) ~/ _book.balance.discardPerDust} PÓ (1 A CADA ${_book.balance.discardPerDust})',
                      style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    key: const Key('discard-hold'),
                    onTapDown: (_) => _startHold(),
                    onTapUp: (_) => _endHold(),
                    onTapCancel: _endHold,
                    child: Stack(children: [
                      UiFrame(name: 'button', padding: const EdgeInsets.all(12), fallbackLine: kEssence, child: const Center(child: Text('SEGURE PARA DESCARTAR', style: TextStyle(fontSize: 8, color: kEssence)))),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(widthFactor: _hold.clamp(0.0, 1.0), heightFactor: 1, child: ColoredBox(color: kEssence.withValues(alpha: 0.3))),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          );
        },
      );

  void _equip(ItemDef def) {
    final s = widget.state;
    final slots = LoadoutSlot.values.where((x) => x.kind == def.kind).toList();
    if (slots.isEmpty) return;
    final slot = slots.firstWhere((x) => s.crafting.equipped[x] == null, orElse: () => slots.first);
    final key = Quality.values.reversed.map((q) => stackKey(def.id, q)).firstWhere((k) => (s.inventory[k] ?? 0) > 0, orElse: () => def.id);
    widget.say(equip(s, _book, slot, key) ? 'Equipado: ${slot.label}' : 'Não deu para equipar');
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: UiFrame(
          name: 'button',
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          fallbackLine: kSignal,
          child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: kSignal)),
        ),
      );
}

