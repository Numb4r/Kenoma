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
final SpriteRows _suv = _car(16, 8, cabin0: 3, cabin1: 12);

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

/// O guarda-chuva aberto por cima da cabeça (`w` pano, `W` borda, `r` cabo).
const SpriteRows _umbrella = ['..ooo..', '.owwwo.', 'owwwwwo', 'oWoWoWo', '...r...'];

/// O corpo do adulto com a roupa [o]: o acessório troca pixels da cabeça e do tronco (`c` boné ou chapéu, `e` gorro,
/// `f` cachecol, `m` máscara) e o guarda-chuva cresce [_umbrella] por cima. As cores vêm de [paletteOf].
SpriteRows _dressed(GhostOutfit o) {
  final r = [..._adultTop];
  switch (o) {
    case GhostOutfit.beanie:
      r[0] = '..oeo..';
      r[1] = '.oeeeo.';
    case GhostOutfit.cap:
      r[0] = '..occ..';
      r[1] = '.occccc';
    case GhostOutfit.hat:
      r[0] = '..ccc..';
      r[1] = 'ccccccc';
    case GhostOutfit.scarf:
      r[3] = '.offfo.';
      r[4] = '.oftto.';
    case GhostOutfit.mask:
      r[2] = '.ommmo.';
    case GhostOutfit.light:
      r[5] = r[6] = 'ostttso'; // braços de fora
    case GhostOutfit.raincoat:
      r[0] = '..ttt..'; // o capuz, da cor da capa
      r[1] = '.ottto.';
    case GhostOutfit.umbrella || GhostOutfit.coat || GhostOutfit.none:
      break;
  }
  return o == GhostOutfit.umbrella ? [..._umbrella, ...r] : r;
}

SpriteRows _adult(int frame, [GhostOutfit o = GhostOutfit.none]) => [..._dressed(o), ...(frame == 0 ? _adultLegsA : _adultLegsB)];

SpriteRows _pair(int frame, [GhostOutfit o = GhostOutfit.none]) {
  final adult = _adult(frame, o);
  final child = [..._childTop, ...(frame == 0 ? _childLegsA : _childLegsB)];
  final pad = adult.length - child.length;
  return [
    for (var i = 0; i < adult.length; i++) '${adult[i]}.${i < pad ? '.....' : child[i - pad]}',
  ];
}

SpriteRows _elder(int frame, [GhostOutfit o = GhostOutfit.none]) {
  final a = _adult(frame, o);
  final top = o == GhostOutfit.umbrella ? _umbrella.length : 0;
  return [
    for (var i = 0; i < a.length; i++)
      // cabeça e ombros inclinados um pixel à frente (esquerda), bengala na direita
      '${i < top + 5 ? '${a[i].substring(1)}.' : a[i]}${i >= top + 5 ? 'n' : '.'}',
  ];
}

/// As linhas do sprite de [m] no [frame] (0 ou 1; só os passantes de pé têm dois quadros), com a roupa [o] do clima (só
/// nos passantes de pé; ciclistas e carros ficam como estão).
SpriteRows spriteRows(GhostModel m, int frame, [GhostOutfit o = GhostOutfit.none]) => switch (m) {
      GhostModel.hatch => _hatch,
      GhostModel.sedan => _sedan,
      GhostModel.pickup => _pickup,
      GhostModel.moto => _moto,
      GhostModel.cyclist => _cyclist,
      GhostModel.adult => _adult(frame, o),
      GhostModel.childPair => _pair(frame, o),
      GhostModel.elder => _elder(frame, o),
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

const List<ui.Color> _umbrellas = [kVeil, kSignal, kEssence, ui.Color(0xFF6C7FB8), ui.Color(0xFF8A3B3B), kText];
const List<ui.Color> _raincoats = [ui.Color(0xFFE8C14A), ui.Color(0xFF5FA8D3), ui.Color(0xFFE8E4F4)];
const List<ui.Color> _coats = [ui.Color(0xFF6B4A2F), ui.Color(0xFF4A4458), ui.Color(0xFF7A3B4A), ui.Color(0xFF3F4A6C)];
const List<ui.Color> _knits = [ui.Color(0xFFB8484A), kEssence, kSignal, ui.Color(0xFFE8C14A), kVeil];
const List<ui.Color> _caps = [ui.Color(0xFFE8E4F4), ui.Color(0xFFD8B45A), ui.Color(0xFF6C7FB8), kEssence];

/// As cores de cada papel para o modelo [m], a paleta [p] (de 0 a `paletteCount - 1`) e a roupa [o] do clima: a capa e o
/// casaco trocam a blusa, a roupa leve a clareia; o guarda-chuva, o gorro e o boné variam de cor com a paleta.
Map<String, ui.Color> paletteOf(GhostModel m, int p, [GhostOutfit o = GhostOutfit.none]) {
  final base = _paletteOf(m, p);
  if (o == GhostOutfit.none || m.kind == GhostKind.car) return base;
  final i = p % m.paletteCount;
  final umbrella = _umbrellas[i % _umbrellas.length];
  return {
    ...base,
    if (o == GhostOutfit.raincoat) 't': _raincoats[i % _raincoats.length],
    if (o == GhostOutfit.coat) ...{'t': _coats[i % _coats.length], 'p': _shade(_coats[(i + 1) % _coats.length], 0.4)},
    if (o == GhostOutfit.light) 't': ui.Color.lerp(base['t'], const ui.Color(0xFFFFFFFF), 0.45)!,
    'w': umbrella,
    'W': _shade(umbrella, 0.35),
    'r': const ui.Color(0xFF8A8FA3),
    'c': _caps[i % _caps.length],
    'e': _knits[i % _knits.length],
    'f': _knits[(i + 2) % _knits.length],
    'm': const ui.Color(0xFFE8E4F4),
  };
}

Map<String, ui.Color> _paletteOf(GhostModel m, int p) {
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

/// Barco e canoa fantasmas (Dilúvio), vistos de cima e de frente para a direita, como os carros: o carro da rua alagada
/// vira barco, a moto vira canoa. `h` é quem rema.
const SpriteRows boatRows = [
  '..oooooooooo....',
  '.obbbbbbbbbbooo.',
  'obbaaaabbbbbbbbo',
  'obbaggabbbbhbbbo',
  'obbaaaabbbbbbbbo',
  '.obbbbbbbbbbooo.',
  '..oooooooooo....',
];
const SpriteRows canoeRows = [
  '...oooooooo...',
  '.oobbbbbbbboo.',
  'obbbbhbbbhbbbo',
  '.oobbbbbbbboo.',
  '...oooooooo...',
];

/// As linhas do carro da corrida: `hatch`, `sedan` ou `suv`. Sem logo nem marca.
SpriteRows rideCarRows(String type) => switch (type) { 'sedan' => _sedan, 'suv' => _suv, _ => _hatch };

/// As cores do carro da corrida, com o corpo em [body].
Map<String, ui.Color> rideCarPalette(ui.Color body) => {'o': kOutline, 'b': body, 'a': _shade(body, 0.3), 'd': _shade(body, 0.5), 'g': _glass, 'y': _lamp, 'k': _tire};

/// Grava [rows] com [colors], 1 unidade por pixel de arte.
ui.Picture recordSprite(SpriteRows rows, Map<String, ui.Color> colors) {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  final paint = ui.Paint()..isAntiAlias = false;
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

/// Guarda uma `Picture` por (modelo, paleta, quadro), gravada com 1 unidade por pixel de arte.
class GhostSprites {
  final Map<int, ui.Picture> _pictures = {};

  /// Colunas e linhas da matriz do modelo.
  /// Com a roupa [o], o guarda-chuva deixa o passante mais alto.
  (int, int) sizeOf(GhostModel m, [GhostOutfit o = GhostOutfit.none]) {
    final rows = spriteRows(m, 0, o);
    return (rows.first.length, rows.length);
  }

  ui.Picture picture(GhostModel m, int palette, int frame, [GhostOutfit o = GhostOutfit.none]) {
    final f = frame % framesOf(m);
    final key = ((m.index * 8 + palette % m.paletteCount) * 2 + f) * 16 + o.index;
    return _pictures[key] ??= recordSprite(spriteRows(m, f, o), paletteOf(m, palette, o));
  }

  final Map<int, ui.Picture> _boats = {};

  /// O barco (ou a canoa) que o carro [m] vira na rua alagada, com a paleta dele.
  ui.Picture boat(GhostModel m, int palette) => _boats[m.index * 8 + palette % m.paletteCount] ??= recordSprite(boatRowsOf(m), paletteOf(m, palette));
}

/// A moto vira canoa; os outros carros, barco.
SpriteRows boatRowsOf(GhostModel m) => m == GhostModel.moto ? canoeRows : boatRows;
