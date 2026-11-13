/// O Bestiário (docs/GDD.md, "Bestiário"): as famílias com a linha de fusão em cada cartão, a grade por camada com
/// filtro e a busca. Tocar numa forma abre o detalhe (`bestiary/species_detail.dart`). Só desenha: o que aparece vem de
/// `player/bestiary_view.dart`.
library;

import 'package:flutter/material.dart' hide FormState;

import '../../capture/eco_type.dart';
import '../../data/game_data.dart';
import '../../player/bestiary_view.dart';
import '../../player/game_state.dart';
import '../../player/research.dart';
import '../colors.dart' show typeColor;
import '../sprites/sprite_image.dart';
import '../tema.dart';
import '../type_label.dart';
import 'bestiary/bestiary_widgets.dart';
import 'bestiary/species_detail.dart';
import 'phone_shell.dart';

/// Os sprites de todas as formas do Bestiário, pela chave do sprite (`hum.eco`, `hum.mote`).
Future<Map<String, EcoSprite>> loadBestiarySprites(GameData data) async => {for (final f in bestiaryForms(data)) f.spriteKey: await EcoSprite.load(f.spriteKey)};

class BestiaryScreen extends StatefulWidget {
  const BestiaryScreen({required this.state, required this.data, this.sprites, super.key});

  final GameState state;
  final GameData data;

  /// Os sprites já carregados ([loadBestiarySprites]); `null`: a tela carrega ao abrir.
  final Map<String, EcoSprite>? sprites;

  @override
  State<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends State<BestiaryScreen> {
  late Map<String, EcoSprite> _sprites = widget.sprites ?? {};
  var _grid = false;
  var _filter = const BestiaryFilter();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sprites != null) return;
    loadBestiarySprites(widget.data).then((m) {
      if (mounted) setState(() => _sprites = m);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _typeLabel(String type) => typeLabel(EcoType.parse(type));

  bool _matches(BestiaryForm f, BestiaryFilter filter) => filter.matches(f, widget.data, widget.state.bestiary, _typeLabel);

  void _open(BestiaryForm form) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SpeciesDetailScreen(state: widget.state, data: widget.data, form: form, sprites: _sprites),
      ));

  Future<void> _openFilter() async {
    final forms = bestiaryForms(widget.data);
    final picked = await showModalBottomSheet<BestiaryFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FilterSheet(initial: _filter, countOf: (f) => forms.where((x) => _matches(x, f)).length),
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final data = widget.data, b = widget.state.bestiary;
        return PhoneScreen(
          title: 'Bestiário',
          actions: [
            Text('PESQUISA\n${bestiaryPercent(data, b)}%', key: const Key('bestiary-percent'), textAlign: TextAlign.right, style: KTexto.rotulo.copyWith(fontSize: 10, height: 1.2, color: KCores.sinalCiano)),
          ],
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, 8),
              child: Container(
                decoration: BoxDecoration(color: KCores.superficie1, border: Border.all(color: KCores.contorno, width: kContornoDp)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  key: const Key('bestiary-search'),
                  controller: _search,
                  style: KTexto.corpoPequeno.copyWith(color: KCores.texto),
                  cursorColor: KCores.veuVioleta,
                  decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12), hintText: 'Buscar espécie, tipo, lugar', hintStyle: KTexto.corpoPequeno),
                  onChanged: (q) => setState(() => _filter = _filter.copyWith(query: q)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, 8),
              child: KSegment(labels: const ['Famílias', 'Grade'], index: _grid ? 1 : 0, onTap: (i) => setState(() => _grid = i == 1)),
            ),
            if (_grid)
              Padding(
                padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, 8),
                child: KButton(key: const Key('bestiary-filter'), label: _filter.copyWith(query: '').isEmpty ? 'Filtrar' : 'Filtrar · ligado', primary: false, onTap: _openFilter),
              )
            else
              SizedBox(
                height: 44,
                child: ListView(
                  key: const Key('bestiary-chips'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, 8),
                  children: [
                    KChip(key: const Key('chip-all'), label: 'Todos', on: _filter.types.isEmpty, onTap: () => setState(() => _filter = _filter.copyWith(types: const {}))),
                    for (final t in EcoType.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: KChip(key: Key('chip-${t.name}'), label: typeLabel(t), dot: typeColor(t), on: _filter.types.contains(t.name), onTap: () => setState(() => _filter = _filter.copyWith(types: {t.name}))),
                      ),
                  ],
                ),
              ),
            Expanded(child: _grid ? _gridView(data) : _familiesView(data)),
          ]),
        );
      },
    );
  }

  Widget _empty() => Padding(padding: const EdgeInsets.all(KEspaco.s4), child: Text('Nada com esse filtro.', style: KTexto.corpoPequeno, textAlign: TextAlign.center));

  Widget _familiesView(GameData data) {
    final b = widget.state.bestiary;
    final cards = <Widget>[];
    var n = 1;
    for (final f in data.families) {
      final forms = familyForms(f, data, n);
      n += forms.length;
      if (!forms.any((x) => _matches(x, _filter))) continue;
      cards.add(FamilyCard(
        family: f,
        forms: forms,
        states: [for (final x in forms) formState(x.id, b)],
        percent: familyPercent(f, data, b),
        sprites: _sprites,
        known: familyKnown(f, data, b),
        pinned: widget.state.pins,
        onTap: _open,
      ));
    }
    return ListView(key: const Key('bestiary-families'), padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s4), children: cards.isEmpty ? [_empty()] : cards);
  }

  Widget _gridView(GameData data) {
    final b = widget.state.bestiary;
    final forms = [for (final f in bestiaryForms(data)) if (_matches(f, _filter)) f];
    final sections = <Widget>[];
    for (final (layer, title) in const [(FormLayer.eco, 'Ecos'), (FormLayer.spark, 'Fagulhas'), (FormLayer.spirit, 'Espíritos'), (FormLayer.ritual, 'Espíritos de ritual')]) {
      final list = [for (final f in forms) if (f.layer == layer) f];
      if (list.isEmpty) continue;
      sections
        ..add(KSection('$title · ${list.length}'))
        ..add(GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 0.92,
          children: [
            for (final f in list) SpeciesCell(form: f, state: formState(f.id, b), sprite: _sprites[f.spriteKey], pinned: widget.state.isPinned(f.id), onTap: () => _open(f)),
          ],
        ));
    }
    return ListView(key: const Key('bestiary-grid'), padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s4), children: sections.isEmpty ? [_empty()] : sections);
  }
}
