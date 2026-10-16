/// Ícones em pixel dos apps do celular: matrizes de 12 × 12 desenhadas por código, sem arquivo de imagem. Cada letra é
/// uma cor da paleta. O app bloqueado aparece com glitch; o app que acaba de ser liberado se forma com a costura violeta.
library;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'phone_apps.dart';

const int phoneIconGrid = 12;
const double phoneIconPixel = 4;
const Duration phoneFormDuration = Duration(milliseconds: 600);

const Map<String, List<String>> phoneIconArt = {
  PhoneAppId.vision: [
    '............', '............', '...llllll...', '..l......l..', '.l..cccc..l.', 'l...cttc...l',
    'l...cttc...l', '.l..cccc..l.', '..l......l..', '...llllll...', '............', '............',
  ],
  PhoneAppId.radar: [
    '....cccc....', '..cc....cc..', '.c.......vc.', '.c......v..c', 'c......v...c', 'c.....v....c',
    'c....vv....c', 'c....vv....c', '.c........c.', '.cc......cc.', '..cc....cc..', '....cccc....',
  ],
  PhoneAppId.bestiary: [
    '..vvvvvvvv..', '.vllllllllv.', '.vl..cc..lv.', '.vl.cccc.lv.', '.vl.c..c.lv.', '.vl.cccc.lv.',
    '.vl..cc..lv.', '.vllllllllv.', '.vl.tttt.lv.', '.vllllllllv.', '..vvvvvvvv..', '............',
  ],
  PhoneAppId.circle: [
    '....vvvv....', '..vv.cc.vv..', '.v...cc...v.', '.v........v.', 'v..........v', 'v..........v',
    'v..........v', 'vcc......ccv', '.vcc....ccv.', '..vv....vv..', '....vvvv....', '............',
  ],
  PhoneAppId.bag: [
    '....vvvv....', '...v....v...', '...v....v...', '.vvvvvvvvvv.', '.vllllllllv.', '.vllllllllv.',
    '.vlllooollv.', '.vlllooollv.', '.vllllllllv.', '.vllllllllv.', '.vvvvvvvvvv.', '............',
  ],
  PhoneAppId.bench: [
    '....tttt....', '.....tt.....', '.....tt.....', '....tttt....', '...t.oo.t...', '..t.oooo.t..',
    '..toooooot..', '.t.oooooo.t.', '.t.oooooo.t.', '.tttttttttt.', '............', '............',
  ],
  PhoneAppId.chat: [
    '............', '.vvvvvvvvvv.', 'vllllllllllv', 'vl.t..t..tlv', 'vllllllllllv', 'vllllllllllv',
    '.vvvvvvvvvv.', '..vlv.......', '..vv........', '..v.........', '............', '............',
  ],
  PhoneAppId.forum: [
    '............', '.vvvvvvvvvv.', '.vcccccc..v.', '.v........v.', '.vttttttt.v.', '.v........v.',
    '.vtttttt..v.', '.v........v.', '.vttttttt.v.', '.v........v.', '.vvvvvvvvvv.', '............',
  ],
  PhoneAppId.profile: [
    '............', '....llll....', '...llllll...', '...llllll...', '...llllll...', '....llll....',
    '............', '..vvvvvvvv..', '.vvvvvvvvvv.', '.vvvvvvvvvv.', '.vvvvvvvvvv.', '............',
  ],
  PhoneAppId.settings: [
    '.....tt.....', '..t..tt..t..', '..tttttttt..', '...tt..tt...', '.ttt....ttt.', 'tttt....tttt',
    'tttt....tttt', '.ttt....ttt.', '...tt..tt...', '..tttttttt..', '..t..tt..t..', '.....tt.....',
  ],
};

const Map<String, Color> _palette = {
  'v': KCores.veuVioleta,
  'l': KCores.veuClaro,
  'c': KCores.sinalCiano,
  'o': KCores.brasaLaranja,
  't': KCores.texto,
  'm': KCores.textoMudo,
};

enum PhoneIconMode { normal, locked, forming }

/// O ícone de [appId]. Em `forming`, [t] (0 a 1) é o quanto da costura já correu; as linhas acima dela já assentaram.
class PhoneIconPainter extends CustomPainter {
  const PhoneIconPainter(this.appId, {this.mode = PhoneIconMode.normal, this.t = 1});

  final String appId;
  final PhoneIconMode mode;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final art = phoneIconArt[appId];
    if (art == null) return;
    final p = Paint()..isAntiAlias = false;
    const px = phoneIconPixel;
    for (var r = 0; r < phoneIconGrid; r++) {
      final glitched = switch (mode) {
        PhoneIconMode.normal => false,
        PhoneIconMode.locked => true,
        PhoneIconMode.forming => (r + 1) / phoneIconGrid > t,
      };
      final dx = glitched ? ((r * 7 + 3) % 5 - 2) * px : 0.0;
      for (var c = 0; c < phoneIconGrid; c++) {
        final ch = art[r][c];
        if (ch == '.') continue;
        if (glitched && (r * 3 + c * 5) % 7 == 0) continue; // pixel que falta
        final color = mode == PhoneIconMode.locked ? ((r + c) % 6 == 0 ? KCores.textoMudo : KCores.cidade) : _palette[ch]!;
        canvas.drawRect(Rect.fromLTWH(c * px + dx, r * px, px, px), p..color = color);
      }
    }
    if (mode == PhoneIconMode.forming && t < 1) {
      canvas.drawRect(Rect.fromLTWH(0, t * size.height - 1.5, size.width, kContornoDp), p..color = KCores.veuVioleta);
    }
  }

  @override
  bool shouldRepaint(PhoneIconPainter old) => old.appId != appId || old.mode != mode || old.t != t;
}
