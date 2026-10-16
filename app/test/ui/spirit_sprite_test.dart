import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/sprites/sprite_data.dart';
import 'package:kenoma/ui/sprites/sprite_downscale.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';

int count(List<String> rows, String ch) => rows.fold(0, (n, r) => n + ch.allMatches(r).length);

void main() {
  test('o Espírito usa o sprite do Eco da família com menos costuras violeta e a mesma silhueta', () {
    for (final f in ['soot', 'frond', 'rill']) {
      final eco = ecoSprites['$f.eco']!, sp = ecoSpriteRows('$f.spirit');
      expect(sp.length, eco.length);
      expect(count(sp, 'v'), lessThan(count(eco, 'v')));
      expect(count(sp, 'v'), greaterThan(0), reason: 'ainda tem costuras');
      for (var y = 0; y < eco.length; y++) {
        for (var x = 0; x < eco.length; x++) {
          expect(sp[y][x] == '.', eco[y][x] == '.', reason: 'a silhueta não muda');
        }
      }
    }
  });

  test('no mapa o Espírito tem 24 pixels (9 m) e o Eco 19 (7 m), sem filtro', () {
    expect(downscaleRows(ecoSpriteRows('soot.spirit'), mapSpiritPx).length, 24);
    expect(downscaleRows(ecoSpriteRows('soot.eco'), mapEcoPx).length, 19);
    expect(mapSpiritPx / mapEcoPx, closeTo(9 / 7, 0.05));
  });
}
