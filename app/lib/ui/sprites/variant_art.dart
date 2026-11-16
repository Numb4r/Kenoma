/// A arte das variantes: cada uma muda o VALOR do corpo e ganha um ACESSÓRIO, para ser reconhecida no tamanho do mapa
/// mesmo em escala de cinza. Substitui o tom por cima da silhueta (`srcATop`). Dart puro.
///
/// | Variante      | Valor do corpo                       | Acessório (onde)                                   | Por que se lê em cinza                                   |
/// |---------------|--------------------------------------|----------------------------------------------------|----------------------------------------------------------|
/// | `urban`       | cinza (80% sem cor) e 38% mais escuro | abafadores claros de 4 células, um de cada LADO, na altura dos olhos | corpo cinza médio com dois blocos claros nos flancos     |
/// | `green`       | 42% mais escuro (mata fechada)       | broto claro de duas folhas no TOPO, ao centro; pintas claras esparsas, fora do rosto | corpo escuro salpicado de claro, haste com V em cima     |
/// | `water`       | 38% mais claro                       | duas faixas escuras de maré no corpo; dois pingos EMBAIXO | corpo claro cortado por duas listras escuras horizontais |
/// | `residential` | 25% mais claro (quente)              | telhado escuro de cerâmica, largo, no TOPO         | triângulo escuro cobrindo a cabeça de um corpo claro     |
/// | `lit`         | 48% mais claro (o mais claro, ainda com sombra interna) | tubo de neon de 2 px (1 no mapa) por FORA do contorno escuro, nunca em buraco interno, mais o halo de [variantGlowRows] | o corpo mais claro de todos, com um segundo contorno claro por fora do escuro |
/// | `sacred`      | 38% mais escuro (cinza violeta)      | auréola clara FLUTUANDO acima da cabeça; véu claro no quarto de cima do corpo | corpo escuro com o alto claro e uma barra solta em cima  |
/// | `crimson`     | 58% mais escuro (o mais escuro)      | dois chifres claros nas PONTAS do topo             | o corpo mais escuro de todos, com duas pontas claras     |
/// | `shiny`       | 18% mais claro                       | estrela branca de quatro pontas no CANTO de cima à direita; risco de brilho branco com fio escuro em diagonal | diagonal branca e escura que nenhuma outra tem; é a única que pulsa ([shinyPulse]) |
///
/// Cada acessório mora num lugar diferente da silhueta (lados, topo ao centro, base, topo largo, contorno, flutuando,
/// pontas, canto), então duas variantes não se confundem nem quando o valor fica parecido. A posição sai das linhas
/// (caixa do corpo, perfil de cima e de baixo, linha dos olhos), nunca de coordenada fixa.
///
/// Caracteres novos: `A` acessório, `H` acessório ou padrão claro, `K` acessório ou padrão escuro, `W` brilho branco,
/// `N` neon. Nenhum existe em `spritePalette` nem na paleta provisória. Ao reduzir para o mapa, passe
/// `keep: ecoIdentity + variantIdentity` a `downscaleRows`, senão o acessório some na votação. O neon entra por
/// maioria, sem prioridade, para não apagar o contorno.
library;

import 'dart:math' as math;

/// Os caracteres das variantes que têm de ganhar a votação de `downscaleRows`.
/// O neon `N` fica de fora de propósito: com prioridade ele comia o contorno escuro e a Iluminada virava um borrão.
const String variantIdentity = 'AHKW';

/// Caracteres cuja cor não muda com a variante: contorno, costura, brilho do Véu, olhos e os das próprias variantes.
const Set<String> _fixed = {'O', 'v', 'u', 'E', 'x', 'A', 'H', 'K', 'W', 'N'};

const String _marks = 'AHKW';

class _Look {
  const _Look(this.toward, this.k, {this.a = 0xFFC9CDD8, this.h = 0xFFF0EEF8, this.dark = 0xFF8A8FA3, this.desat = 0});

  /// O corpo é misturado com [toward] na força [k], depois de perder [desat] da cor.
  final int toward;
  final double k, desat;

  /// As cores de `A`, `H` e `K`.
  final int a, h, dark;
}

const Map<String, _Look> _looks = {
  'urban': _Look(0xFF2B2F3D, 0.38, desat: 0.8),
  'green': _Look(0xFF14301E, 0.42, a: 0xFF86D37C, h: 0xFFD6F5B0, dark: 0xFF2F6B45),
  'water': _Look(0xFFD6ECFF, 0.38, a: 0xFF9FD0F5, h: 0xFFE8F6FF, dark: 0xFF2D5AA0),
  'residential': _Look(0xFFF2C9A0, 0.25, a: 0xFF8A4A3A, h: 0xFFB8705A, dark: 0xFF5A2E28),
  'lit': _Look(0xFFFFFBE0, 0.48),
  'sacred': _Look(0xFF352C52, 0.38, a: 0xFFE8D9A0, h: 0xFFFFF6D0, dark: 0xFFD9CCFF),
  'crimson': _Look(0xFF4A0F1C, 0.58, a: 0xFFF2C6C0, h: 0xFFFFF0EC, dark: 0xFFB06A70),
  'shiny': _Look(0xFFFFF6D8, 0.18, dark: 0xFF9A7A3A),
};

// Os acessórios, em células: cada caractere vira um bloco de 3 x 3 pixels, como as silhuetas provisórias.
const List<String> _muffLeft = ['HA', 'AA', 'AA', 'AK'];
const List<String> _muffRight = ['AH', 'AA', 'AA', 'KA'];
const List<String> _sprout = ['HH.HH', '.AAA.', '..A..'];
const List<String> _roof = ['....A....', '..AAHAA..', '.AAAAAAA.', 'KKKKKKKKK'];
const List<String> _halo = ['AHHHA'];
const List<String> _hornLeft = ['H.', 'A.', 'AA'];
const List<String> _hornRight = ['.H', '.A', 'AA'];
const List<String> _dripLong = ['A', 'A', 'H'];
const List<String> _dripShort = ['A', 'H'];
const List<String> _star = ['.W.', 'WWW', '.W.'];

bool _solid(String c) => c != '.' && c != 'u';

int _mix(int argb, int toward, double k) {
  int ch(int shift) => (((argb >> shift) & 0xff) + ((((toward >> shift) & 0xff) - ((argb >> shift) & 0xff)) * k)).round();
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

int _desat(int argb, double k) {
  final g = (((argb >> 16) & 0xff) * 299 + ((argb >> 8) & 0xff) * 587 + (argb & 0xff) * 114) ~/ 1000;
  return _mix(argb, (g << 16) | (g << 8) | g, k);
}

/// Tem corpo a até [d] pixels de (x, y)?
bool _near(List<String> rows, int x, int y, int d) {
  for (var j = y - d; j <= y + d; j++) {
    if (j < 0 || j >= rows.length) continue;
    for (var i = x - d; i <= x + d; i++) {
      if (i >= 0 && i < rows[j].length && _solid(rows[j][i])) return true;
    }
  }
  return false;
}

/// As linhas de [rows] (48 x 48, de `phase1Rows` ou de `sprite_data.dart`) com o acessório e os padrões de [variant]
/// (chave de `creatures.json`). Variante desconhecida ou sprite vazio: devolve [rows] sem mexer. Pinte com
/// [variantPalette].
List<String> variantRows(List<String> rows, String variant) {
  if (!_looks.containsKey(variant)) return rows;
  final n = rows.length;
  final g = [for (final row in rows) row.split('')];

  // A caixa do corpo, a faixa da cabeça (as 6 linhas de cima) e a linha dos olhos.
  var l = n, t = n, r = -1, b = -1, eyeSum = 0, eyes = 0;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final c = rows[y][x];
      if (!_solid(c)) continue;
      l = math.min(l, x);
      r = math.max(r, x);
      t = math.min(t, y);
      b = math.max(b, y);
      if (c == 'E' || c == 'x') {
        eyeSum += y;
        eyes++;
      }
    }
  }
  if (r < 0) return rows;
  final w = r - l + 1, h = b - t + 1;
  final eyeY = eyes == 0 ? t + h * 2 ~/ 5 : eyeSum ~/ eyes;

  /// O primeiro e o último pixel de corpo entre as linhas [y0] e [y1], ou a caixa inteira se não houver.
  (int, int) span(int y0, int y1) {
    var a = n, z = -1;
    for (var y = math.max(0, y0); y <= math.min(n - 1, y1); y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (!_solid(rows[y][x])) continue;
        a = math.min(a, x);
        z = math.max(z, x);
      }
    }
    return z < 0 ? (l, r) : (a, z);
  }

  int top(int x) {
    for (var y = 0; y < n; y++) {
      if (_solid(rows[y][x])) return y;
    }
    return t;
  }

  int bottom(int x) {
    for (var y = n - 1; y >= 0; y--) {
      if (_solid(rows[y][x])) return y;
    }
    return b;
  }

  /// Carimba [cells] com o canto em (x0, y0), preso dentro do sprite.
  void stamp(List<String> cells, int x0, int y0) {
    final sx = math.max(0, math.min(x0, n - cells.first.length * 3)), sy = math.max(0, math.min(y0, n - cells.length * 3));
    for (var cy = 0; cy < cells.length; cy++) {
      for (var cx = 0; cx < cells[cy].length; cx++) {
        final c = cells[cy][cx];
        if (c == '.') continue;
        for (var i = 0; i < 9; i++) {
          final x = sx + cx * 3 + i % 3, y = sy + cy * 3 + i ~/ 3;
          if (y < n && x < g[y].length) g[y][x] = c;
        }
      }
    }
  }

  final (headL, headR) = span(t, t + 5);
  final headX = (headL + headR) ~/ 2;

  switch (variant) {
    case 'urban': // abafadores: metade para fora do corpo, metade para dentro
      final (el, er) = span(eyeY - 4, eyeY + 4);
      stamp(_muffLeft, el - 3, eyeY - 6);
      stamp(_muffRight, er - 2, eyeY - 6);
    case 'green': // a haste entra 2 px no topo
      stamp(_sprout, headX - 7, top(headX) + 2 - 9);
    case 'residential': // o beiral cobre os 3 px de cima
      stamp(_roof, headX - 13, t + 3 - 12);
    case 'sacred': // 2 px de ar entre a auréola e a cabeça
      stamp(_halo, headX - 7, t - 6);
    case 'crimson':
      final xl = l + w * 2 ~/ 9, xr = l + w * 7 ~/ 9;
      stamp(_hornLeft, xl - 3, top(xl) + 2 - 9);
      stamp(_hornRight, xr - 2, top(xr) + 2 - 9);
    case 'water': // os pingos saem da borda de baixo
      final xa = l + w * 3 ~/ 10, xb = l + w * 7 ~/ 10;
      stamp(_dripLong, xa - 1, bottom(xa) - 1);
      stamp(_dripShort, xb - 1, bottom(xb) - 1);
    case 'shiny':
      stamp(_star, r - 6, t - 3);
  }

  // Contorno de 1 px em volta do acessório, para ele se soltar do corpo e do chão. Costura e olho ficam.
  final marked = [
    for (var y = 0; y < n; y++)
      for (var x = 0; x < g[y].length; x++)
        if (_marks.contains(g[y][x])) (x, y),
  ];
  for (final (x, y) in marked) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (ny < 0 || ny >= n || nx < 0 || nx >= g[ny].length) continue;
      final c = g[ny][nx];
      if (!_marks.contains(c) && c != 'v' && c != 'E' && c != 'x') g[ny][nx] = 'O';
    }
  }

  // Padrões no corpo: só trocam pixel de corpo comum (nunca contorno, costura, olho ou acessório).
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < g[y].length; x++) {
      final c = g[y][x];
      if (!_solid(c) || _fixed.contains(c)) continue;
      final band = (y - t) * 100 ~/ h; // altura dentro do corpo, de 0 (topo) a 99
      switch (variant) {
        case 'green': // pintas de uma célula, esparsas e fora da faixa dos olhos (o rosto tem de sobrar)
          if ((y - eyeY).abs() > 4 && (x ~/ 3 * 3 + y ~/ 3 * 5) % 11 == 0) g[y][x] = 'H';
        case 'water': // duas linhas de maré
          if ((band >= 50 && band < 58) || (band >= 72 && band < 80)) g[y][x] = 'K';
        case 'sacred': // o véu
          if (band < 26) g[y][x] = 'K';
        case 'shiny': // risco de brilho em diagonal: 4 px brancos e 2 px de fio escuro
          final d = (x - l) + (y - t) - (w + h) * 2 ~/ 5;
          if (d >= 0 && d < 4) {
            g[y][x] = 'W';
          } else if (d >= 4 && d < 6) {
            g[y][x] = 'K';
          }
      }
    }
  }

  // O tubo de neon da Iluminada: 2 px por fora do contorno (1 pixel no mapa), só no lado de FORA da silhueta. Buraco
  // interno (a grade do rust.spirit) fica vazio: o lado de fora é o que se alcança a partir da borda do sprite.
  if (variant == 'lit') {
    final outside = [for (final row in rows) List.filled(row.length, false)];
    final queue = <(int, int)>[];
    void visit(int x, int y) {
      if (y < 0 || y >= n || x < 0 || x >= rows[y].length || outside[y][x] || _solid(rows[y][x])) return;
      outside[y][x] = true;
      queue.add((x, y));
    }

    for (var i = 0; i < n; i++) {
      visit(i, 0);
      visit(i, n - 1);
      visit(0, i);
      visit(rows[i].length - 1, i);
    }
    while (queue.isNotEmpty) {
      final (x, y) = queue.removeLast();
      visit(x + 1, y);
      visit(x - 1, y);
      visit(x, y + 1);
      visit(x, y - 1);
    }
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (outside[y][x] && _near(rows, x, y, 2)) g[y][x] = 'N';
      }
    }
  }
  return [for (final row in g) row.join()];
}

/// A paleta de [variant] a partir da paleta comum [base]: o corpo muda de valor (contorno, costura, brilho do Véu e
/// olhos não) e entram as cores de `A`, `H`, `K`, `W` e `N`. Variante desconhecida: devolve [base].
Map<String, int> variantPalette(Map<String, int> base, String variant) {
  final look = _looks[variant];
  if (look == null) return base;
  return {
    for (final e in base.entries) e.key: _fixed.contains(e.key) ? e.value : _mix(_desat(e.value, look.desat), look.toward, look.k),
    'A': look.a,
    'H': look.h,
    'K': look.dark,
    'W': 0xFFFFFFFF,
    'N': 0xFFFFF27A, // amarelo neon: nem violeta do Véu, nem ciano do sinal, nem laranja brasa
  };
}

/// O halo de neon da Iluminada: `N` nos 3 pixels em volta do corpo e `.` no resto (nunca em cima do corpo). Desenhe
/// por baixo do sprite, suave ou aditivo, com a cor `N` de [variantPalette]. `null` nas outras variantes.
List<String>? variantGlowRows(List<String> rows, String variant) {
  if (variant != 'lit') return null;
  return [
    for (var y = 0; y < rows.length; y++)
      [
        for (var x = 0; x < rows[y].length; x++) !_solid(rows[y][x]) && _near(rows, x, y, 3) ? 'N' : '.',
      ].join(),
  ];
}

/// A força do brilho do Brilhante no instante [t] (segundos), de 0 a 1: respira devagar entre 0,1 e 0,4 e solta um
/// lampejo de meio segundo a cada 2,4 s. Só o Brilhante é animado.
double shinyPulse(double t) {
  const period = 2.4, flash = 0.5;
  final s = t % period;
  final breath = 0.25 + 0.15 * math.sin(2 * math.pi * s / period);
  final glint = s < flash ? math.sin(math.pi * s / flash) : 0.0;
  return math.min(1.0, breath + 0.6 * glint); // nunca abaixo de 0,1
}
