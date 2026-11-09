// Oráculo do fallback: `buildBlock` contra o recorte dos pacotes gerados em Python (pipeline/export_fixture.py): oito blocos de Campinas e dois de São Paulo
// engolidos por polígonos maiores que a caixa da consulta.
// A diferença tem de ser zero, célula a célula.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/fallback/block_builder.dart';

String report(int tx, int ty, Uint8List got, Uint8List want) {
  final byBiome = <(int, int), int>{};
  final first = <String>[];
  for (var i = 0; i < want.length; i++) {
    if (got[i] == want[i]) continue;
    final key = (want[i], got[i]);
    byBiome[key] = (byBiome[key] ?? 0) + 1;
    if (first.length < 10) first.add('(${i % blockCells}, ${i ~/ blockCells}) esperado ${want[i]}, veio ${got[i]}');
  }
  final total = byBiome.values.fold(0, (a, b) => a + b);
  final pairs = byBiome.entries.map((e) => 'esperado ${e.key.$1} veio ${e.key.$2}: ${e.value}').join(', ');
  return '${tx}_$ty: $total células diferentes de ${want.length} ($pairs); primeiras: ${first.join('; ')}';
}

void main() {
  final dir = Directory(Platform.environment['FALLBACK_FIXTURES'] ?? 'test/fixtures/fallback');
  final fixtures = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json.gz')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final rules = OsmRules.fromJson(jsonDecode(File('assets/data/biomes.json').readAsStringSync()) as Map<String, dynamic>);

  test('há fixtures', () => expect(fixtures, isNotEmpty));

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last.replaceAll('.json.gz', '');
    final parts = name.split('_');
    final tx = int.parse(parts[0]), ty = int.parse(parts[1]);
    test('bloco $name igual ao pacote', () {
      final json = utf8.decode(gzip.decode(file.readAsBytesSync()));
      final want = File(file.path.replaceAll('.json.gz', '.grid')).readAsBytesSync();
      final watch = Stopwatch()..start();
      final block = buildBlock(overpassJson: json, tx: tx, ty: ty, epochId: 0, rules: rules);
      final ms = watch.elapsedMilliseconds;
      final text = report(tx, ty, block.cells, want);
      // ignore: avoid_print
      print('$text; ${ms}ms; ${block.visual.lines.length} linhas, ${block.visual.areas.length} áreas, ${block.noWalk.length ~/ 4} seg noWalk');
      if (!text.contains(': 0 células')) fail(text);
    });
  }
}
