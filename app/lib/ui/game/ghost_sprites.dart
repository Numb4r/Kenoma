/// Os sprites do Tráfego do Véu, em pixel art desenhada por código: matrizes de caracteres, uma paleta por modelo
/// e uma `Picture` por (modelo, paleta, quadro) gravada uma vez. Sem arquivos de imagem. Cores do jogo
/// (`colors.dart`); o contorno é `kOutline`, nunca preto puro.
library;

import 'dart:ui' as ui;

import '../../world/veil_traffic.dart';
import '../colors.dart';

/// Papéis de cor das matrizes: `.` vazio, `o` contorno, `b` corpo, `a` teto/detalhe, `d` corpo escuro, `g` vidro,
/// `y` farol, `k` pneu, `h` cabelo/capacete, `s` pele, `t` blusa, `p` calça, `u` blusa da criança, `n` bengala.
typedef SpriteRows = List<String>;

/// Carro visto de cima, de frente para a direita (+x): retângulo arredondado, cabine e vidros, faróis e pneus.
SpriteRows _car(int w, int h, {required int cabin0, required int cabin1, int bed = 0}) {
  final rows = <String>[];
  for (var y = 0; y < h; y++) {
    final sb = StringBuffer();
    for (var x = 0; x < w; x++) {
      final edgeX = x == 0 || x == w - 1, edgeY = y == 0 || y == h - 1;
      String c;
      if (edgeX && edgeY) {
        c = '.';
      } else if (edgeY && (x == 3 || x == 4 || x == w - 5 || x == w - 4)) {
        c = 'k'; // pneus aparecendo nas laterais
      } else if (edgeY || edgeX) {
        c = (x == w - 1 && (y == 1 || y == h - 2)) ? 'y' : 'o';
      } else if (x == cabin1 && y >= 1 && y <= h - 2) {
        c = 'g'; // para-brisa
      } else if (x == cabin0 && y >= 1 && y <= h - 2) {
        c = 'g'; // vidro traseiro
      } else if (x > cabin0 && x < cabin1) {
        c = 'a'; // teto
      } else if (bed > 0 && x >= 2 && x <= bed && y >= 2 && y <= h - 3) {
        c = 'd'; // caçamba
      } else {
        c = 'b';
      }
      sb.write(c);
    }
    rows.add(sb.toString());
  }
  return rows;
}

final SpriteRows _hatch = _car(14, 7, cabin0: 3, cabin1: 10);
final SpriteRows _sedan = _car(16, 7, cabin0: 4, cabin1: 11);
final SpriteRows _pickup = _car(17, 8, cabin0: 9, cabin1: 14, bed: 7);

const SpriteRows _moto = [
  '......oo....',
  '.kk..obbo.yy',
  'kkkkoohhbboo',
  '.kk..obbo.yy',
  '......oo....',
];

const SpriteRows _cyclist = [
  '....oo....',
  '.kk.obbo.k',
  'kkkoohhbok',
  '.kk.obbo.k',
  '....oo....',
];

const SpriteRows _adultTop = [
  '..ooo..',
  '.ohhho.',
  '.ossso.',
  '..ooo..',
  '.ottto.',
  'ottttto',
  'ottttto',
  'ottttto',
  '.opppo.',
  '.opppo.',
];
const SpriteRows _adultLegsA = ['opo.opo', 'opo.opo', 'oko.oko'];
const SpriteRows _adultLegsB = ['.opopo.', '.opopo.', '.okoko.'];

const SpriteRows _childTop = [
  '.ooo.',
  'ohhho',
  'ossso',
  '.ooo.',
  'ouuuo',
  'ouuuo',
  'opppo',
];
const SpriteRows _childLegsA = ['op.po', 'okoko'];
const SpriteRows _childLegsB = ['opopo', 'okoko'];

SpriteRows _adult(int frame) => [..._adultTop, ...(frame == 0 ? _adultLegsA : _adultLegsB)];

SpriteRows _pair(int frame) {
  final adult = _adult(frame);
  final child = [..._childTop, ...(frame == 0 ? _childLegsA : _childLegsB)];
  final pad = adult.length - child.length;
  return [
    for (var i = 0; i < adult.length; i++) '${adult[i]}.${i < pad ? '.....' : child[i - pad]}',
  ];
}

SpriteRows _elder(int frame) {
  final a = _adult(frame);
  return [
    for (var i = 0; i < a.length; i++)
      // cabeça e ombros inclinados um pixel à frente (esquerda), bengala na direita
      '${i < 5 ? '${a[i].substring(1)}.' : a[i]}${i >= 5 ? 'n' : '.'}',
  ];
}

/// As linhas do sprite de [m] no [frame] (0 ou 1; só os passantes de pé têm dois quadros).
SpriteRows spriteRows(GhostModel m, int frame) => switch (m) {
      GhostModel.hatch => _hatch,
      GhostModel.sedan => _sedan,
      GhostModel.pickup => _pickup,
      GhostModel.moto => _moto,
      GhostModel.cyclist => _cyclist,
      GhostModel.adult => _adult(frame),
      GhostModel.childPair => _pair(frame),
      GhostModel.elder => _elder(frame),
    };

/// Os modelos desenhados de pé na tela, com dois quadros de caminhada. Os outros se desenham de cima e giram.
bool isUpright(GhostModel m) => m == GhostModel.adult || m == GhostModel.childPair || m == GhostModel.elder;

int framesOf(GhostModel m) => isUpright(m) ? 2 : 1;

/// Colunas da matriz do carro de referência: o `ghost_car_m` do balance vale para esta largura.
const int carRefPx = 16;

/// Linhas dos passantes de pé: o `ghost_pedestrian_m` do balance vale para esta altura.
const int pedRefPx = 13;

const List<ui.Color> _carBodies = [kVeil, kText, kSignal, kEssence, ui.Color(0xFF6C7FB8), kDim];
const List<ui.Color> _tops = [kVeil, kSignal, kEssence, kText, ui.Color(0xFF6C7FB8)];
const List<ui.Color> _hair = [ui.Color(0xFF3A2A2A), ui.Color(0xFF6B4A2F), ui.Color(0xFFD8B45A), ui.Color(0xFF2A2236), ui.Color(0xFF8A3B3B)];
const List<ui.Color> _skin = [ui.Color(0xFFF0C9A6), ui.Color(0xFFD9A47C), ui.Color(0xFFA8714C), ui.Color(0xFF7A4E34)];
const ui.Color _glass = ui.Color(0xFFBFE9F0);
const ui.Color _lamp = ui.Color(0xFFFFE8A3);
const ui.Color _tire = ui.Color(0xFF3A2F4A);

ui.Color _shade(ui.Color c, double t) => ui.Color.lerp(c, kOutline, t)!;

/// As cores de cada papel para o modelo [m] e a paleta [p] (de 0 a `paletteCount - 1`).
Map<String, ui.Color> paletteOf(GhostModel m, int p) {
  final i = p % m.paletteCount;
  if (m.kind == GhostKind.car) {
    final body = _carBodies[i];
    return {'o': kOutline, 'b': body, 'a': _shade(body, 0.3), 'd': _shade(body, 0.5), 'g': _glass, 'y': _lamp, 'k': _tire, 'h': _shade(_tops[(i + 2) % _tops.length], 0.1)};
  }
  final top = _tops[i % _tops.length];
  return {
    'o': kOutline,
    't': top,
    'u': _tops[(i + 2) % _tops.length],
    'p': _shade(const ui.Color(0xFF6C7FB8), 0.35 + 0.1 * (i % 3)),
    'b': top,
    'h': m == GhostModel.elder ? const ui.Color(0xFFCFCFD8) : (m == GhostModel.cyclist ? _tops[(i + 1) % _tops.length] : _hair[i % _hair.length]),
    's': _skin[i % _skin.length],
    'k': _tire,
    'n': const ui.Color(0xFFA9824F),
  };
}

/// Guarda uma `Picture` por (modelo, paleta, quadro), gravada com 1 unidade por pixel de arte.
class GhostSprites {
  final Map<int, ui.Picture> _pictures = {};

  /// Colunas e linhas da matriz do modelo.
  (int, int) sizeOf(GhostModel m) {
    final rows = spriteRows(m, 0);
    return (rows.first.length, rows.length);
  }

  ui.Picture picture(GhostModel m, int palette, int frame) {
    final f = frame % framesOf(m);
    final key = (m.index * 8 + palette % m.paletteCount) * 2 + f;
    return _pictures[key] ??= _record(m, palette, f);
  }

  ui.Picture _record(GhostModel m, int palette, int frame) {
    final colors = paletteOf(m, palette);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final paint = ui.Paint()..isAntiAlias = false;
    final rows = spriteRows(m, frame);
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final c = colors[row[x]];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    return rec.endRecording();
  }
}
