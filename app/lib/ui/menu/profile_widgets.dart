/// Peças do Perfil: o painel com contorno e sombra dura, a barra de XP, a linha de estatística e os selos pixel art.
library;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Um painel do Perfil: `superficie1`, contorno de 3 dp e sombra dura.
class ProfilePanel extends StatelessWidget {
  const ProfilePanel({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: KEspaco.s2 + 3),
        padding: const EdgeInsets.all(KEspaco.s2),
        decoration: BoxDecoration(
          color: KCores.superficie1,
          border: Border.all(color: KCores.contorno, width: kContornoDp),
          boxShadow: KSombra.pixel,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
          const SizedBox(height: KEspaco.s1),
          child,
        ]),
      );
}

/// Barra de XP de pixel reto: [fraction] de 0 a 1.
class XpBar extends StatelessWidget {
  const XpBar({required this.fraction, super.key});

  final double fraction;

  @override
  Widget build(BuildContext context) => Container(
        height: 18,
        decoration: BoxDecoration(color: KCores.fundo, border: Border.all(color: KCores.contorno, width: kContornoDp)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: fraction.clamp(0.0, 1.0), heightFactor: 1, child: const ColoredBox(color: KCores.sinalCiano)),
        ),
      );
}

/// Rótulo pequeno em cima e valor grande embaixo.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 140,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
          const SizedBox(height: 3),
          Text(value, style: KTexto.numero),
        ]),
      );
}

const Map<String, int> _sealPalette = {'O': 0xFF1A1424, 'v': 0xFF9B7BFF, 'p': 0xFF6A52C4, 'C': 0xFF5FD3C6, 'W': 0xFFE8E4F4};

/// O selo de fundador, 11 x 11: um disco violeta com uma estrela ciano.
const List<String> founderSealRows = [
  '...OOOOO...',
  '.OOvvvvvOO.',
  '.OvvvCvvvO.',
  'OvvvvCvvvvO',
  'OvvvCCCvvvO',
  'OvCCCWCCCvO',
  'OvvvCCCvvpO',
  'OvvvCvCvvpO',
  '.OpvCvCvpO.',
  '.OOppppOO..',
  '...OOOOO...',
];

/// Um selo desenhado por código a partir de [rows] (um caractere por pixel da paleta).
class SealPainter extends CustomPainter {
  const SealPainter(this.rows);

  final List<String> rows;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / rows.first.length;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final c = _sealPalette[rows[y][x]];
        if (c == null) continue;
        canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), Paint()..color = Color(c)..isAntiAlias = false);
      }
    }
  }

  @override
  bool shouldRepaint(SealPainter old) => old.rows != rows;
}

class Seal extends StatelessWidget {
  const Seal({required this.rows, required this.label, super.key});

  final List<String> rows;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 88,
        child: Column(children: [
          CustomPaint(size: const Size(66, 66), painter: SealPainter(rows)),
          const SizedBox(height: KEspaco.s1),
          Text(label.toUpperCase(), style: KTexto.rotulo, textAlign: TextAlign.center),
        ]),
      );
}
