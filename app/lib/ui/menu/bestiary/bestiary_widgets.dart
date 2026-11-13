/// Peças do Bestiário que outras telas podem usar: a etiqueta de tipo, a ficha com filtro, a arte de uma forma com o
/// estado dela, o cartão de família, a célula de espécie, as abas e o botão. No tema do Design System (`tema.dart`).
library;

import 'package:flutter/material.dart';

import '../../../capture/eco_type.dart';
import '../../../player/bestiary_view.dart';
import '../../../player/research.dart';
import '../../colors.dart' show typeColor;
import '../../pressable.dart';
import '../../sprites/sprite_image.dart';
import '../../tema.dart';
import '../../type_label.dart';
import '../screen_frame.dart' show SpeciesImage;

const TextStyle _tiny = TextStyle(fontFamily: KFonte.pixel, fontSize: 9, height: 12 / 9, letterSpacing: 1, color: KCores.texto);

BoxDecoration kCard({Color line = KCores.contorno, Color fill = KCores.superficie1, bool glow = false}) => BoxDecoration(
      color: fill,
      border: Border.all(color: line, width: kContornoDp),
      boxShadow: glow ? KSombra.brilhoVeu : KSombra.pixel,
    );

/// Etiqueta pequena: um quadrado na cor do tipo (ou sem ele) e o texto.
class KTag extends StatelessWidget {
  const KTag(this.label, {this.dot, this.color = KCores.texto, super.key});

  factory KTag.type(EcoType t) => KTag(typeLabel(t), dot: typeColor(t));

  final String label;
  final Color? dot;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.contorno, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) Container(width: 6, height: 6, color: dot, margin: const EdgeInsets.only(right: 5)),
          Text(label.toUpperCase(), style: _tiny.copyWith(color: color)),
        ]),
      );
}

/// Ficha de filtro que liga e desliga.
class KChip extends StatelessWidget {
  const KChip({required this.label, required this.on, required this.onTap, this.dot, super.key});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: KCores.superficie2,
            border: Border.all(color: on ? KCores.veuVioleta : KCores.contorno, width: kContornoDp),
            boxShadow: on ? KSombra.brilhoVeu : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot != null) Container(width: 6, height: 6, color: dot, margin: const EdgeInsets.only(right: 6)),
            Text(label.toUpperCase(), style: _tiny.copyWith(color: on ? KCores.texto : KCores.textoMudo)),
          ]),
        ),
      );
}

/// Botão do sistema: cheio (violeta) ou secundário (contorno violeta).
class KButton extends StatelessWidget {
  const KButton({required this.label, required this.onTap, this.primary = true, super.key});

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    return Pressable(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: kToqueMinDp),
        padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
        decoration: BoxDecoration(
          color: primary && !off ? KCores.veuVioleta : KCores.superficie1,
          border: Border.all(color: primary ? KCores.contorno : (off ? KCores.cidade : KCores.veuVioleta), width: kContornoDp),
          boxShadow: KSombra.pixel,
        ),
        child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: off ? KCores.textoMudo : (primary ? KCores.fundo : KCores.texto))),
      ),
    );
  }
}

/// Um visto de pixel, desenhado: dois traços em degraus.
class KTick extends StatelessWidget {
  const KTick({required this.color, this.size = 9, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _TickPainter(color));
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Numa grade de 5 x 5: desce dois degraus e sobe quatro.
    final u = size.width / 5, p = Paint()..color = color;
    for (final (x, y) in const [(0, 2), (1, 3), (2, 4), (3, 3), (3, 2), (4, 1), (4, 0)]) {
      canvas.drawRect(Rect.fromLTWH(x * u, y * u, u, u), p);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}

/// A arte de uma forma com o estado dela: colorida com a marca ciano (capturada), colorida com o olho (vista) ou
/// silhueta (nunca vista).
class FormArt extends StatelessWidget {
  const FormArt({required this.sprite, required this.state, this.size = 58, this.selected = false, this.pinned = false, super.key});

  final EcoSprite? sprite;
  final FormStatus state;
  final double size;
  final bool selected;
  final bool pinned;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size + 6,
        height: size + 6,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            top: 6,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: selected ? KCores.veuVioleta : KCores.contorno, width: kContornoDp)),
              child: SpeciesImage(sprite: sprite, silhouette: state == FormStatus.unknown, size: size - 12),
            ),
          ),
          if (state != FormStatus.unknown)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 15,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: state == FormStatus.captured ? KCores.sinalCiano : KCores.superficie1, border: Border.all(color: KCores.contorno, width: 2)),
                // A marca é desenhada (um visto ou um olho de pixel): as fontes do jogo não têm esses sinais.
                child: state == FormStatus.captured ? const KTick(color: KCores.fundo) : Container(width: 5, height: 5, color: KCores.veuClaro),
              ),
            ),
          if (pinned) Positioned(left: -3, top: 0, child: Container(width: 9, height: 9, color: KCores.brasaLaranja)),
        ]),
      );
}

/// O cartão de uma família: nome, tipo, pesquisa em porcentagem e a linha de fusão, com o estado de cada forma. Antes de
/// a primeira forma ser vista, é "Família ???".
class FamilyCard extends StatelessWidget {
  const FamilyCard({required this.family, required this.forms, required this.states, required this.percent, required this.sprites, required this.onTap, this.known = true, this.pinned = const [], super.key});

  final FamilyDef family;
  final List<BestiaryForm> forms;
  final List<FormStatus> states;
  final int percent;
  final Map<String, EcoSprite> sprites;
  final void Function(BestiaryForm form) onTap;
  final bool known;
  /// As formas marcadas no Bestiário (até 3).
  final List<String> pinned;

  @override
  Widget build(BuildContext context) {
    final type = EcoType.parse(family.type);
    return Container(
      key: Key('family-${family.id}'),
      margin: const EdgeInsets.only(bottom: KEspaco.s2),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      decoration: kCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(known ? family.name.toUpperCase() : 'FAMÍLIA ???', style: KTexto.rotulo.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          known ? KTag.type(type) : const KTag('???'),
          const Spacer(),
          Text('$percent%', style: _tiny.copyWith(color: KCores.textoMudo)),
        ]),
        const SizedBox(height: 6),
        Container(
          height: 4,
          color: KCores.contorno,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: percent / 100, child: Container(color: KCores.sinalCiano)),
        ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < forms.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.only(top: 28), child: Text('›', style: TextStyle(fontFamily: KFonte.pixel, fontSize: 12, color: KCores.textoMudo))),
            Expanded(
              child: Pressable(
                onTap: () => onTap(forms[i]),
                child: Column(key: Key('form-${forms[i].id}'), children: [
                  FormArt(sprite: sprites[forms[i].spriteKey], state: states[i], pinned: pinned.contains(forms[i].id)),
                  const SizedBox(height: 4),
                  Text(
                    states[i] == FormStatus.unknown ? '???' : forms[i].name,
                    style: KTexto.corpoPequeno.copyWith(fontSize: 12, height: 14 / 12, color: states[i] == FormStatus.unknown ? KCores.textoMudo : KCores.texto),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(formLayerNames[forms[i].layer]!.toUpperCase(), style: _tiny.copyWith(fontSize: 8, color: KCores.textoMudo)),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// A célula de uma forma na grade: número, arte, nome e a cor do tipo no canto.
class SpeciesCell extends StatelessWidget {
  const SpeciesCell({required this.form, required this.state, required this.sprite, required this.onTap, this.pinned = false, super.key});

  final BestiaryForm form;
  final FormStatus state;
  final EcoSprite? sprite;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          key: Key('cell-${form.id}'),
          padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
          decoration: BoxDecoration(color: KCores.superficie1, border: Border.all(color: pinned ? KCores.brasaLaranja : KCores.contorno, width: kContornoDp)),
          child: Stack(children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: Text(form.number.toString().padLeft(3, '0'), style: _tiny.copyWith(fontSize: 7, color: KCores.textoMudo))),
              SpeciesImage(sprite: sprite, silhouette: state == FormStatus.unknown, size: 42),
              const SizedBox(height: 2),
              Text(
                state == FormStatus.unknown ? '???' : form.name,
                style: KTexto.corpoPequeno.copyWith(fontSize: 10, height: 12 / 10, color: state == FormStatus.unknown ? KCores.textoMudo : KCores.texto),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: state == FormStatus.captured ? typeColor(EcoType.parse(form.family.type)) : (state == FormStatus.seen ? KCores.superficie1 : KCores.superficie2),
                  border: state == FormStatus.seen ? Border.all(color: typeColor(EcoType.parse(form.family.type)), width: 1) : null,
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Abas em linha: a ativa tem o traço violeta embaixo.
class KTabs extends StatelessWidget {
  const KTabs({required this.labels, required this.index, required this.onTap, super.key});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KCores.contorno, width: kContornoDp))),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                key: Key('tab-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == index ? KCores.veuVioleta : Colors.transparent, width: kContornoDp))),
                  child: Text(labels[i].toUpperCase(), style: _tiny.copyWith(color: i == index ? KCores.texto : KCores.textoMudo)),
                ),
              ),
            ),
        ]),
      );
}

/// Dois lados lado a lado, o ativo em violeta (Famílias / Grade).
class KSegment extends StatelessWidget {
  const KSegment({required this.labels, required this.index, required this.onTap, super.key});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: KCores.contorno, width: kContornoDp)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                key: Key('seg-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  alignment: Alignment.center,
                  color: i == index ? KCores.veuVioleta : KCores.superficie1,
                  child: Text(labels[i].toUpperCase(), style: _tiny.copyWith(fontSize: 10, color: i == index ? KCores.fundo : KCores.textoMudo)),
                ),
              ),
            ),
        ]),
      );
}

/// O título pequeno de uma seção.
class KSection extends StatelessWidget {
  const KSection(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 6, bottom: 6), child: Text(text.toUpperCase(), style: _tiny.copyWith(color: KCores.textoMudo)));
}

/// A folha de filtro da grade: tipo, camada e estado. Fecha devolvendo o filtro escolhido.
class FilterSheet extends StatefulWidget {
  const FilterSheet({required this.initial, required this.countOf, super.key});

  final BestiaryFilter initial;

  /// Quantas formas o filtro deixa passar, para o botão.
  final int Function(BestiaryFilter f) countOf;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late BestiaryFilter _f = widget.initial;

  Set<T> _toggle<T>(Set<T> set, T v) => set.contains(v) ? ({...set}..remove(v)) : {...set, v};

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          key: const Key('filter-sheet'),
          padding: const EdgeInsets.fromLTRB(KEspaco.s2, KEspaco.s2, KEspaco.s2, KEspaco.s3),
          decoration: const BoxDecoration(color: KCores.superficie1, border: Border(top: BorderSide(color: KCores.veuVioleta, width: kContornoDp))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FILTRAR', style: KTexto.rotulo),
            const KSection('Tipo'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in EcoType.values)
                KChip(key: Key('filter-type-${t.name}'), label: typeLabel(t), dot: typeColor(t), on: _f.types.contains(t.name), onTap: () => setState(() => _f = _f.copyWith(types: _toggle(_f.types, t.name)))),
            ]),
            const KSection('Camada'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final l in const [FormLayer.spark, FormLayer.eco, FormLayer.spirit])
                KChip(key: Key('filter-layer-${l.name}'), label: formLayerNames[l]!, on: _f.layers.contains(l), onTap: () => setState(() => _f = _f.copyWith(layers: _toggle(_f.layers, l)))),
            ]),
            const KSection('Estado'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (s, label) in const [(FormStatus.captured, 'Capturada'), (FormStatus.seen, 'Vista'), (FormStatus.unknown, '???')])
                KChip(key: Key('filter-state-${s.name}'), label: label, on: _f.states.contains(s), onTap: () => setState(() => _f = _f.copyWith(states: _toggle(_f.states, s)))),
              KChip(key: const Key('filter-incomplete'), label: 'Só pesquisa incompleta', on: _f.incompleteOnly, onTap: () => setState(() => _f = _f.copyWith(incompleteOnly: !_f.incompleteOnly))),
            ]),
            const SizedBox(height: KEspaco.s2),
            Row(children: [
              Expanded(child: KButton(label: 'Limpar', primary: false, onTap: () => setState(() => _f = BestiaryFilter(query: _f.query)))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: KButton(key: const Key('filter-apply'), label: 'Ver ${widget.countOf(_f)} formas', onTap: () => Navigator.of(context).pop(_f))),
            ]),
          ]),
        ),
      );
}
