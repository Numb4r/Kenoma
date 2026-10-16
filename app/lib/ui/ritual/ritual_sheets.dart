/// As folhas de escolha do ritual: o material de um espaço (item e quantidade) e a criatura do Círculo.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../crafting/ritual.dart' show PlacedMaterial;
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../tema.dart';

/// O que a folha de material devolve: o material escolhido, ou `null` para esvaziar o espaço.
class RitualPick {
  const RitualPick(this.material);

  final PlacedMaterial? material;
}

class RitualMaterialSheet extends StatefulWidget {
  const RitualMaterialSheet({required this.state, required this.data, required this.current, required this.maxQty, super.key});

  final GameState state;
  final GameData data;
  final PlacedMaterial? current;
  final int maxQty;

  @override
  State<RitualMaterialSheet> createState() => RitualMaterialSheetState();
}

class RitualMaterialSheetState extends State<RitualMaterialSheet> {
  late String? _item = widget.current?.item;
  late int _qty = widget.current?.qty ?? 1;

  @override
  Widget build(BuildContext context) {
    final have = {for (final e in widget.state.inventory.entries) if (e.value > 0) e.key: e.value};
    final max = _item == null ? 1 : math.min(widget.maxQty, have[_item] ?? 1);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KEspaco.s2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MATERIAL DO ESPAÇO', style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
          const SizedBox(height: KEspaco.s1),
          if (have.isEmpty) Text('A Bolsa está vazia.', style: KTexto.corpoPequeno),
          Wrap(spacing: KEspaco.s1, runSpacing: KEspaco.s1, children: [
            for (final e in have.entries)
              GestureDetector(
                key: Key('ritual-item-${e.key}'),
                onTap: () => setState(() {
                  _item = e.key;
                  _qty = _qty.clamp(1, math.min(widget.maxQty, e.value));
                }),
                child: Container(
                  constraints: const BoxConstraints(minHeight: kToqueMinDp),
                  padding: const EdgeInsets.symmetric(horizontal: KEspaco.s1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: _item == e.key ? KCores.sinalCiano : KCores.cidade, width: kContornoDp)),
                  child: Text('${widget.data.itemName(e.key)} ×${e.value}', style: KTexto.corpoPequeno.copyWith(color: KCores.texto)),
                ),
              ),
          ]),
          const SizedBox(height: KEspaco.s2),
          Row(children: [
            RitualStep(key: const Key('ritual-minus'), label: '−', onTap: () => setState(() => _qty = math.max(1, _qty - 1))),
            SizedBox(width: 56, child: Text('$_qty', key: const Key('ritual-qty'), textAlign: TextAlign.center, style: KTexto.numero)),
            RitualStep(key: const Key('ritual-plus'), label: '+', onTap: () => setState(() => _qty = math.min(max, _qty + 1))),
          ]),
          const SizedBox(height: KEspaco.s1),
          Row(children: [
            Expanded(child: RitualStep(key: const Key('ritual-clear'), label: 'Esvaziar', wide: true, onTap: () => Navigator.of(context).pop(const RitualPick(null)))),
            const SizedBox(width: KEspaco.s1),
            Expanded(
              child: RitualStep(
                key: const Key('ritual-place'),
                label: 'Colocar',
                wide: true,
                onTap: _item == null ? () {} : () => Navigator.of(context).pop(RitualPick(PlacedMaterial(_item!, _qty))),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class RitualStep extends StatelessWidget {
  const RitualStep({required this.label, required this.onTap, this.wide = false, super.key});

  final String label;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: wide ? null : kToqueMinDp,
          height: kToqueMinDp,
          padding: wide ? const EdgeInsets.symmetric(horizontal: KEspaco.s2) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.veuVioleta, width: kContornoDp)),
          child: Text(label.toUpperCase(), style: KTexto.rotulo),
        ),
      );
}

class RitualCircleSheet extends StatelessWidget {
  const RitualCircleSheet({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  Widget build(BuildContext context) {
    final members = [for (final u in state.circle) if (state.creature(u) != null) state.creature(u)!];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KEspaco.s2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CRIATURA DO CÍRCULO', style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
          const SizedBox(height: KEspaco.s1),
          if (members.isEmpty) Text('O Círculo está vazio. Ponha criaturas nele pela coleção.', style: KTexto.corpoPequeno),
          for (final c in members)
            GestureDetector(
              key: Key('ritual-member-${c.uid}'),
              onTap: () => Navigator.of(context).pop(c.uid),
              child: Container(
                height: kToqueMinDp,
                margin: const EdgeInsets.only(bottom: KEspaco.s1),
                padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.cidade, width: kContornoDp)),
                child: Text('${data.species(c.speciesId)?.name ?? c.speciesId} · NV ${c.level}', style: KTexto.corpo),
              ),
            ),
          GestureDetector(
            key: const Key('ritual-member-none'),
            onTap: () => Navigator.of(context).pop(''),
            child: SizedBox(height: kToqueMinDp, child: Align(alignment: Alignment.centerLeft, child: Text('ESVAZIAR', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)))),
          ),
        ]),
      ),
    );
  }
}
