import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/map/biome_textures.dart';

import '../support/fixtures.dart';

void main() {
  final biomes = loadBiomes();

  Set<int> tones(List<int> px) => {for (var i = 0; i < px.length; i += 4) (px[i] << 16) | (px[i + 1] << 8) | px[i + 2]};

  test('cada textura tem 16 x 16 pixels opacos e só usa tons da paleta do bioma', () {
    for (final b in biomes.all) {
      for (var v = 0; v < textureVariants; v++) {
        final px = biomeTexturePixels(b, v);
        expect(px.length, 16 * 16 * 4);
        for (var i = 3; i < px.length; i += 4) {
          expect(px[i], 255);
        }
        expect(b.palette.toSet().containsAll(tones(px)), isTrue, reason: '${b.key} v$v');
      }
    }
  });

  test('ruído leve: 2 ou 3 tons por textura, com a cor base dominando', () {
    for (final b in biomes.all) {
      var base = 0, total = 0;
      for (var v = 0; v < textureVariants; v++) {
        final px = biomeTexturePixels(b, v);
        total += 256;
        for (var i = 0; i < px.length; i += 4) {
          if (((px[i] << 16) | (px[i + 1] << 8) | px[i + 2]) == b.palette[1]) base++;
        }
        expect(tones(px).length, inInclusiveRange(1, 3));
      }
      expect(base / total, greaterThan(0.5), reason: '${b.key}: a base domina');
      expect(base / total, lessThan(0.95), reason: '${b.key}: tem ruído suficiente para não parecer planilha');
    }
  });

  test('é determinístico, e as variantes e os biomas são diferentes entre si', () {
    for (final b in biomes.all) {
      expect(biomeTexturePixels(b, 3), biomeTexturePixels(b, 3));
      final variants = {for (var v = 0; v < textureVariants; v++) biomeTexturePixels(b, v).join(',')};
      expect(variants.length, greaterThanOrEqualTo(textureVariants - 1), reason: b.key);
    }
    expect(biomeTexturePixels(biomes.byId(1), 0), isNot(biomeTexturePixels(biomes.byId(2), 0)));
  });

  test('a água é feita de listras horizontais (blocos 4 x 1) e a cidade de blocos 2 x 2', () {
    final water = biomeTexturePixels(biomes.byId(3), 2);
    for (var y = 0; y < 16; y++) {
      for (var bx = 0; bx < 16; bx += 4) {
        final first = water.sublist((y * 16 + bx) * 4, (y * 16 + bx) * 4 + 3);
        for (var x = bx + 1; x < bx + 4; x++) {
          expect(water.sublist((y * 16 + x) * 4, (y * 16 + x) * 4 + 3), first);
        }
      }
    }
    final urban = biomeTexturePixels(biomes.byId(1), 2);
    for (var y = 0; y < 16; y += 2) {
      for (var x = 0; x < 16; x += 2) {
        final a = urban.sublist((y * 16 + x) * 4, (y * 16 + x) * 4 + 3);
        expect(urban.sublist(((y + 1) * 16 + x + 1) * 4, ((y + 1) * 16 + x + 1) * 4 + 3), a);
      }
    }
  });

  test('a variante da célula é fixa para a célula, entre 0 e 7, e espalhada', () {
    expect(cellVariant(773324, 1184541), cellVariant(773324, 1184541));
    final counts = List.filled(textureVariants, 0);
    for (var x = 0; x < 100; x++) {
      for (var y = 0; y < 100; y++) {
        final v = cellVariant(773324 + x, 1184541 + y);
        expect(v, inInclusiveRange(0, textureVariants - 1));
        counts[v]++;
      }
    }
    for (final c in counts) {
      expect(c, greaterThan(10000 / textureVariants * 0.7));
      expect(c, lessThan(10000 / textureVariants * 1.3));
    }
  });

  test('o atlas tem uma linha por id de bioma e uma coluna por variante', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final image = await buildBiomeAtlas(biomes);
    expect((image.width, image.height), (16 * textureVariants, 16 * 5));
    image.dispose();
  });
}
