// O desenho e o noWalk do bloco não precisam sair iguais byte a byte aos pacotes de Python, mas têm de seguir as mesmas
// regras: mesmo comprimento de rua por classe, mesmos nomes e a mesma água e verde, com a tolerância da simplificação.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/nowalk_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/fallback/block_builder.dart';

double lengthIn(Int32List xy) {
  var sum = 0.0;
  for (var i = 2; i + 1 < xy.length; i += 2) {
    final dx = (xy[i] - xy[i - 2]).toDouble(), dy = (xy[i + 1] - xy[i - 1]).toDouble();
    sum += math.sqrt(dx * dx + dy * dy);
  }
  return sum;
}

Map<RoadClass, double> lengths(VisualTile t) {
  final out = <RoadClass, double>{};
  for (final l in t.lines) {
    out[l.roadClass] = (out[l.roadClass] ?? 0) + lengthIn(l.xy);
  }
  return out;
}

/// Área por tipo dentro do tile, por amostragem numa grade de 128x128 (par/ímpar sobre os anéis da área).
Map<AreaKind, int> coverage(VisualTile t) {
  final out = <AreaKind, int>{};
  for (var row = 0; row < 128; row++) {
    for (var col = 0; col < 128; col++) {
      final x = (col + 0.5) * 4096 / 128, y = (row + 0.5) * 4096 / 128;
      final hit = <AreaKind>{};
      for (final a in t.areas) {
        var inside = false;
        for (final ring in a.rings) {
          final n = ring.length ~/ 2;
          for (var i = 0, j = n - 1; i < n; j = i++) {
            final ax = ring[2 * i], ay = ring[2 * i + 1], bx = ring[2 * j], by = ring[2 * j + 1];
            if ((ay > y) != (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) inside = !inside;
          }
        }
        if (inside) hit.add(a.kind);
      }
      for (final k in hit) {
        out[k] = (out[k] ?? 0) + 1;
      }
    }
  }
  return out;
}

void main() {
  final rules = OsmRules.fromJson(jsonDecode(File('assets/data/biomes.json').readAsStringSync()) as Map<String, dynamic>);
  final pack = VisualPack.parse(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync());
  final noWalk = NoWalkPack.parse(File('assets/regions/campinas_e2_nowalk.bin').readAsBytesSync());
  final fixtures = Directory('test/fixtures/fallback').listSync().whereType<File>().where((f) => f.path.endsWith('.json.gz')).toList();

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last.replaceAll('.json.gz', '');
    final parts = name.split('_');
    final tx = int.parse(parts[0]), ty = int.parse(parts[1]);
    final block = buildBlock(overpassJson: utf8.decode(gzip.decode(file.readAsBytesSync())), tx: tx, ty: ty, epochId: 0, rules: rules);
    final want = pack.decode(tx, ty)!;

    test('$name: ruas do bloco iguais às do pacote visual', () {
      final a = lengths(block.visual), b = lengths(want);
      expect(a.keys.toSet(), b.keys.toSet());
      for (final cls in b.keys) {
        expect(a[cls]! / b[cls]!, closeTo(1, 0.02), reason: '$cls');
      }
      expect({for (final l in block.visual.lines) l.name}, {for (final l in want.lines) l.name});
      double oneway(VisualTile t) => t.lines.where((l) => l.oneway != OneWay.twoWay).fold(0.0, (s, l) => s + lengthIn(l.xy));
      expect(oneway(block.visual), closeTo(oneway(want), 0.02 * oneway(want) + 1));
    });

    test('$name: água e verde iguais aos do pacote visual', () {
      final a = coverage(block.visual), b = coverage(want);
      for (final kind in AreaKind.values) {
        expect((a[kind] ?? 0) - (b[kind] ?? 0), inInclusiveRange(-250, 250), reason: '$kind: bloco ${a[kind]}, pacote ${b[kind]}');
      }
    });

    test('$name: noWalk cobre as mesmas vias', () {
      // Todo segmento do bloco tem de estar a menos de uma célula de um segmento do pacote, e vice-versa dentro do bloco.
      bool near(List<double> segs, double x, double y) {
        for (var i = 0; i + 3 < segs.length; i += 4) {
          final ax = segs[i], ay = segs[i + 1], dx = segs[i + 2] - ax, dy = segs[i + 3] - ay;
          final len2 = dx * dx + dy * dy;
          final t = len2 == 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / len2).clamp(0.0, 1.0);
          final ex = x - (ax + t * dx), ey = y - (ay + t * dy);
          if (ex * ex + ey * ey < 1) return true;
        }
        return false;
      }

      final w = block.noWalk;
      for (var i = 0; i + 3 < w.length; i += 4) {
        final x = (w[i] + w[i + 2]) / 2, y = (w[i + 1] + w[i + 3]) / 2;
        final inBlock = x >= tx * blockCells && x < (tx + 1) * blockCells && y >= ty * blockCells && y < (ty + 1) * blockCells;
        if (inBlock) expect(near(noWalk.near(x ~/ 2, y ~/ 2), x, y), isTrue, reason: '($x, $y)');
      }
      for (var cy = ty * 32; cy < (ty + 1) * 32; cy++) {
        for (var cx = tx * 32; cx < (tx + 1) * 32; cx++) {
          final segs = noWalk.near(cx, cy);
          for (var i = 0; i + 3 < segs.length; i += 4) {
            final x = (segs[i] + segs[i + 2]) / 2, y = (segs[i + 1] + segs[i + 3]) / 2;
            final inner = x >= tx * blockCells + 1 && x < (tx + 1) * blockCells - 1 && y >= ty * blockCells + 1 && y < (ty + 1) * blockCells - 1;
            if (inner) expect(near(w, x, y), isTrue, reason: 'pacote ($x, $y)');
          }
        }
      }
    });
  }

  test('buildBlock roda num Isolate e recusa resposta cortada', () async {
    final file = fixtures.first;
    final parts = file.uri.pathSegments.last.replaceAll('.json.gz', '').split('_');
    final tx = int.parse(parts[0]), ty = int.parse(parts[1]);
    final json = utf8.decode(gzip.decode(file.readAsBytesSync()));
    final block = await Isolate.run(() => buildBlock(overpassJson: json, tx: tx, ty: ty, epochId: 3, rules: rules));
    expect(block.epochId, 3);
    expect(block.biomeAt(tx * blockCells, ty * blockCells), block.cells[0]);
    expect(() => buildBlock(overpassJson: '{"remark":"runtime error: Query timed out","elements":[]}', tx: tx, ty: ty, epochId: 0, rules: rules), throwsFormatException);
  });
}
