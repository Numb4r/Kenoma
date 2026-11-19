/// Peças de interface reaproveitáveis no estilo da Bolsa (0.26.0, docs/art/estilo-ui.md): ícone em pixel inteiro, ícone e
/// etiqueta de tipo, interruptor e diálogo de confirmação com as molduras do Aseprite (`assets/art/ui/`). Sem a arte
/// (testes, arquivo faltando), cada peça cai num desenho simples: arte nunca bloqueia código.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../capture/eco_type.dart';
import 'colors.dart';
import 'craft/ui_art.dart';
import 'pressable.dart';
import 'type_label.dart';

/// O fundo escuro neutro das etiquetas (o `fundo` do guia).
const Color kTextOnFaceBackground = Color(0xFF120E1A);

/// O violeta claro (`#c9b8ff`): o violeta do Véu em texto sobre a face do botão, onde o `#9b7bff` fica em 3,7:1.
const Color kVeilLight = Color(0xFFC9B8FF);

/// A cor de texto que um rótulo em [c] usa sobre a face do botão (`#3d3357`): o violeta, o cinza e o laranja viram o tom claro.
Color onButtonFace(Color c) => switch (c) {
      kVeil => kVeilLight,
      kDim => kText,
      kEssence => const Color(0xFFFFA07A), // a Essência na face fica em 4,49:1; o tom claro dela passa
      _ => c,
    };

/// O tamanho em dp de [art] pixels desenhados na maior escala inteira de pixel físico que cabe em [target] dp (nítido em
/// qualquer densidade; nunca menos de 1 pixel físico por pixel de arte).
double snapUiSize(int art, double target, double dpr) => (target * dpr / art).floor().clamp(1, 1 << 20) * art / dpr;

/// Um ícone de [name] (`apps/radar`, `moon/moon_3`, `climate/storm`...) em pixel inteiro, do tamanho mais próximo de
/// [size] dp que fica nítido. [flip] espelha (a lua no hemisfério norte). Sem a arte, [fallback] ou nada.
class UiIcon extends StatelessWidget {
  const UiIcon(this.name, {this.size = 48, this.flip = false, this.fallback, this.opacity = 1, super.key});

  final String name;
  final double size;
  final bool flip;
  final Widget? fallback;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final img = UiArt.instance?.image(name);
    if (img == null) return SizedBox(width: size, height: size, child: fallback);
    final side = snapUiSize(img.width, size, MediaQuery.devicePixelRatioOf(context));
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: SizedBox(width: side, height: side * img.height / img.width, child: CustomPaint(painter: _IconPainter(img, flip, opacity)))),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.img, this.flip, this.opacity);

  final ui.Image img;
  final bool flip;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none..color = Color.fromRGBO(255, 255, 255, opacity));
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.img != img || old.flip != flip || old.opacity != opacity;
}

/// O ícone do tipo: o de 16 px, ou o de 8 (chapado, para etiquetas) quando [small].
class TypeIcon extends StatelessWidget {
  const TypeIcon(this.type, {this.size = 24, this.small = false, super.key});

  final EcoType type;
  final double size;
  final bool small;

  @override
  Widget build(BuildContext context) => UiIcon('types/${type.name}${small ? '_8' : ''}',
      size: size, fallback: DecoratedBox(decoration: BoxDecoration(color: typeColor(type), border: Border.all(color: kOutline))));
}

/// A etiqueta de tipo: o ícone de 8 e o nome no tom claro, sobre o fundo escuro neutro com o aro no tom escuro do tipo
/// (cor + ícone, nunca só cor). O tom claro sobre o escuro do próprio tipo ficava abaixo de 4,5:1 (2,0 a 4,2).
class TypeTag extends StatelessWidget {
  const TypeTag(this.type, {super.key});

  final EcoType type;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
        decoration: BoxDecoration(color: kTextOnFaceBackground, border: Border.all(color: typeColorDark(type), width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TypeIcon(type, size: 12, small: true),
          const SizedBox(width: 3),
          Text(typeLabel(type).toUpperCase(), style: TextStyle(fontSize: 8, color: typeColorLight(type))),
        ]),
      );
}

/// O interruptor do kit (`switch_off` e `switch_on`, o ligado no violeta do Véu): mesmo tamanho nos dois estados, o
/// estado nunca só pela cor. Alvo de toque de 48 dp.
class KitSwitch extends StatelessWidget {
  const KitSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final on = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: on,
      child: Pressable(
        onTap: on ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Opacity(
            opacity: on ? 1 : 0.45,
            child: UiIcon(value ? 'switch_on' : 'switch_off',
                size: 42, fallback: Switch(value: value, onChanged: onChanged, activeThumbColor: kVeil)),
          ),
        ),
      ),
    );
  }
}

/// No lugar do `SwitchListTile` do Material, com os mesmos nomes de parâmetro que as telas usam.
class KitSwitchTile extends StatelessWidget {
  const KitSwitchTile({required this.title, required this.value, required this.onChanged, this.subtitle, this.contentPadding, this.activeThumbColor, super.key});

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  /// Ignorado: o ligado é sempre o violeta do Véu (escolha do jogador).
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    DefaultTextStyle.merge(style: const TextStyle(color: kText), child: title),
                    if (subtitle != null) ...[const SizedBox(height: 3), subtitle!],
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              KitSwitch(value: value, onChanged: onChanged),
            ]),
          ),
        ),
      );
}

/// No lugar do `AlertDialog` do Material: a moldura `dialog` (faixa de título em cima), com os mesmos nomes de parâmetro.
class KitAlertDialog extends StatelessWidget {
  const KitAlertDialog({this.title, this.content, this.actions, this.backgroundColor, this.shape, super.key});

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  /// Ignorados: a moldura é a do kit.
  final Color? backgroundColor;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: UiFrame(
          name: 'dialog',
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null) DefaultTextStyle.merge(style: const TextStyle(fontSize: 12, color: kText), child: title!),
            if (title != null) const SizedBox(height: 15),
            if (content != null) Flexible(child: SingleChildScrollView(child: DefaultTextStyle.merge(style: const TextStyle(color: kText, height: 1.6), child: content!))),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: actions!),
            ],
          ]),
        ),
      );
}

/// Uma peça fixa do kit ([name], ou o quadro [frame] de uma tira de [frames]) na maior escala inteira de pixel físico que
/// cabe em [box], centrada. [overlay] recebe quantos dp vale um pixel de arte e o canto da peça, para pôr por cima o que
/// fica dentro dela (o Conjurador no retrato, o nível, o XP). Sem a arte, [fallback].
class UiPiece extends StatelessWidget {
  const UiPiece(this.name, {required this.box, this.frame = 0, this.frames = 1, this.overlay, this.fallback, this.rotation = 0, super.key});

  final String name;
  final Size box;
  final int frame, frames;
  final double rotation;
  final List<Widget> Function(double px, Offset origin)? overlay;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final img = UiArt.instance?.image(name);
    if (img == null) return fallback ?? SizedBox.fromSize(size: box); // a reserva com o tamanho dela, como antes do kit
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fw = img.width ~/ frames, fh = img.height;
    final k = math.max(1, math.min(box.width * dpr / fw, box.height * dpr / fh).floor());
    final px = k / dpr, w = fw * px, h = fh * px;
    final origin = Offset((box.width - w) / 2, (box.height - h) / 2);
    return SizedBox.fromSize(
      size: box,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: origin.dx,
          top: origin.dy,
          width: w,
          height: h,
          child: Transform.rotate(angle: rotation, child: CustomPaint(painter: _FramePainter(img, frame.clamp(0, frames - 1) * fw, fw))),
        ),
        ...?overlay?.call(px, origin),
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.img, this.x0, this.fw);

  final ui.Image img;
  final int x0, fw;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
      img, Rect.fromLTWH(x0.toDouble(), 0, fw.toDouble(), img.height.toDouble()), Offset.zero & size, Paint()..filterQuality = FilterQuality.none);

  @override
  bool shouldRepaint(_FramePainter old) => old.img != img || old.x0 != x0;
}

/// Tinge pela luminância: o escuro (contorno) continua escuro e o claro vira [c]. Para variar a cor de uma peça neutra.
ColorFilter lumaTint(Color c) => ColorFilter.matrix([
      0.299 * c.r, 0.587 * c.r, 0.114 * c.r, 0, 0, //
      0.299 * c.g, 0.587 * c.g, 0.114 * c.g, 0, 0, //
      0.299 * c.b, 0.587 * c.b, 0.114 * c.b, 0, 0, //
      0, 0, 0, 1, 0,
    ]);

/// A barra do kit (`bar_frame` com `bar_fill` por dentro): capacidade, XP, progresso. [fraction] de 0 a 1.
class KitBar extends StatelessWidget {
  const KitBar({required this.fraction, this.height = 6 * kUiPixel, super.key});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    // Largura cheia mesmo numa coluna solta: o Stack não pode encolher até o preenchimento (0 XP sumia com a moldura).
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(children: [
        const Positioned.fill(child: UiFrame(name: 'bar_frame', padding: EdgeInsets.zero, child: SizedBox.expand())),
        if (f > 0)
          FractionallySizedBox(
            widthFactor: f,
            child: const UiFrame(name: 'bar_fill', padding: EdgeInsets.zero, fallbackFill: kSignal, fallbackLine: kOutline, child: SizedBox.expand()),
          ),
      ]),
    );
  }
}
