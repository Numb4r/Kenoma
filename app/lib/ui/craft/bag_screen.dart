/// A Bolsa da fase 1 (docs/GDD.md, "Regras da fase 1"; proposta aprovada, tela Bolsa): o topo com a bolsa equipada, os
/// espaços usados e a dica da próxima bolsa; as abas Materiais, Condições, Uso, Equipáveis e Missão com contagem; o
/// filtro por degrau; a grade de 4 colunas. As criaturas ficam na Coleção (no Círculo).
library;

import 'package:flutter/material.dart';

import '../../crafting/bag.dart';
import '../../crafting/collectors.dart';
import '../../crafting/crafting_data.dart';
import '../../crafting/crafting_state.dart';
import '../../crafting/grimoire.dart';
import '../../crafting/loadout.dart';
import '../../crafting/quality.dart';
import '../../crafting/tutorial.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../menu/phone_shell.dart';
import 'bag_detail.dart';
import 'craft_context.dart';
import 'tutorial_card.dart';
import 'ui_art.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({required this.state, required this.data, required this.ctx, this.onOpenRecipe, super.key});

  final GameState state;
  final GameData data;
  final CraftContext ctx;

  /// "Ver receita" no detalhe: abre a Bancada nela.
  final void Function(Recipe r)? onOpenRecipe;

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  BagTab _tab = BagTab.materials;
  Tier? _tier;

  @override
  void initState() {
    super.initState();
    UiArt.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  CraftingBook get _book => widget.data.craft;

  /// Troca de aba. Abrir Condições sem nenhum recipiente faz o mentor deixar a primeira garrafa (uma vez).
  void _open(BagTab t) {
    setState(() => _tab = t);
    if (t == BagTab.conditions && giveFirstBottle(widget.state, widget.ctx.nowUtc())) _say('O mentor deixou uma Garrafa de vidro na sua bolsa');
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// De onde vem a próxima bolsa maior.
  String _nextBag(GameState s) {
    final now = widget.ctx.nowUtc();
    final cap = bagCapacity(s, _book, now);
    for (final r in widget.data.recipes.values) {
      final def = _book.items[r.outId];
      if (def?.kind != 'bag' || _book.balance.baseSlots + (def!.effects['bag_slots'] ?? 0) <= cap) continue;
      final lv = levelBlocker(s, r, _book.balance);
      if (lv != null) return 'A próxima bolsa se fabrica. A receita abre no ${lv.toLowerCase()}.';
      if (!isKnown(s, r)) return 'A próxima bolsa se fabrica: a receita vem numa página do grimório.';
      return 'A próxima bolsa se fabrica: ${def.name}, na Bancada.';
    }
    return 'Esta é a maior bolsa que existe, por enquanto.';
  }

  @override
  Widget build(BuildContext context) => PhoneScreen(
        title: 'Bolsa',
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final s = widget.state;
            final now = widget.ctx.nowUtc();
            final used = slotsUsed(s, _book), cap = bagCapacity(s, _book, now);
            final counts = tabCounts(s, _book);
            final bag = s.crafting.equipped[LoadoutSlot.bag];
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              TutorialCard(state: s, script: widget.data.mentor),
              UiFrame(
                name: 'panel',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((bag == null ? 'Bolsa de pano' : widget.data.itemName(parseStack(bag).id)).toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _CapacityBar(used: used, cap: cap)),
                    const SizedBox(width: 8),
                    Text(used >= cap ? '$used/$cap · CHEIA' : '$used/$cap', key: const Key('bag-capacity'), style: TextStyle(fontSize: 8, color: used >= cap ? kText : kSignal)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_nextBag(s), style: const TextStyle(fontSize: 8, color: kDim, height: 1.6)),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in BagTab.values)
                  TutorialMark(
                    on: t == BagTab.conditions && _tab != t && const {TutStep.belt, TutStep.fill}.contains(currentStep(s)),
                    child: _Tab(key: Key('bag-tab-${t.name}'), label: '${t.label} ${counts[t]}', on: _tab == t, onTap: () => _open(t)),
                  ),
              ]),
              const SizedBox(height: 10),
              if (_tab == BagTab.materials)
                Wrap(spacing: 6, children: [
                  for (final t in [null, Tier.raw, Tier.refined, Tier.component])
                    _Chip(label: t?.label ?? 'Todos', on: _tier == t, onTap: () => setState(() => _tier = t)),
                ]),
              const SizedBox(height: 10),
              if (_tab == BagTab.conditions) ..._conditions(s, now) else _grid(s),
            ]);
          },
        ),
      );

  Widget _grid(GameState s) {
    final stacks = tabStacks(s, _book, _tab, tier: _tab == BagTab.materials ? _tier : null);
    if (stacks.isEmpty) return const Text('NADA AQUI.', style: TextStyle(fontSize: 8, color: kDim));
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final e in stacks)
          _Cell(
            key: Key('bag-cell-${e.key}'),
            stackKey: e.key,
            qty: e.value,
            name: widget.data.itemName(parseStack(e.key).id),
            tint: _tint(parseStack(e.key).id),
            pinned: s.crafting.pins.contains(parseStack(e.key).id),
            onTap: () => showBagDetail(context, state: s, data: widget.data, ctx: widget.ctx, itemId: parseStack(e.key).id, onOpenRecipe: widget.onOpenRecipe, say: _say),
          ),
      ],
    );
  }

  Color? _tint(String id) => itemTint(_book, id);

  /// A aba Condições: as garrafas do cinto com a validade, os recipientes vazios, os guardados (iguais com a mesma validade
  /// numa linha só, ×N) e os coletores plantados. Os passos da quest do crafting ficam destacados aqui.
  List<Widget> _conditions(GameState s, int now) {
    final ctx = widget.ctx;
    final belt = s.crafting.at(VesselPlace.belt).toList();
    final planted = s.crafting.at(VesselPlace.planted).toList();
    final empties = [for (final e in s.inventory.entries) if (e.value > 0 && _book.item(e.key)?.kind == 'vessel') e];
    final here = ctx.here();
    final step = currentStep(s);
    // Os guardados: iguais (conteúdo, qualidade e validade) numa linha só.
    final groups = <String, List<Vessel>>{};
    for (final v in s.crafting.at(VesselPlace.bag)) {
      groups.putIfAbsent('${v.kind}|${v.content}|${v.quality.name}|${vesselValidity(v, _book, now)?.text}', () => []).add(v);
    }
    return [
      _title('CINTO · ${belt.length}/${beltCapacity(s, _book, now)}'),
      if (step == TutStep.fill)
        TutorialHint(key: const Key('tut-fill'), text: ruleFor('item.vessel.glass', here, _book.balance) != null ? 'Está chovendo: a garrafa do cinto enche em alguns minutos.' : 'Sem chuva agora: espere a próxima, ou plante a garrafa e volte depois.'),
      if (belt.isEmpty) _dim('NENHUMA GARRAFA NO CINTO. PONHA UMA VAZIA PARA ENCHER COM O TEMPO EM VOLTA.'),
      for (final v in belt)
        _VesselRow(key: Key('belt-${v.uid}'), v: v, data: widget.data, now: now, action: ('Tirar', () => fromBelt(s, v, _book, now) ? null : _say('Bolsa cheia'))),
      const SizedBox(height: 12),
      _title('RECIPIENTES VAZIOS'),
      if (empties.isEmpty) _dim('NENHUM. FAÇA UMA GARRAFA NA BANCADA.'),
      for (final e in empties)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            ItemIcon(itemId: e.key, name: widget.data.itemName(e.key), size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text('${widget.data.itemName(e.key).toUpperCase()} ×${e.value}', style: const TextStyle(fontSize: 8, color: kText))),
            _Small(key: Key('belt-${e.key}'), label: 'Cinto', mark: step == TutStep.belt, onTap: () => toBelt(s, e.key, _book, now) ? null : _say('Cinto cheio')),
            const SizedBox(width: 6),
            _Small(
              key: Key('plant-${e.key}'),
              label: 'Plantar',
              mark: step == TutStep.fill,
              onTap: () {
                final why = plantBlocker(s, e.key, here, ctx.speedMps?.call() ?? double.infinity, ctx.walkMaxMps, _book);
                if (why != null) return _say(why);
                plant(s, e.key, here, ctx.speedMps!(), ctx.walkMaxMps, _book);
                _say('Plantado aqui. Volte para colher.');
              },
            ),
          ]),
        ),
      if (groups.isNotEmpty) ...[
        const SizedBox(height: 12),
        _title('GUARDADOS NA BOLSA'),
        for (final g in groups.values) _VesselRow(key: Key('stored-${g.first.uid}'), v: g.first, count: g.length, data: widget.data, now: now),
      ],
      const SizedBox(height: 12),
      _title('PLANTADOS · ${planted.length}/${plantedCapacity(s, _book, now)}'),
      if (planted.isEmpty) _dim('NENHUM. PLANTE A PÉ, A 100 M OU MAIS UM DO OUTRO.'),
      for (final v in planted)
        Builder(builder: (context) {
          final st = updatePlanted(v, now, (t) => ctx.hereAt(v.lat, v.lon, t), _book);
          final d = metersBetween(here.lat, here.lon, v.lat, v.lon);
          return _VesselRow(
            key: Key('planted-${v.uid}'),
            v: v,
            data: widget.data,
            now: now,
            extra: '${d.round()} M · ${plantedLabel(st, _book.items[v.kind])}',
            action: d <= ctx.touchM ? ('Colher', () => harvest(s, v, d, ctx.touchM, _book, now) ? null : _say('Cinto e bolsa cheios')) : null,
          );
        }),
    ];
  }

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 8, color: kSignal)));
  Widget _dim(String t) => Text(t, style: const TextStyle(fontSize: 8, color: kDim, height: 1.8));
}

/// O estado de um plantado, concordando com o recipiente ("garrafa cheia", "frasco cheio").
String plantedLabel(PlantedState s, ItemDef? kind) => switch (s) {
      PlantedState.full => kind?.agree('CHEIO', 'CHEIA') ?? 'CHEIO',
      PlantedState.filling => 'ENCHENDO',
      PlantedState.waiting => 'ESPERANDO',
    };

/// A validade de um conteúdo, com o verbo dele ("derrete em", "apaga em", "estraga em"): laranja só quando falta pouco
/// (horas), a única urgência do Design System. O que não estraga diz isso.
({String text, bool soon})? vesselValidity(Vessel v, CraftingBook book, int now) {
  if (v.empty) return null;
  final def = book.items[v.content];
  final verb = (def?.perishVerb ?? (def?.meltsTo != null ? 'derrete' : 'estraga')).toUpperCase();
  final h = def?.perishH;
  if (h == null) return (text: 'NÃO ${verb == 'APAGA' ? 'SE APAGA' : verb}', soon: false);
  if (def!.meltsTo != null && (book.items[v.kind]?.keepsCold ?? false)) return (text: 'NÃO $verb', soon: false);
  final left = (v.filledUtc + (h * 3600).round() - now).clamp(0, 1 << 40); // a conta de 10 s em 10 s alcança
  return left < 86400 ? (text: '$verb EM ${(left / 3600).ceil()} H', soon: true) : (text: '$verb EM ${(left / 86400).ceil()} DIAS', soon: false);
}

class _VesselRow extends StatelessWidget {
  const _VesselRow({required this.v, required this.data, required this.now, this.count = 1, this.extra, this.action, super.key});

  final Vessel v;

  /// Quantos iguais a linha representa (guardados com o mesmo conteúdo, qualidade e validade).
  final int count;
  final GameData data;
  final int now;
  final String? extra;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final valid = vesselValidity(v, data.craft, now);
    final progress = v.empty && v.progressS > 0 ? ' · ENCHENDO' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: UiFrame(
        name: 'cell',
        padding: const EdgeInsets.all(6),
        child: Row(children: [
          ItemIcon(itemId: v.content ?? v.kind, name: data.itemName(v.content ?? v.kind), size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    (v.empty ? '${data.itemName(v.kind)} · ${data.craft.items[v.kind]?.agree('vazio', 'vazia') ?? 'vazio'}$progress' : '${data.itemName(v.content!)}${count > 1 ? ' ×$count' : ''}').toUpperCase(),
                    style: const TextStyle(fontSize: 8, color: kText),
                  ),
                ),
                if (!v.empty) QualityDots(v.quality),
              ]),
              if (extra != null) Text(extra!, style: const TextStyle(fontSize: 8, color: kDim, height: 1.6)),
              if (valid != null) Text(valid.text, style: TextStyle(fontSize: 8, color: valid.soon ? kEssence : kDim, height: 1.6)),
            ]),
          ),
          if (action != null) _Small(label: action!.$1, onTap: action!.$2),
        ]),
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.used, required this.cap});

  final int used;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final frac = cap <= 0 ? 1.0 : (used / cap).clamp(0.0, 1.0);
    return SizedBox(
      height: 6 * kUiPixel,
      child: Stack(children: [
        const Positioned.fill(child: UiFrame(name: 'bar_frame', padding: EdgeInsets.zero, child: SizedBox.expand())),
        FractionallySizedBox(
          widthFactor: frac,
          child: const UiFrame(name: 'bar_fill', padding: EdgeInsets.zero, fallbackFill: kSignal, fallbackLine: kOutline, child: SizedBox.expand()),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap, super.key});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: UiFrame(
          name: on ? 'tab_on' : 'tab_off',
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          fallbackLine: on ? kSignal : kPanelLine,
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: on ? kSignal : kDim)),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: UiFrame(
          name: 'chip',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          fallbackLine: on ? kVeil : kPanelLine,
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: on ? kVeil : kDim)),
        ),
      );
}

class _Small extends StatelessWidget {
  const _Small({required this.label, required this.onTap, this.mark = false, super.key});

  final String label;
  final VoidCallback onTap;

  /// O passo da quest do crafting: o botão ganha a marca do mentor.
  final bool mark;

  @override
  Widget build(BuildContext context) => TutorialMark(
        on: mark,
        child: GestureDetector(
          onTap: onTap,
          child: UiFrame(
            name: 'button',
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            fallbackLine: kSignal,
            child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: kSignal)),
          ),
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.stackKey, required this.qty, required this.name, required this.onTap, this.tint, this.pinned = false, super.key});

  final String stackKey;
  final int qty;
  final String name;
  final Color? tint;
  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: UiFrame(
          name: pinned ? 'cell_selected' : 'cell',
          padding: const EdgeInsets.all(4),
          fallbackLine: pinned ? kVeil : kPanelLine,
          child: Stack(children: [
            Center(child: ItemIcon(itemId: stackKey, name: name, tint: tint, size: 40)),
            Positioned(top: 0, right: 0, child: QualityDots(parseStack(stackKey).q)),
            Positioned(right: 0, bottom: 0, child: Text('$qty', style: const TextStyle(fontSize: 8, color: kText, shadows: [Shadow(color: kOutline, offset: Offset(1, 1))]))),
          ]),
        ),
      );
}
