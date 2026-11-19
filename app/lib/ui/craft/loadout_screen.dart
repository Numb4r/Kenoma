/// O Loadout (docs/GDD.md, "Regras da fase 1"; proposta aprovada, tela Loadout), com os componentes atuais do Design System:
/// o visual novo entra junto com o redesenho do HUD. Abas Equipamento e Aparência (a cara de um item com o efeito de outro),
/// "mostrar no personagem" em cada espaço e, embaixo, a soma do que o equipamento dá.
library;

import 'package:flutter/material.dart';

import '../../crafting/crafting_data.dart';
import '../../crafting/crafting_state.dart';
import '../../crafting/loadout.dart';
import '../../crafting/quality.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../menu/screen_frame.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import '../kit.dart' show KitSwitch;

/// Um efeito em palavras: `bag_slots` 20 → "+20 espaços na bolsa".
String effectText(String key, double v) {
  final n = v.round();
  String plural(String one, String many) => n == 1 ? one : many;
  return switch (key) {
      'bag_slots' => '+$n ${plural('espaço', 'espaços')} na bolsa',
      'belt_slots' => '+$n ${plural('garrafa', 'garrafas')} no cinto',
      'planted_slots' => '+$n ${plural('coletor plantado', 'coletores plantados')}',
      'seal_tolerance' => '+${(v * 100).round()}% de tolerância no selo',
      'tonic_time' => '+${(v * 100).round()}% de tempo no tônico',
      'fill_speed' => '+${(v * 100).round()}% de velocidade ao encher',
      _ => '$key ${v.toStringAsFixed(2)}',
    };
}

class LoadoutScreen extends StatefulWidget {
  const LoadoutScreen({required this.state, required this.data, required this.nowUtc, super.key});

  final GameState state;
  final GameData data;
  final int Function() nowUtc;

  @override
  State<LoadoutScreen> createState() => _LoadoutScreenState();
}

class _LoadoutScreenState extends State<LoadoutScreen> {
  bool _looks = false;
  LoadoutSlot? _choosing;

  CraftingBook get _book => widget.data.craft;

  /// Os itens da bolsa que cabem em [slot] (pilhas exatas, com a qualidade).
  List<String> _fits(LoadoutSlot slot) => [
        for (final e in widget.state.inventory.entries)
          if (e.value > 0 && _book.item(e.key)?.kind == slot.kind) e.key,
      ]..sort();

  /// Para a aparência: tudo do mesmo tipo que o jogador tem ou já equipou.
  List<String> _looksFor(LoadoutSlot slot) => {
        for (final k in _fits(slot)) parseStack(k).id,
        for (final k in widget.state.crafting.equipped.values)
          if (_book.item(k)?.kind == slot.kind) parseStack(k).id,
      }.toList()
        ..sort();

  String _name(String? key) => key == null ? 'vazio' : widget.data.itemName(parseStack(key).id);

  @override
  Widget build(BuildContext context) => PopScope(
        // 0.24.4: Voltar com a lista de troca aberta só fecha a lista (um nível), depois sai do app.
        canPop: _choosing == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _choosing = null);
        },
        child: _body(context),
      );

  Widget _body(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final s = widget.state;
          final eff = loadoutEffects(s, _book, widget.nowUtc());
          return ScreenFrame(
            title: 'Loadout',
            subtitle: 'Equipamento e aparência são camadas separadas',
            children: [
              Wrap(spacing: 8, children: [
                PixelButton(key: const Key('loadout-tab-gear'), label: 'Equipamento', color: _looks ? kDim : kSignal, onTap: () => setState(() => _looks = false)),
                PixelButton(key: const Key('loadout-tab-looks'), label: 'Aparência', color: _looks ? kVeil : kDim, onTap: () => setState(() => _looks = true)),
              ]),
              const SizedBox(height: 16),
              for (final slot in LoadoutSlot.values) _slot(s, slot),
              const SectionTitle('O equipamento dá'),
              if (eff.values.every((v) => v == 0)) const Text('NADA AINDA. A BOLSA DE 40 E O CINTO DE 3 SÃO A BASE.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
              for (final e in eff.entries)
                if (e.value != 0) Text(effectText(e.key, e.value).toUpperCase(), key: Key('loadout-effect-${e.key}'), style: const TextStyle(fontSize: 8, color: kSignal, height: 1.8)),
            ],
          );
        },
      );

  Widget _slot(GameState s, LoadoutSlot slot) {
    final c = s.crafting;
    final equipped = c.equipped[slot];
    final def = equipped == null ? null : _book.item(equipped);
    final choices = _looks ? _looksFor(slot) : _fits(slot);
    return Container(
      key: Key('loadout-slot-${slot.name}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: equipped == null ? cellBox() : cardBox(line: kSignal),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(slot.label.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim))),
          const Text('NO PERSONAGEM', style: TextStyle(fontSize: 8, color: kDim)),
          KitSwitch(
            key: Key('loadout-show-${slot.name}'),
            value: !c.hidden.contains(slot),
            onChanged: (v) {
              v ? c.hidden.remove(slot) : c.hidden.add(slot);
              s.changed();
            },
          ),
        ]),
        Text(
          _looks ? 'CARA: ${_name(c.looks[slot] ?? equipped).toUpperCase()}' : _name(equipped).toUpperCase(),
          style: const TextStyle(fontSize: 12, color: kText, height: 1.6),
        ),
        if (!_looks && def != null)
          for (final e in def.effects.entries) Text(effectText(e.key, e.value).toUpperCase(), style: const TextStyle(fontSize: 8, color: kSignal, height: 1.6)),
        if (!_looks && def?.season != null) Text('MAIS FORTE ${def!.season!.inLabel.toUpperCase()}', style: const TextStyle(fontSize: 8, color: kVeil, height: 1.6)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (choices.isNotEmpty) PixelButton(label: _choosing == slot ? 'Fechar' : 'Trocar', color: kSignal, onTap: () => setState(() => _choosing = _choosing == slot ? null : slot)),
          if (!_looks && equipped != null) PixelButton(label: 'Tirar', color: kDim, onTap: () => unequip(s, slot)),
          if (_looks && c.looks[slot] != null) PixelButton(label: 'Igual ao equipado', color: kDim, onTap: () => setState(() => c.looks.remove(slot))),
        ]),
        if (_choosing == slot)
          for (final k in choices)
            GestureDetector(
              key: Key('loadout-pick-$k'),
              onTap: () {
                if (_looks) {
                  c.looks[slot] = k;
                  s.changed();
                } else {
                  equip(s, _book, slot, k);
                }
                setState(() => _choosing = null);
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('▸ ${_name(k).toUpperCase()}${parseStack(k).q == Quality.common ? '' : ' · ${parseStack(k).q.phrase.toUpperCase()}'}', style: const TextStyle(fontSize: 8, color: kText, height: 1.6)),
              ),
            ),
      ]),
    );
  }
}
