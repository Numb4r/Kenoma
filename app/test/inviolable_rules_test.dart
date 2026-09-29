import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regras invioláveis 1 e 2 do CLAUDE.md, verificadas no código de lib/core e lib/data:
/// deslocamento sempre lógico (`>>>`), nada de `hashCode` nem `Random` na lógica de mundo.
void main() {
  final sources = [
    for (final dir in ['lib/core', 'lib/data', 'lib/world', 'lib/capture'])
      if (Directory(dir).existsSync())
        ...Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
  ];

  test('há código para verificar', () {
    expect(sources, isNotEmpty);
  });

  test('nenhum deslocamento aritmético (>> com número); só >>>', () {
    // `>>` de genéricos (List<List<int>>) não é seguido por número, então não conta.
    final shift = RegExp(r'(?<!>)>>(?!>|=)\s*[\d(]');
    for (final f in sources) {
      expect(shift.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('nada de hashCode nem dart:math Random', () {
    final banned = RegExp(r'\bhashCode\b|\bRandom\b');
    for (final f in sources) {
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });
}
