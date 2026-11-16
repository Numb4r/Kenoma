import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/lab_block.dart';

/// O Laboratório visual (0.21.0): a geometria da altura falsa, das paredes e da sombra.
void main() {
  const square = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]; // horário na tela (y para baixo)

  test('o telhado sai do centro da tela: no centro não anda, longe anda mais, e gira junto com o mapa', () {
    expect(roofPoint((80, 60), (80, 60), 14), (80.0, 60.0));
    final near = roofPoint((90, 60), (80, 60), 14), far = roofPoint((140, 60), (80, 60), 14);
    expect(near.$1 - 90, lessThan(far.$1 - 140));
    expect(far.$2, 60.0);
    final up = roofPoint((80, 0), (80, 60), 14);
    expect(up.$2, lessThan(0), reason: 'para cima da tela, o telhado sobe: a direção é a do ponto, não a do norte');
  });

  test('aparecem só as paredes viradas para fora do centro da tela', () {
    expect(isClockwise(square), isTrue);
    const c = (5.0, -50.0); // o centro da tela acima do prédio
    expect(wallVisible((10, 10), (0, 10), c, clockwise: true), isTrue, reason: 'a de baixo, longe do centro');
    expect(wallVisible((0, 0), (10, 0), c, clockwise: true), isFalse, reason: 'a de cima, virada para o centro');
  });

  test('a sombra vai para o lado oposto ao sol, mais longa com o sol baixo, e some à noite', () {
    final morning = shadowOffset(20, 90, 10)!; // sol a leste
    expect(morning.$1, lessThan(0), reason: 'a sombra vai para oeste');
    final low = shadowOffset(5, 90, 10)!, high = shadowOffset(60, 90, 10)!;
    expect(-low.$1, greaterThan(-high.$1));
    expect(-low.$1, lessThanOrEqualTo(30.0001), reason: 'no máximo 3 vezes a altura');
    expect(shadowOffset(-3, 90, 10), isNull);
    final turned = shadowOffset(20, 90, 10, rotationRad: 3.14159265)!;
    expect(turned.$1, greaterThan(0), reason: 'com o mapa virado, a sombra vira junto');
    expect(facesSun((10, 0), (10, 10), morning, clockwise: true), isTrue, reason: 'a parede leste recebe o sol da manhã');
    expect(facesSun((0, 10), (0, 0), morning, clockwise: true), isFalse);
  });

  test('a altura falsa sai do tipo e dos andares, até 32 pixels de arte', () {
    LabBuilding b(String type, {double? levels, bool shop = false}) => LabBuilding(pts: square, type: type, heightM: 6, shop: shop, levels: levels, index: 0);
    expect((b('house').fakeHeightPx, b('church').fakeHeightPx, b('commercial').fakeHeightPx), (5, 16, 8));
    expect(b('apartments', levels: 20).fakeHeightPx, 32);
    expect(b('yes', shop: true).biome, 'lit');
    expect(b('house').biome, 'residential');
  });
}
