/// A Bancada da fase 1 (docs/GDD.md, "Regras da fase 1"; proposta aprovada, telas Bancada, Receita e Experimentar): as
/// abas "Improviso · aqui" e "Bancada · casa" (do nível 5), o botão Experimentar, a faixa com as condições de agora e
/// aqui, e as receitas conhecidas em três grupos: pode fazer agora (com a qualidade que sai), esperando uma condição
/// (qual e quando) e falta material (recolhido). Destilar e fundir ficam numa tela própria, ligada daqui.
library;

import 'package:flutter/material.dart';

import '../../crafting/conditions.dart';
import '../../crafting/crafting_data.dart';
import '../../crafting/grimoire.dart';
import '../../crafting/quality.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../menu/distill_screen.dart';
import '../menu/phone_shell.dart';
import 'craft_context.dart';
import 'experiment_sheet.dart';
import 'recipe_sheet.dart';
import 'ui_art.dart';

class CraftBenchScreen extends StatefulWidget {
  const CraftBenchScreen({required this.state, required this.data, required this.ctx, this.openRecipe, super.key});

  final GameState state;
  final GameData data;
  final CraftContext ctx;

  /// Abre já nesta receita (o "Ver receita" da Bolsa).
  final Recipe? openRecipe;

  @override
  State<CraftBenchScreen> createState() => _CraftBenchScreenState();
}

class _CraftBenchScreenState extends State<CraftBenchScreen> {
  bool _bench = false;
  bool _showMissing = false;

  CraftingBook get _book => widget.data.craft;

  @override
  void initState() {
    super.initState();
    _bench = widget.openRecipe?.bench ?? false;
    UiArt.load().then((_) {
      if (!mounted) return;
      setState(() {});
      if (widget.openRecipe != null) _open(widget.openRecipe!);
    });
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _open(Recipe r) => showRecipeSheet(context, state: widget.state, data: widget.data, ctx: widget.ctx, recipe: r, say: _say);

  @override
  Widget build(BuildContext context) => PhoneScreen(
        title: 'Bancada',
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final s = widget.state;
            final h = widget.ctx.here();
            final benchOpen = s.playerLevel >= _book.balance.benchLevel;
            final g = groupRecipes(s, widget.data.recipes.values, _book, h, bench: _bench && benchOpen);
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _Tab(key: const Key('bench-tab-improv'), label: 'Improviso · aqui', on: !_bench, onTap: () => setState(() => _bench = false)),
                _Tab(
                  key: const Key('bench-tab-home'),
                  label: benchOpen ? 'Bancada · casa' : 'Bancada · nv ${_book.balance.benchLevel}',
                  on: _bench && benchOpen,
                  onTap: () => benchOpen ? setState(() => _bench = true) : _say('A bancada de casa abre no nível ${_book.balance.benchLevel}'),
                ),
                _Button(
                  key: const Key('bench-experiment'),
                  label: 'Experimentar',
                  color: kVeil,
                  onTap: () => showExperimentSheet(context, state: s, data: widget.data, ctx: widget.ctx, say: _say),
                ),
              ]),
              const SizedBox(height: 12),
              _HereStrip(here: h, book: _book, climateName: widget.ctx.climateName),
              const SizedBox(height: 16),
              _title('PODE FAZER AGORA · ${g.now.length}'),
              if (g.now.isEmpty) _dim('NADA AGORA, AQUI.'),
              for (final (r, q) in g.now) _RecipeRow(key: Key('recipe-${r.id}'), data: widget.data, recipe: r, quality: q, onTap: () => _open(r)),
              const SizedBox(height: 12),
              _title('ESPERANDO UMA CONDIÇÃO · ${g.waiting.length}'),
              for (final (r, unmet) in g.waiting)
                _RecipeRow(key: Key('recipe-${r.id}'), data: widget.data, recipe: r, note: '${unmet.first.what} · ${unmet.first.when}'.toUpperCase(), onTap: () => _open(r)),
              const SizedBox(height: 12),
              GestureDetector(
                key: const Key('bench-missing'),
                onTap: () => setState(() => _showMissing = !_showMissing),
                child: _title('${_showMissing ? '▾' : '▸'} FALTA MATERIAL · ${g.missing.length}'),
              ),
              if (_showMissing)
                for (final r in g.missing) _RecipeRow(key: Key('recipe-${r.id}'), data: widget.data, recipe: r, note: 'FALTA MATERIAL', dim: true, onTap: () => _open(r)),
              const SizedBox(height: 20),
              GestureDetector(
                key: const Key('bench-distill'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DistillScreen(state: s, data: widget.data))),
                child: _dim('▸ DESTILAR ECOS E FUNDIR: OUTRA TELA'),
              ),
            ]);
          },
        ),
      );

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 8, color: kSignal)));
  Widget _dim(String t) => Text(t, style: const TextStyle(fontSize: 8, color: kDim, height: 1.8));
}

/// A faixa "Agora, aqui": as condições que valem neste momento e neste lugar.
class _HereStrip extends StatelessWidget {
  const _HereStrip({required this.here, required this.book, this.climateName});

  final Here here;
  final CraftingBook book;
  final String Function(String id)? climateName;

  @override
  Widget build(BuildContext context) {
    final b = book.balance;
    final chips = <String>[
      here.night(b) ? 'Noite' : (here.strongSun(b) ? 'Sol forte' : 'Dia'),
      for (final c in here.climates) climateName?.call(c) ?? c,
      here.moon.label,
      here.waterM == null ? 'Sem água perto' : 'Água a ${here.waterM!.round()} m',
      if (here.biome == 'green') 'Área verde',
      if (here.biome == 'sacred') 'Lugar sagrado',
      here.season.label,
    ];
    return UiFrame(
      name: 'panel',
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AGORA, AQUI', style: TextStyle(fontSize: 8, color: kDim)),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final c in chips)
            UiFrame(name: 'chip', padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text(c.toUpperCase(), style: const TextStyle(fontSize: 8, color: kSignal))),
        ]),
      ]),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.data, required this.recipe, required this.onTap, this.quality, this.note, this.dim = false, super.key});

  final GameData data;
  final Recipe recipe;
  final Quality? quality;
  final String? note;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: UiFrame(
            name: 'cell',
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              ItemIcon(itemId: recipe.outId, name: data.itemName(recipe.outId), size: 32, tint: itemTint(data.craft, recipe.outId)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.itemName(recipe.outId).toUpperCase(), style: TextStyle(fontSize: 8, color: dim ? kDim : kText)),
                  if (note != null) Text(note!, style: const TextStyle(fontSize: 8, color: kEssence, height: 1.6)),
                ]),
              ),
              if (quality != null) QualityDots(quality!),
            ]),
          ),
        ),
      );
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

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap, this.color = kSignal, super.key});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: UiFrame(
          name: 'button',
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          fallbackLine: color,
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: color)),
        ),
      );
}
