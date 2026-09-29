import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` roda com o diretório de trabalho em app/.
  test('assets/data/biomes.json é cópia exata de shared/biomes.json', () {
    final shared = File('../shared/biomes.json').readAsBytesSync();
    final copy = File('assets/data/biomes.json').readAsBytesSync();
    expect(copy, shared,
        reason: 'Rode scripts/sync_shared.sh depois de editar shared/biomes.json');
  });
}
