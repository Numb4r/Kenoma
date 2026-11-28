/// A tela do menu de debug (0.26.6): uma vista do [DebugRegistry], como o `cmd`. No topo, fixos: a faixa "fora do real"
/// (um chip por override; tocar desfaz só ele; "Voltar tudo ao real" desfaz o que não mexe no save), a busca, os favoritos
/// numa linha de atalhos e as abas. Embaixo rolam os cartões da aba (`debug_entry_card.dart`). Sempre acessível, em toda
/// build de teste (CLAUDE.md); sai da build dos amigos antes de distribuir (`docs/distribuicao.md`).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/pressable.dart';
import '../ui/tema.dart';
import 'debug_entry_card.dart';
import 'debug_prefs.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

class DebugMenuView extends StatefulWidget {
  const DebugMenuView({required this.registry, required this.prefs, this.listenable, this.onTop, super.key});

  final DebugRegistry registry;
  final DebugPrefs prefs;

  /// O que avisa quando o estado das entradas muda (`debugListenables`).
  final Listenable? listenable;

  /// 0.24.4: o Voltar no topo do menu (sem busca). O menu é a primeira rota: sem isto o Voltar fechava o app. O menu do
  /// jogo passa "abrir o mapa".
  final VoidCallback? onTop;

  @override
  State<DebugMenuView> createState() => _DebugMenuViewState();
}

class _DebugMenuViewState extends State<DebugMenuView> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _cards = <String, GlobalKey>{};
  String? _flash;
  Timer? _flashTimer;

  DebugRegistry get reg => widget.registry;

  @override
  void initState() {
    super.initState();
    reg.screen = () => mounted ? context : null;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Roda pela tela: o destrutivo pergunta antes (com a palavra, se houver); o aviso sai num snackbar.
  Future<void> _run(DebugEntry e, String raw) async {
    final say = debugSayer(context);
    if (e.destructive && !e.selfConfirm) {
      final ok = await debugConfirm(context,
          title: '${e.name}?', body: e.info ?? 'Não tem volta.', confirm: e.name, word: e.confirmWord == 'sim' ? null : e.confirmWord);
      if (!ok || !mounted) return;
    }
    try {
      final msg = await reg.execute(e, e.destructive ? '$raw confirma=${e.confirmWord}' : raw, context: context);
      if (e.kind == DebugKind.action || e.kind == DebugKind.coord) say(msg);
    } on DebugError catch (err) {
      say(err.message);
    } catch (err) {
      say('Erro: $err');
    }
  }

  Future<void> _undo(DebugEntry e) async {
    final say = debugSayer(context);
    try {
      await reg.undo(e);
    } catch (err) {
      say('Erro: $err');
    }
  }

  Future<void> _undoAll() async {
    final say = debugSayer(context);
    final kept = await reg.undoAll();
    say(kept.isEmpty ? 'Tudo no real' : 'Tudo no real, menos o que mexe no save: ${kept.join(', ')}');
  }

  /// Favorito tocado: vai para a aba dele e rola até o cartão, que acende por 600 ms.
  void _goTo(DebugEntry e) {
    _search.clear();
    widget.prefs.setTab(e.tab);
    setState(() => _flash = e.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _cards[e.id]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 200));
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Voltar sobe um nível: com busca, limpa a busca; no topo, [onTop] (o mapa). Nunca fecha o app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_search.text.isNotEmpty) {
          _search.clear();
          setState(() {});
        } else {
          widget.onTop?.call();
        }
      },
      child: Scaffold(
        backgroundColor: KCores.fundo,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([widget.prefs, reg.ran, ?widget.listenable]),
            builder: (context, _) {
              final query = _search.text.trim();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(KEspaco.s2, KEspaco.s2, KEspaco.s2, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('DEBUG', style: KTexto.titulo),
                    const SizedBox(height: KEspaco.s1),
                    _offReal(),
                    const SizedBox(height: KEspaco.s1),
                    DebugField('Buscar por nome, id ou palavra-chave', _search, key: const Key('debug-search'), onChanged: (_) => setState(() {})),
                    if (query.isEmpty) ...[const SizedBox(height: KEspaco.s1), _favorites(), _tabs()],
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('debug-cards'),
                    controller: _scroll,
                    padding: const EdgeInsets.all(KEspaco.s2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: query.isEmpty ? _tabCards() : _results(query)),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _card(DebugEntry e, {bool search = false}) => KeyedSubtree(
        key: _cards.putIfAbsent(e.id, GlobalKey.new),
        child: EntryCard(
          entry: e,
          onRun: _run,
          favorite: widget.prefs.isFavorite(e.id),
          onStar: () => widget.prefs.toggleFavorite(e.id),
          prefix: search ? e.tab.title : null,
          flash: _flash == e.id,
        ),
      );

  List<Widget> _tabCards() => [for (final e in reg.inTab(widget.prefs.tab)) _card(e)];

  List<Widget> _results(String query) {
    final hits = reg.search(query);
    if (hits.isEmpty) return [const DebugNote('Nenhuma entrada com essa busca.')];
    return [for (final e in hits) _card(e, search: true)];
  }

  Widget _offReal() {
    final off = reg.offReal();
    if (off.isEmpty) {
      return SizedBox(height: 24, child: Align(alignment: Alignment.centerLeft, child: Text('TUDO REAL', key: const Key('debug-all-real-state'), style: KTexto.rotulo.copyWith(color: KCores.textoMudo))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('FORA DO REAL · ${off.length}', style: KTexto.rotulo.copyWith(color: KCores.sinalCiano))),
        DebugButton(key: const Key('debug-all-real'), label: 'Voltar tudo ao real', onTap: _undoAll),
      ]),
      Wrap(spacing: KEspaco.s1, children: [
        for (final (e, label) in off) DebugOverrideChip(label, key: Key('real-${e.id}'), onTap: () => _undo(e)),
      ]),
    ]);
  }

  Widget _favorites() {
    final favs = [for (final id in widget.prefs.favorites) ?reg.byName(id)];
    return SizedBox(
      height: kToqueMinDp,
      child: Row(children: [
        const Icon(Icons.star, size: 18, color: KCores.textoMudo),
        const SizedBox(width: KEspaco.s1),
        Expanded(
          child: favs.isEmpty
              ? const DebugNote('Sem favoritos: toque na estrela de um item.')
              : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                  for (final e in favs)
                    Padding(
                      padding: const EdgeInsets.only(right: KEspaco.s1),
                      child: Pressable(
                        key: Key('fav-${e.id}'),
                        onTap: () => _goTo(e),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: kToqueMinDp),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: KEspaco.s1),
                          decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.contorno, width: kContornoDp)),
                          child: Stack(clipBehavior: Clip.none, children: [
                            Text(e.name.toUpperCase(), style: KTexto.rotulo),
                            if (e.offReal?.call() != null) const Positioned(right: -3, top: -6, child: DebugDot()),
                          ]),
                        ),
                      ),
                    ),
                ])),
        ),
      ]),
    );
  }

  Widget _tabs() {
    final now = widget.prefs.tab;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KCores.contorno, width: kContornoDp))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final t in DebugTab.values)
          Expanded(
            child: DebugTabButton(
              key: Key('tab-${t.id}'),
              icon: kDebugTabIcons[t]!,
              label: t.title,
              active: t == now,
              dot: reg.inTab(t).any((e) => e.offReal?.call() != null),
              onTap: () {
                widget.prefs.setTab(t);
                if (_scroll.hasClients) _scroll.jumpTo(0);
              },
            ),
          ),
      ]),
    );
  }
}

/// O ícone de cada aba (spec do criativo): o chip em Sistema, para não confundir com os Ajustes.
const kDebugTabIcons = {
  DebugTab.world: Icons.public_sharp,
  DebugTab.position: Icons.place_sharp,
  DebugTab.creatures: Icons.pets_sharp,
  DebugTab.player: Icons.person_sharp,
  DebugTab.visual: Icons.visibility_sharp,
  DebugTab.system: Icons.memory_sharp,
};
