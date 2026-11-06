// Consulta, codec e UTM do fallback. Os vetores de UTM vieram do pyproj 3.7.2 (pipeline/.venv), EPSG:31982, 31983 e 31984.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/fallback/block_builder.dart';
import 'package:kenoma/world/fallback/block_codec.dart';
import 'package:kenoma/world/fallback/geos_buffer.dart';
import 'package:kenoma/world/fallback/osm_area.dart';
import 'package:kenoma/world/fallback/utm.dart';

void main() {
  final rules = OsmRules.fromJson(jsonDecode(File('assets/data/biomes.json').readAsStringSync()) as Map<String, dynamic>);

  group('overpassQuery', () {
    final q = overpassQuery(tx: 12100, ty: 18526, dateIso: '2026-10-16T19:40:00Z', rules: rules);

    test('fixa a data e o formato', () {
      expect(q, startsWith('[out:json][timeout:60][date:"2026-10-16T19:40:00Z"];'));
    });

    test('pede as tags das regras e as ruas', () {
      expect(q, contains('way["highway"~"^('));
      expect(q, contains('footway'));
      expect(q, contains('rel["landuse"~"^('));
      expect(q, contains('"type"~"^(multipolygon|boundary)\$"'));
    });

    test('usa as caixas das fixtures', () {
      final dir = Directory('test/fixtures/fallback');
      for (final file in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json.gz'))) {
        final parts = file.uri.pathSegments.last.replaceAll('.json.gz', '').split('_');
        final doc = jsonDecode(utf8.decode(gzip.decode(file.readAsBytesSync()))) as Map<String, dynamic>;
        final query = overpassQuery(tx: int.parse(parts[0]), ty: int.parse(parts[1]), dateIso: 'x', rules: rules);
        for (final box in doc['query_boxes'] as List) {
          final b = (box as List).cast<num>().map((v) => v.toStringAsFixed(7)).toList();
          expect(query, contains('(${b[1]},${b[0]},${b[3]},${b[2]})'));
        }
      }
    });
  });

  test('encode e decode vão e voltam', () {
    final cells = Uint8List(blockCells * blockCells);
    for (var i = 0; i < cells.length; i++) {
      cells[i] = i % 5;
    }
    final block = FallbackBlock(
      tx: 12100,
      ty: 18526,
      epochId: 4,
      cells: cells,
      visual: VisualTile(
        lines: [
          VisualLine(RoadClass.principal, Int32List.fromList([-40, 3, 4100, 90]), oneway: OneWay.forward, name: 'Avenida Norte-Sul'),
          VisualLine(RoadClass.pedestrian, Int32List.fromList([1, 2, 3, 4])),
        ],
        areas: [
          VisualArea(AreaKind.water, [Int32List.fromList([0, 0, 10, 0, 10, 10]), Int32List.fromList([2, 2, 3, 2, 3, 3])]),
        ],
      ),
      noWalk: [774400.25, 1185664.5, 774401.125, 1185665.0],
    );
    final bytes = encodeBlock(block);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'FBK1');
    final back = decodeBlock(bytes);
    expect((back.tx, back.ty, back.epochId), (12100, 18526, 4));
    expect(back.cells, cells);
    expect(back.noWalk, block.noWalk);
    expect(back.visual.lines.length, 2);
    expect(back.visual.lines[0].xy, block.visual.lines[0].xy);
    expect(back.visual.lines[0].name, 'Avenida Norte-Sul');
    expect(back.visual.lines[0].oneway, OneWay.forward);
    expect(back.visual.lines[1].name, isNull);
    expect(back.visual.areas[0].kind, AreaKind.water);
    expect(back.visual.areas[0].rings[1], block.visual.areas[0].rings[1]);
    expect(() => decodeBlock(Uint8List(30)), throwsFormatException);
  });

  test('UTM contra o pyproj, ida e volta', () {
    for (final (zone, south, lon, lat, e, n) in _utmVectors) {
      final utm = Utm.zone(zone, south: south);
      final (x, y) = utm.forward(lon, lat);
      expect(x, closeTo(e, 1e-6));
      expect(y, closeTo(n, 1e-6));
      final (lo, la) = utm.inverse(e, n);
      expect(lo, closeTo(lon, 1e-10));
      expect(la, closeTo(lat, 1e-10));
    }
    expect(Utm.zoneOf(-47.06), 23);
    expect(Utm.zoneOf(-46.6), 23);
    expect(Utm.zoneOf(-49.0), 22);
  });

  group('montagem de área', () {
    List<AreaSegment> square(int x, int y, int s) {
      final segs = <AreaSegment>[];
      addSegments(segs, [x, y, x + s, y, x + s, y + s, x, y + s, x, y]);
      return segs;
    }

    test('anel simples passa e dá um anel', () {
      final a = assembleArea(square(0, 0, 10))!;
      expect(ringsOf(a).single.length, 4);
    });

    test('anel aberto é recusado', () {
      final segs = <AreaSegment>[];
      addSegments(segs, [0, 0, 10, 0, 10, 10]);
      expect(assembleArea(segs), isNull);
    });

    test('auto-interseção é recusada', () {
      final segs = <AreaSegment>[];
      addSegments(segs, [0, 0, 10, 10, 10, 0, 0, 10, 0, 0]);
      expect(assembleArea(segs), isNull);
    });

    test('segmento duplicado cancela o par', () {
      // Dois quadrados colados pela aresta x=10: a aresta comum some e sobra um anel só.
      final a = assembleArea([...square(0, 0, 10), ...square(10, 0, 10)])!;
      expect(a.length, 6);
    });
  });

  test('curva de offset de um segmento reto tem 2 x (16 x 2 + 1) vértices e fecha', () {
    final curve = bufferCurves(const [Pt(0, 0), Pt(100, 0)], 14).single;
    expect(curve.interiorRight, isTrue);
    expect(curve.pts.first.same(curve.pts.last), isTrue);
    expect(curve.pts.length, 2 * (2 * 16 + 1) + 1);
  });
}

// (zona, sul, lon, lat, leste, norte)
const List<(int, bool, double, double, double, double)> _utmVectors = [
  (23, true, -47.0608, -22.9056, 288627.506500735, 7465450.273723103),
  (23, true, -47.25, -23.1, 269545.4912667201, 7443634.26198498),
  (23, true, -46.85, -22.72, 309997.05989038554, 7486290.587616598),
  (23, true, -46.36, -24.01, 361674.8811460419, 7343998.245656978),
  (23, true, -44.1, -20.0, 594147.6909484768, 7788265.776418751),
  (22, true, -49.27, -25.43, 673978.126701871, 7186309.486385411),
  (23, true, -43.2, -22.9, 684623.6732650576, 7466421.400747576),
  (24, true, -38.5, -12.97, 554227.8093892429, 8566128.754354764),
];
