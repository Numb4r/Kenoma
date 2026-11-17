/// Uma receita aberta (proposta aprovada, tela Receita): ingredientes e resultado numa linha, a condição pedida e se está
/// cumprida, a escolha de qual pilha de cada ingrediente usar (por qualidade), a caixa "Vai sair" com a qualidade e o que
/// faltaria para subir, e a quantidade com o botão Fazer.
library;

import 'package:flutter/material.dart';

import '../../crafting/collectors.dart';
import '../../crafting/conditions.dart';
import '../../crafting/crafting_data.dart';
import '../../crafting/grimoire.dart';
import '../../crafting/quality.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../tema.dart';
import 'craft_context.dart';
import 'ui_art.dart';

Future<void> showRecipeSheet(BuildContext context, {required GameState state, required GameData data, required CraftContext ctx, required Recipe recipe, required void Function(String) say}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UiFrame(
        name: 'sheet',
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _RecipeSheet(state: state, data: data, ctx: ctx, recipe: recipe, say: say),
      ),
    );

class _RecipeSheet extends StatefulWidget {
  const _RecipeSheet({required this.state, required this.data, required this.ctx, required this.recipe, required this.say});

  final GameState state;
  final GameData data;
  final CraftContext ctx;
  final Recipe recipe;
  final void Function(String) say;

  @override
  State<_RecipeSheet> createState() => _RecipeSheetState();
}

class _RecipeSheetState extends State<_RecipeSheet> {
  final _pick = <String, Quality>{};
  int _times = 1;

  /// O caminho escolhido entre os que fazem o mesmo item (os `.alt`).
  late Recipe _r = widget.recipe;

  CraftingBook get _book => widget.data.craft;

  /// As qualidades que há de [id] (pilhas ou recipientes cheios).
  List<(Quality, int)> _have(String id) => [
        for (final q in Quality.values)
          if ((isCondition(_book, id) ? carriedWith(widget.state, id).where((v) => v.quality == q).length : widget.state.countQ(id, q)) case final n when n > 0) (q, n),
      ];

  int _maxTimes() {
    var n = 0;
    while (n < 99 && planCraft(widget.state, _r, _book, pick: _pick, times: n + 1) != null) {
      n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final s = widget.state, d = widget.data, r = _r;
          final paths = alternativesOf(s, d.recipes.values, widget.recipe);
          final h = widget.ctx.here();
          final unmet = unmetNeeds(r.needs, h, _book.balance, climateName: widget.ctx.climateName);
          final plan = planCraft(s, r, _book, pick: _pick, times: _times);
          final blocker = craftBlocker(s, r, _book, h, pick: _pick, times: _times);
          final maxT = _maxTimes();
          return SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(d.itemName(r.outId).toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
              Text((r.bench ? 'Bancada de casa' : 'Improviso, em qualquer lugar').toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
              if (paths.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  for (final (i, p) in paths.indexed)
                    _Choice(
                      label: 'Caminho ${i + 1}',
                      on: p.id == r.id,
                      onTap: () => setState(() {
                        _r = p;
                        _pick.clear();
                        _times = 1;
                      }),
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final e in r.inputs.entries) _Ingredient(data: d, id: e.key, need: e.value * _times, have: isCondition(_book, e.key) ? carriedWith(s, e.key).length : s.count(e.key)),
                for (final g in r.anyOf.entries)
                  _Ingredient(
                    data: d,
                    id: 'item.${g.key == 'trait' ? 'essence.trait.green' : g.key}',
                    label: switch (g.key) { 'dust' => 'Pó (qualquer)', 'trait' => 'Traço (qualquer)', _ => 'Essência (qualquer)' },
                    need: g.value * _times,
                    have: anyGroupIds(g.key, _book).fold<int>(0, (n, id) => n + s.count(id)),
                  ),
                const Text('→', style: TextStyle(fontSize: 16, color: kDim)),
                _Ingredient(data: d, id: r.outId, need: r.outQty * _times, result: true),
              ]),
              const SizedBox(height: 12),
              if (r.needs.none) const Text('SEM CONDIÇÃO: VALE A QUALQUER HORA.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
              if (!r.needs.none && unmet.isEmpty) const Text('CONDIÇÃO CUMPRIDA AGORA, AQUI.', key: Key('recipe-condition-ok'), style: TextStyle(fontSize: 8, color: kSignal, height: 1.8)),
              for (final u in unmet) Text('PEDE ${u.what} · ${u.when}'.toUpperCase(), style: const TextStyle(fontSize: 8, color: KCores.textoMudo, height: 1.8)),
              const SizedBox(height: 12),
              for (final id in r.inputs.keys)
                if (_have(id).length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      SizedBox(width: 96, child: Text(d.itemName(id).toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim))),
                      _Choice(label: 'auto', on: _pick[id] == null, onTap: () => setState(() => _pick.remove(id))),
                      for (final (q, n) in _have(id)) _Choice(dots: q, label: '×$n', on: _pick[id] == q, onTap: () => setState(() => _pick[id] = q)),
                    ]),
                  ),
              UiFrame(
                name: 'panel',
                child: Row(children: [
                  const Text('VAI SAIR ', style: TextStyle(fontSize: 8, color: kDim)),
                  if (plan != null) ...[QualityDots(plan.quality), const SizedBox(width: 6)],
                  Expanded(
                    child: Text(
                      plan == null
                          ? 'FALTA MATERIAL'
                          : plan.quality == Quality.perfect
                              ? 'QUALIDADE PERFEITA'
                              : '${plan.quality.phrase} · para subir, use ${_join(plan.limiting.map((id) => id.startsWith('any:') ? 'a Essência' : d.itemName(id)).toList())} de ${plan.quality.up().phrase}'.toUpperCase(),
                      key: const Key('recipe-outcome'),
                      style: TextStyle(fontSize: 8, color: plan == null ? KCores.textoMudo : qualityColor(plan.quality), height: 1.6),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _Choice(label: '−', on: false, onTap: () => setState(() => _times = (_times - 1).clamp(1, maxT.clamp(1, 99)))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_times', style: const TextStyle(fontSize: 16, color: kText))),
                _Choice(label: '+', on: false, onTap: () => setState(() => _times = (_times + 1).clamp(1, maxT.clamp(1, 99)))),
                const Spacer(),
                GestureDetector(
                  key: const Key('recipe-make'),
                  onTap: () {
                    if (blocker != null) return widget.say(blocker);
                    final q = craftAt(s, r, _book, h, pick: _pick, times: _times);
                    if (q != null) widget.say('+${r.outQty * _times} ${d.itemName(r.outId)}, ${q.phrase}');
                    setState(() => _times = 1);
                  },
                  child: UiFrame(
                    name: blocker == null ? 'button' : 'button_disabled',
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    fallbackLine: blocker == null ? kSignal : kPanelLine,
                    child: Text('FAZER', style: TextStyle(fontSize: 16, color: blocker == null ? kSignal : kDim)),
                  ),
                ),
              ]),
              if (blocker != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(blocker.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim, height: 1.6))),
            ]),
          );
        },
      );
}

/// "a, b e c".
String _join(List<String> xs) => xs.length < 2 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} e ${xs.last}';

class _Ingredient extends StatelessWidget {
  const _Ingredient({required this.data, required this.id, required this.need, this.have, this.label, this.result = false});

  final GameData data;
  final String id;
  final int need;
  final int? have;
  final String? label;
  final bool result;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ItemIcon(itemId: id, name: label ?? data.itemName(id), size: 40, tint: itemTint(data.craft, id)),
        Text(result ? '×$need' : '${have ?? 0}/$need', style: TextStyle(fontSize: 8, color: result ? kText : ((have ?? 0) >= need ? kSignal : KCores.textoMudo))),
        // 0.24.1: o nome quebra em até três linhas ("Pó de Essência / de Sombra"), sem cortar.
        SizedBox(width: 96, child: Text((label ?? data.itemName(id)).toUpperCase(), maxLines: 3, softWrap: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: kDim, height: 1.4))),
      ]);
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap, this.dots});

  final String label;
  final bool on;
  final Quality? dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: UiFrame(
          name: on ? 'button_pressed' : 'button',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          fallbackLine: on ? kVeil : kPanelLine,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dots != null) ...[QualityDots(dots!), const SizedBox(width: 4)],
            Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: on ? kVeil : kText)),
          ]),
        ),
      );
}
