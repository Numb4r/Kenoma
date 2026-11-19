import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/spawn_painter.dart' show castsGroundShadow;

/// O Shade não ganha a sombra oval no chão: a sombra-assinatura dele vem desenhada no sprite.
void main() {
  test('só a família Shade fica sem a sombra no chão', () {
    for (final id in ['shade.eco', 'shade.spirit', 'shade.major', 'shade.archetype']) {
      expect(castsGroundShadow(id), isFalse, reason: id);
    }
    for (final id in ['soot.eco', 'hum.spirit', 'frond.major', 'wisp.eco']) {
      expect(castsGroundShadow(id), isTrue, reason: id);
    }
  });
}
