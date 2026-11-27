import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// 0.26.2: o APK leva uma folha por família (`scripts/pack_creature_atlas.py`), não as pastas soltas. A folha é a das
/// pastas de agora (o SHA-256 das fontes bate) e tem um retângulo para cada PNG de cada criatura do índice.
void main() {
  const art = 'assets/art/creatures';
  final index = (jsonDecode(File('$art/index.json').readAsStringSync()) as Map<String, dynamic>)['species'] as Map<String, dynamic>;
  final byFamily = <String, Set<String>>{};
  for (final e in index.entries) {
    byFamily.putIfAbsent(e.key.split('.').first, () => {}).add((e.value as Map<String, dynamic>)['folder'] as String);
  }

  for (final MapEntry(key: family, value: folders) in byFamily.entries) {
    test('a folha de $family está em dia com as pastas e cobre todos os PNGs', () {
      final json = File('$art/atlas/$family.json');
      expect(json.existsSync() && File('$art/atlas/$family.png').existsSync(), isTrue, reason: 'rode scripts/pack_creature_atlas.py');
      final atlas = jsonDecode(json.readAsStringSync()) as Map<String, dynamic>;
      // O mesmo SHA do script: cada PNG e JSON das pastas, em ordem, com o caminho relativo antes dos bytes.
      final bytes = <int>[];
      for (final folder in folders.toList()..sort()) {
        final files = Directory('$art/$folder').listSync().whereType<File>().where((f) => f.path.endsWith('.png') || f.path.endsWith('.json')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final f in files) {
          bytes
            ..addAll(utf8.encode('$folder/${f.uri.pathSegments.last}\n'))
            ..addAll(f.readAsBytesSync());
        }
      }
      expect(atlas['source_sha256'], sha256.convert(bytes).toString(), reason: 'folha velha: rode scripts/pack_creature_atlas.py');
      final inAtlas = atlas['folders'] as Map<String, dynamic>;
      for (final folder in folders) {
        final rects = (inAtlas[folder] as Map<String, dynamic>)['rects'] as Map<String, dynamic>;
        final pngs = Directory('$art/$folder').listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).toSet();
        expect(rects.keys.toSet(), pngs, reason: folder);
      }
    });
  }
}
