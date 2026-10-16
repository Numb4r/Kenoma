/// A tela do menu de debug: busca no topo, seção Favoritos e as seções recolhíveis. Só desenha o [DebugRegistry];
/// o que cada item faz mora nos `debug_items_*.dart`. Sempre acessível, em toda build (CLAUDE.md).
library;

import 'package:flutter/material.dart';

import '../ui/pressable.dart';
import '../ui/tema.dart';
import 'debug_prefs.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

class DebugMenuView extends StatefulWidget {
  const DebugMenuView({required this.registry, required this.prefs, super.key});

  final DebugRegistry registry;
  final DebugPrefs prefs;

  @override
  State<DebugMenuView> createState() => _DebugMenuViewState();
}

class _DebugMenuViewState extends State<DebugMenuView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    return Scaffold(
      backgroundColor: KCores.fundo,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.prefs,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(KEspaco.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('DEBUG', style: KTexto.titulo),
                const SizedBox(height: KEspaco.s2),
                DebugField('Buscar por nome ou palavra-chave', _search, key: const Key('debug-search'), onChanged: (_) => setState(() {})),
                const SizedBox(height: KEspaco.s2),
                if (query.isEmpty) ..._sections() else ..._results(query),
                const SizedBox(height: KEspaco.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _results(String query) {
    final hits = widget.registry.search(query);
    if (hits.isEmpty) return [const DebugNote('Nenhum item com essa busca.')];
    return [for (final i in hits) _card(i, showSection: true)];
  }

  List<Widget> _sections() {
    final prefs = widget.prefs;
    final favs = [for (final id in prefs.favorites) if (widget.registry.byId(id) != null) widget.registry.byId(id)!];
    return [
      for (final s in DebugSection.values)
        _Section(
          section: s,
          open: prefs.isOpen(s),
          count: s == DebugSection.favorites ? favs.length : widget.registry.inSection(s).length,
          onToggle: () => prefs.setOpen(s, !prefs.isOpen(s)),
          empty: s == DebugSection.favorites ? 'Nenhum favorito. Toque na estrela de um item para fixar aqui.' : 'sem itens ainda',
          hasMovedToFavorites: s != DebugSection.favorites && widget.registry.inSection(s).any((i) => prefs.isFavorite(i.id)),
          children: s == DebugSection.favorites
              ? [for (final i in favs) _card(i)]
              : [for (final i in widget.registry.inSection(s)) if (!prefs.isFavorite(i.id)) _card(i)],
        ),
    ];
  }

  Widget _card(DebugItem item, {bool showSection = false}) {
    final fav = widget.prefs.isFavorite(item.id);
    return Container(
      key: Key('item-${item.id}'),
      margin: const EdgeInsets.only(bottom: KEspaco.s2),
      decoration: BoxDecoration(border: Border.all(color: KCores.contorno, width: kContornoDp), boxShadow: KSombra.pixel),
      // Material próprio: o SwitchListTile pinta o fundo e o respingo no Material mais próximo.
      child: Material(
        color: KCores.superficie1,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: KEspaco.s2),
                child: Text(showSection ? '${item.section.title} · ${item.title}'.toUpperCase() : item.title.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
              ),
            ),
            Pressable(
              onTap: () => widget.prefs.toggleFavorite(item.id),
              child: SizedBox(
                key: Key('star-${item.id}'),
                width: kToqueMinDp,
                height: kToqueMinDp,
                child: Icon(fav ? Icons.star : Icons.star_border, color: fav ? KCores.veuVioleta : KCores.textoMudo),
              ),
            ),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s2), child: Builder(builder: item.builder)),
        ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.open,
    required this.count,
    required this.onToggle,
    required this.children,
    required this.empty,
    required this.hasMovedToFavorites,
  });

  final DebugSection section;
  final bool open;
  final int count;
  final VoidCallback onToggle;
  final List<Widget> children;
  final String empty;
  final bool hasMovedToFavorites;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onToggle,
            child: Container(
              key: Key('section-${section.id}'),
              constraints: const BoxConstraints(minHeight: kToqueMinDp),
              margin: const EdgeInsets.only(bottom: KEspaco.s1),
              padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
              decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.contorno, width: kContornoDp), boxShadow: KSombra.pixel),
              child: Row(children: [
                Expanded(child: Text(section.title.toUpperCase(), style: KTexto.rotulo.copyWith(color: section == DebugSection.favorites ? KCores.veuVioleta : KCores.sinalCiano))),
                Text('$count', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
                const SizedBox(width: KEspaco.s1),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: KCores.texto),
              ]),
            ),
          ),
          if (open) ...[
            if (children.isEmpty && !hasMovedToFavorites)
              Padding(padding: const EdgeInsets.only(bottom: KEspaco.s2), child: DebugNote(empty))
            else
              ...children,
          ],
          const SizedBox(height: KEspaco.s1),
        ],
      );
}
