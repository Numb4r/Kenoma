import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A régua das criaturas (docs/art/estilo-criaturas.md, "A régua em números") na arte final de toda espécie e das
/// Fagulhas refeitas. A medida e os pisos moram num lugar só, `tools/art/creatures/regua.py`; o teste roda o script e
/// falha com o que ficou abaixo do piso. Precisa de `python3` com Pillow (o mesmo da pipeline).
void main() {
  test('toda criatura e Fagulha com arte final passa no piso da régua', () async {
    final r = await Process.run('python3', ['../tools/art/creatures/regua.py']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });
}
