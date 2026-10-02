/// Texturas provisórias de pixel art dos biomas, geradas por código: ruído leve de 3 tons (escuro,
/// base e claro, da paleta de `biomes.json`), determinístico por bioma e variante. Arte nunca bloqueia
/// código (CLAUDE.md): quando vier a arte final, o atlas troca e o resto do mapa fica igual.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/biomes.dart';
import '../../core/fnv.dart';
import '../../core/pcg32.dart';

/// Lado de um tile do mapa, em pixels: um tile de 16 px por célula z21 (spec, seção 1).
const int tileSize = 16;

/// Quantas variantes de textura cada bioma tem. A célula escolhe uma por hash, então o mapa não repete
/// um quadriculado.
const int textureVariants = 8;

/// Variante de textura da célula z21 `(x, y)`, fixa para a célula.
int cellVariant(int x, int y) => (fnv1a64Of3(x, y, 0x7e1e) >>> 32) % textureVariants;

/// Como o ruído de cada bioma é desenhado: chance do tom escuro e do claro, e o tamanho do bloco de
/// pixels que muda junto (blocos largos dão listras na água, blocos quadrados dão a cidade).
class _Style {
  const _Style(this.dark, this.light, this.blockW, this.blockH);

  final double dark;
  final double light;
  final int blockW;
  final int blockH;
}

_Style _styleOf(String key) => switch (key) {
      'void' => const _Style(0.10, 0.05, 1, 1),
      'residential' => const _Style(0.14, 0.12, 1, 1),
      'urban' => const _Style(0.18, 0.20, 2, 2),
      'green' => const _Style(0.22, 0.14, 1, 1),
      'water' => const _Style(0.12, 0.20, 4, 1),
      _ => const _Style(0.12, 0.12, 1, 1),
    };

/// Pixels RGBA (16 x 16) da [variant] da textura de [biome]. Só usa os 3 tons da paleta.
Uint8List biomeTexturePixels(BiomeDef biome, int variant) {
  final style = _styleOf(biome.key);
  final rng = Pcg32(fnv1a64([biome.id, variant, 0x7e1e]), saltKenoma);
  final pixels = Uint8List(tileSize * tileSize * 4);
  for (var by = 0; by < tileSize; by += style.blockH) {
    for (var bx = 0; bx < tileSize; bx += style.blockW) {
      final r = rng.nextFloat();
      final tone = r < style.dark ? biome.palette[0] : (r > 1 - style.light ? biome.palette[2] : biome.palette[1]);
      for (var y = by; y < by + style.blockH; y++) {
        for (var x = bx; x < bx + style.blockW; x++) {
          final i = (y * tileSize + x) * 4;
          pixels[i] = (tone >>> 16) & 255;
          pixels[i + 1] = (tone >>> 8) & 255;
          pixels[i + 2] = tone & 255;
          pixels[i + 3] = 255;
        }
      }
    }
  }
  return pixels;
}

/// O atlas de texturas: uma linha por id de bioma (de cima para baixo) e [textureVariants] colunas.
/// O tile do bioma `id` e da variante `v` está em `Rect(v*16, id*16, 16, 16)`.
Future<ui.Image> buildBiomeAtlas(BiomeSet biomes) {
  final defs = biomes.all;
  final rows = defs.last.id + 1;
  final width = tileSize * textureVariants;
  final pixels = Uint8List(width * tileSize * rows * 4);
  for (final b in defs) {
    for (var v = 0; v < textureVariants; v++) {
      final tile = biomeTexturePixels(b, v);
      for (var y = 0; y < tileSize; y++) {
        final dst = ((b.id * tileSize + y) * width + v * tileSize) * 4;
        pixels.setRange(dst, dst + tileSize * 4, tile, y * tileSize * 4);
      }
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, width, tileSize * rows, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}
