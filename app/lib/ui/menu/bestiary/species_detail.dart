/// O detalhe de uma forma do Bestiário: a arte com as bolinhas de variante e as setas para a forma anterior e a seguinte,
/// e quatro abas (Pesquisa, Sobre, Atributos, Sintonia). O que cada nível de pesquisa libera vem de `player/research.dart`.
library;

import 'package:flutter/material.dart' hide FormState;

import '../../../capture/eco_type.dart';
import '../../../core/species_ids.dart' show familyOfId;
import '../../../data/game_data.dart';
import '../../../player/bestiary.dart';
import '../../../player/bestiary_view.dart';
import '../../../player/attributes.dart' show abilityText;
import '../../../player/circle.dart' show abilityLabel;
import '../../../player/game_state.dart';
import '../../../player/research.dart';
import '../../colors.dart' show typeColor;
import '../../ritual/ritual_research_panel.dart';
import '../../sprites/sprite_image.dart';
import '../../tema.dart';
import '../../type_label.dart';
import '../bench_screen.dart';
import '../phone_shell.dart';
import '../screen_frame.dart' show SpeciesImage;
import 'bestiary_widgets.dart';

const Map<String, String> _unlockLabels = {'lore1': 'Lore I', 'where': 'Onde aparece', 'attributes': 'Atributos', 'tolerance': '+Tolerância', 'lore3': 'Lore III'};

class SpeciesDetailScreen extends StatefulWidget {
  const SpeciesDetailScreen({required this.state, required this.data, required this.form, required this.sprites, super.key});

  final GameState state;
  final GameData data;
  final BestiaryForm form;
  final Map<String, EcoSprite> sprites;

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  late BestiaryForm _form = widget.form;
  var _tab = 0;

  /// A variante cuja arte está na tela (`''` é a comum).
  var _variant = '';

  List<BestiaryForm> get _siblings {
    final all = bestiaryForms(widget.data);
    return [for (final f in all) if (f.family.id == _form.family.id) f];
  }

  void _go(BestiaryForm f) => setState(() {
        _form = f;
        _variant = '';
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final data = widget.data, b = widget.state.bestiary, form = _form;
        final status = formState(form.id, b);
        final known = status != FormStatus.unknown;
        final famKnown = familyKnown(form.family, data, b);
        final type = EcoType.parse(form.family.type);
        final sibs = _siblings, i = sibs.indexWhere((f) => f.id == form.id);
        final prev = i > 0 ? sibs[i - 1] : null, next = i >= 0 && i + 1 < sibs.length ? sibs[i + 1] : null;
        final lore = data.lore[form.id];
        final unlocks = lore == null ? <String>{} : researchUnlocks(lore.research, form.id, b);
        String nameOf(BestiaryForm f) => formState(f.id, b) == FormStatus.unknown ? '???' : f.name;
        final species = form.isSpark ? null : data.species(form.id);
        final owned = species == null ? 0 : widget.state.collection.where((c) => c.speciesId == form.id && !c.debug).length;
        return PhoneScreen(
          title: famKnown ? 'Família ${form.family.name}' : 'Família ???',
          actions: [Text('${i + 1} / ${sibs.length}', style: KTexto.rotulo.copyWith(color: KCores.sinalCiano))],
          child: Column(children: [
            // A arte: número, bolinhas de variante e as setas.
            Container(
              margin: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
              height: 150,
              decoration: BoxDecoration(
                gradient: const RadialGradient(center: Alignment(0, 0.2), radius: 0.9, colors: [Color(0xFF2E2550), KCores.superficie1]),
                border: Border.all(color: KCores.contorno, width: kContornoDp),
              ),
              child: Stack(children: [
                Positioned(left: 8, top: 6, child: Text('Nº ${form.number.toString().padLeft(3, '0')}', style: KTexto.rotulo.copyWith(fontSize: 9, color: KCores.textoMudo))),
                Center(
                  child: SpeciesImage(
                    key: Key('hero-${form.id}-$_variant'),
                    sprite: widget.sprites[form.spriteKey],
                    silhouette: !known,
                    size: 108,
                    tint: _variant.isEmpty ? null : data.variants[_variant]?.tint,
                  ),
                ),
                if (!form.isSpark)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Row(children: [
                      for (final d in variantDots(form.id, data, b))
                        GestureDetector(
                          key: Key('dot-${d.key.isEmpty ? 'base' : d.key}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: d.state == FormStatus.unknown ? null : () => setState(() => _variant = d.key),
                          child: Padding(padding: const EdgeInsets.all(3), child: _dot(d, type)),
                        ),
                    ]),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _arrow(prev == null ? null : '< ${nameOf(prev)}', const Key('form-prev'), prev == null ? null : () => _go(prev)),
                    _arrow(next == null ? null : '${nameOf(next)} >', const Key('form-next'), next == null ? null : () => _go(next)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KEspaco.s2, 8, KEspaco.s2, 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Flexible(child: Text(known ? form.name : '???', key: const Key('detail-name'), style: KTexto.titulo, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(_layerLine(form), style: KTexto.corpoPequeno.copyWith(fontSize: 13)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (known) KTag.type(type) else const KTag('???'),
                  if (known && unlocks.contains('where') || known && form.isSpark) KTag(form.family.where['biome']!),
                  if (status == FormStatus.captured)
                    KTag(form.isSpark ? 'Coletada ×${b[form.id]?.captures ?? 1}' : 'Capturada ×${b[form.id]?.captures ?? 1}', color: KCores.sinalCiano)
                  else if (status == FormStatus.seen)
                    const KTag('Vista', color: KCores.veuClaro),
                  if (_variant.isNotEmpty) KTag(data.variants[_variant]!.name, dot: Color(data.variants[_variant]!.tint)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
              child: KTabs(labels: const ['Pesquisa', 'Sobre', 'Atrib.', 'Sintonia'], index: _tab, onTap: (t) => setState(() => _tab = t)),
            ),
            Expanded(
              child: ListView(
                key: Key('pane-$_tab'),
                padding: const EdgeInsets.fromLTRB(KEspaco.s2, 10, KEspaco.s2, KEspaco.s2),
                children: switch (_tab) {
                  0 => _research(form, lore, unlocks, b, known),
                  1 => _about(form, lore, unlocks, known, famKnown),
                  2 => _attributes(form, unlocks, b, status),
                  _ => _tuning(form, type, unlocks, known),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s2),
              child: Row(children: [
                Expanded(
                  child: KButton(
                    key: const Key('detail-pin'),
                    label: widget.state.isPinned(form.id) ? 'Desmarcar' : 'Marcar',
                    primary: false,
                    onTap: known
                        ? () {
                            if (!widget.state.togglePin(form.id)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Até 3 espécies marcadas. Desmarque uma antes.')));
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KButton(
                    key: const Key('detail-fuse'),
                    label: form.layer == FormLayer.eco ? 'Fundir $owned/${widget.state.cb.fusionEcoCount}' : 'Fundir',
                    onTap: form.layer == FormLayer.eco && owned > 0
                        ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BenchScreen(state: widget.state, data: widget.data, openFusion: true)))
                        : null,
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  String _layerLine(BestiaryForm f) => switch (f.layer) {
        FormLayer.spark => 'Fagulha',
        FormLayer.eco => 'Eco · nv. 1 a 20',
        FormLayer.spirit => 'Espírito · nv. 1 a ${widget.state.cb.spiritLevelCap}',
        FormLayer.ritual => 'Espírito · só ritual',
      };

  Widget _arrow(String? label, Key key, VoidCallback? onTap) => GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text((label ?? '').toUpperCase(), style: KTexto.rotulo.copyWith(fontSize: 9, color: KCores.textoMudo)),
        ),
      );

  /// A bolinha: preenchida (capturada), só contorno (vista) ou escura (desconhecida). A que está na tela leva o aro violeta.
  Widget _dot(VariantDot d, EcoType type) {
    final color = d.key.isEmpty ? typeColor(type) : Color(widget.data.variants[d.key]!.tint);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: switch (d.state) { FormStatus.captured => color, FormStatus.seen => KCores.superficie1, FormStatus.unknown => KCores.superficie2 },
        border: Border.all(color: d.state == FormStatus.seen ? color : KCores.contorno, width: 2),
        boxShadow: _variant == d.key && d.state != FormStatus.unknown ? const [BoxShadow(color: KCores.veuVioleta, spreadRadius: 2)] : null,
      ),
    );
  }

  Widget _line(String text, {Color color = KCores.texto, Key? key}) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, key: key, style: KTexto.corpoPequeno.copyWith(color: color)));

  Widget _loreBox(String text, String label) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        decoration: BoxDecoration(color: KCores.superficie1, border: Border.all(color: KCores.contorno, width: kContornoDp)),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$text ', style: KTexto.corpoPequeno.copyWith(color: KCores.texto)),
          TextSpan(text: label, style: KTexto.corpoPequeno.copyWith(fontSize: 12)),
        ])),
      );

  Widget _where(FamilyDef f, bool open) => GridView.count(
        key: const Key('where'),
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.5,
        children: [
          for (final (k, label) in const [('biome', 'Bioma'), ('hour', 'Hora'), ('climate', 'Clima'), ('moon', 'Lua'), ('place', 'Lugar')])
            if (f.where[k] != null)
              Container(
                padding: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.contorno, width: 2)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(fontSize: 7, color: KCores.textoMudo)),
                  Text(open ? f.where[k]! : '???', style: KTexto.corpoPequeno.copyWith(fontSize: 10, height: 1.2, color: KCores.texto), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
        ],
      );

  List<Widget> _research(BestiaryForm form, SpeciesLore? lore, Set<String> unlocks, Map<String, BestiaryEntry> b, bool known) {
    if (form.isSpark) {
      final got = formState(form.id, b) == FormStatus.captured;
      return [
        KSection('Nível de pesquisa ${got ? 1 : 0} de 1'),
        _levelBar(got ? 1 : 0, 1),
        _task('Coletar uma vez', done: got, next: !got, reward: 'Sobre'),
        const KSection('Onde aparece'),
        _where(form.family, got),
      ];
    }
    final species = widget.data.species(form.id);
    if (lore == null) {
      return [
        _line(known ? 'Só responde ao ritual: a pesquisa dela é a do ritual.' : 'Ainda não encontrada.', color: KCores.textoMudo),
        if (species != null && species.ritualOnly && known) RitualResearchPanel(state: widget.state, data: widget.data, species: species),
      ];
    }
    final level = researchLevel(lore.research, form.id, b);
    return [
      KSection('Nível de pesquisa $level de ${lore.research.length}'),
      _levelBar(level, lore.research.length),
      for (var k = 0; k < lore.research.length; k++)
        _task(
          lore.research[k].n > 1 && k == level ? '${lore.research[k].text} · ${taskProgress(lore.research[k], form.id, b)}/${lore.research[k].n}' : lore.research[k].text,
          done: k < level,
          next: k == level,
          reward: _unlockLabels[lore.research[k].unlocks] ?? lore.research[k].unlocks,
        ),
      const KSection('Onde aparece'),
      _where(form.family, unlocks.contains('where')),
      if (unlocks.contains('lore1')) ...[const SizedBox(height: 8), _loreBox(lore.lore[0], 'Lore I')],
    ];
  }

  Widget _levelBar(int level, int max) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          for (var k = 0; k < max; k++)
            Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: k + 1 < max ? 4 : 0),
                decoration: BoxDecoration(color: k < level ? KCores.sinalCiano : KCores.contorno, border: Border.all(color: const Color(0xFF3A2F55))),
              ),
            ),
        ]),
      );

  Widget _task(String text, {required bool done, required bool next, required String reward}) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Container(
            width: 15,
            height: 15,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? KCores.sinalCiano : KCores.superficie2, border: Border.all(color: next ? KCores.veuVioleta : KCores.contorno, width: 2)),
            child: done ? const KTick(color: KCores.fundo) : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: KTexto.corpoPequeno.copyWith(fontSize: 13, color: done || next ? KCores.texto : KCores.textoMudo))),
          Text(reward.toUpperCase(), style: KTexto.rotulo.copyWith(fontSize: 8, color: next ? KCores.veuClaro : KCores.textoMudo)),
        ]),
      );

  List<Widget> _about(BestiaryForm form, SpeciesLore? lore, Set<String> unlocks, bool known, bool famKnown) {
    if (!known) return [_line('Ainda não encontrada. ${famKnown ? 'É da família ${form.family.name}.' : ''}', color: KCores.textoMudo)];
    if (form.isSpark) {
      return [
        _line(form.family.sparkAbout),
        _line('Fagulhas entram sozinhas na Aura e viram ${widget.data.itemName(form.id)}. É a primeira forma da família ${form.family.name}.', color: KCores.textoMudo),
      ];
    }
    if (lore == null) return [_line('Um Espírito que só o ritual chama.', color: KCores.textoMudo)];
    return [
      _line(lore.about),
      for (final (k, key, label) in const [(0, 'lore1', 'Lore I'), (1, 'attributes', 'Lore II'), (2, 'lore3', 'Lore III')])
        unlocks.contains(key) ? _loreBox(lore.lore[k], label) : _line('$label: abre com a pesquisa no nível ${const [1, 3, 5][k]}.', color: KCores.textoMudo),
    ];
  }

  List<Widget> _attributes(BestiaryForm form, Set<String> unlocks, Map<String, BestiaryEntry> b, FormStatus status) {
    if (form.isSpark) {
      return [_line('Três ${widget.data.itemName(form.id)} e um selo simples fazem o selo deste tipo na Bancada.', color: status == FormStatus.unknown ? KCores.textoMudo : KCores.texto)];
    }
    final species = widget.data.species(form.id);
    if (species == null || !(unlocks.contains('attributes') || (widget.data.lore[form.id] == null && status == FormStatus.captured))) {
      return [_line('Atributos reais abrem com a pesquisa no nível 3.', color: KCores.textoMudo)];
    }
    final cb = widget.state.cb, tier = species.isSpirit ? 'spirit' : 'eco', cap = widget.state.balance.levelCapFor(species.id);
    final ability = species.ability;
    final bands = widget.data.tuning.abilityBands;
    // A faixa atual é a da criatura desta espécie de nível mais alto na coleção (sem nenhuma, a do nível 1).
    final owned = [for (final c in widget.state.collection) if (c.speciesId == species.id && !c.debug) c.level];
    final best = owned.isEmpty ? null : owned.reduce((a, b) => a > b ? a : b);
    final family = widget.data.families.where((f) => f.id == familyOfId(species.id)).firstOrNull;
    return [
      const KSection('Poder'),
      _line('${cb.power(tier, 1)} no nível 1 · ${cb.power(tier, cap)} no nível $cap'),
      const KSection('Habilidade de mapa'),
      if (ability == null)
        _line('Nenhuma.', color: KCores.textoMudo)
      else ...[
        _line(abilityText(ability, best ?? 1, bands), key: const Key('species-ability')),
        _line(best == null ? 'Nenhuma na coleção: a faixa do nível 1.' : 'Pela sua de nível $best.', color: KCores.textoMudo),
        for (var k = 0; k < ability.bands.length && k < bands.length; k++) _line('Níveis ${bands[k].$1}${k + 1 == bands.length ? '+' : ' a ${bands[k].$2}'}: ${abilityLabel(ability.kind, ability.bands[k])}', color: KCores.textoMudo),
      ],
      if (family != null && family.workTitle.isNotEmpty) ...[
        const KSection('Trabalho'),
        _line('Trabalho: ${family.workTitle} (em breve)', key: const Key('species-work')),
        if (family.workAbout.isNotEmpty) _line(family.workAbout, color: KCores.textoMudo),
      ],
      const KSection('Traços'),
      for (final d in variantDots(form.id, widget.data, b))
        if (d.key.isNotEmpty && d.state != FormStatus.unknown) _line('${widget.data.variants[d.key]!.name}: ${widget.data.variants[d.key]!.trait}'),
      if (!variantDots(form.id, widget.data, b).any((d) => d.key.isNotEmpty && d.state != FormStatus.unknown)) _line('Nenhuma variante encontrada ainda.', color: KCores.textoMudo),
    ];
  }

  List<Widget> _tuning(BestiaryForm form, EcoType type, Set<String> unlocks, bool known) {
    if (form.isSpark) return [_line('Fagulhas não se sintonizam: basta chegar perto.', color: KCores.textoMudo)];
    if (!known) return [_line('Ainda não encontrada.', color: KCores.textoMudo)];
    final species = widget.data.species(form.id);
    String names(Iterable<EcoType> ts) => ts.isEmpty ? 'nenhum' : ts.map(typeLabel).join(', ');
    final beatenBy = [for (final t in EcoType.values) if (t.beats(type)) t];
    return [
      const KSection('Como responde'),
      _line(species?.ritualOnly ?? false ? 'Só ao ritual, no lugar e na hora certos.' : 'À sintonia no dial.'),
      const KSection('Resistência'),
      _line(typePatternText(type)),
      const KSection('Contenção'),
      _line('Forte contra: ${names(type.strongAgainst)}'),
      _line('Fraco contra: ${names(type.weakAgainst)}'),
      _line('Selos e Círculo que ampliam a tolerância: ${names(beatenBy)}'),
      if (unlocks.contains('tolerance')) _line('Pesquisa: tolerância ×${widget.data.researchTolerance} nesta espécie.', color: KCores.sinalCiano),
    ];
  }
}
