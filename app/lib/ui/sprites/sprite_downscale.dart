/// Redesenha um sprite 48 × 48 numa grade menor, em pixels (docs/GDD.md, "Direção de arte, Câmera"): com o pixel de arte
/// do mapa em 2 dp, um Eco de 9 m cabe em 20 pixels e o Conjurador de 8 m em 18. Cada pixel novo vira o caractere que
/// mais aparece no bloco que ele cobre, nunca uma mistura de cores (nada de filtro). As costuras violeta (`v`) e o
/// brilho (`u`) têm prioridade: são a identidade das criaturas e sumiriam na votação. Dart puro.
library;

import 'dart:math' as math;

/// Os caracteres que valem como identidade nos Ecos (costuras e brilho) e ganham a votação se aparecerem no bloco.
const String ecoIdentity = 'vu';

/// A matriz [rows] reduzida para [target] × [target]. `.` é transparente. Os caracteres de [keep] ganham a votação
/// se aparecerem no bloco (nos Ecos, as costuras; no Conjurador, o ciano dos olhos e da tela).
List<String> downscaleRows(List<String> rows, int target, {String keep = 'vu'}) {
  final n = rows.length;
  assert(n > 0 && rows.every((r) => r.length == n), 'o sprite de origem tem de ser quadrado');
  assert(target > 0 && target <= n, 'a grade nova não pode ser maior que a de origem');
  final out = <String>[];
  for (var ty = 0; ty < target; ty++) {
    final y0 = (ty * n / target).floor(), y1 = math.max(y0 + 1, ((ty + 1) * n / target).ceil());
    final line = StringBuffer();
    for (var tx = 0; tx < target; tx++) {
      final x0 = (tx * n / target).floor(), x1 = math.max(x0 + 1, ((tx + 1) * n / target).ceil());
      final counts = <String, int>{};
      var solid = 0, total = 0;
      for (var y = y0; y < math.min(y1, n); y++) {
        for (var x = x0; x < math.min(x1, n); x++) {
          final c = rows[y][x];
          total++;
          if (c == '.') continue;
          solid++;
          counts[c] = (counts[c] ?? 0) + 1;
        }
      }
      if (solid == 0 || solid * 2 < total) {
        line.write('.'); // menos da metade do bloco: fica transparente, para a silhueta não engordar
        continue;
      }
      final seam = [for (final c in keep.split('')) if (counts.containsKey(c)) c];
      if (seam.isNotEmpty) {
        line.write(seam.first);
        continue;
      }
      var best = counts.entries.first;
      for (final e in counts.entries) {
        if (e.value > best.value) best = e;
      }
      line.write(best.key);
    }
    out.add(line.toString());
  }
  return out;
}

/// O tamanho de um sprite de [srcPx] pixels na tela, em dp: o mais perto de [sizeDp] que é um múltiplo inteiro de
/// pixels **físicos** por pixel do sprite. Assim todo pixel do sprite tem o mesmo tamanho, sem filtro nem pixel
/// mais gordo que o vizinho.
double snapSpriteSize(double sizeDp, double dpr, int srcPx) {
  final k = math.max(1, (sizeDp * dpr / srcPx).round());
  return k * srcPx / dpr;
}
