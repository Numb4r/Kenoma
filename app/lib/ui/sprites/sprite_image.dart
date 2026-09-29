/// Converte as matrizes de caracteres de `sprite_data.dart` em imagem e em PNG.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'sprite_data.dart';

const int spriteSize = 48;

/// Cores das costuras na versão "acesa", para pulsar sobre a versão normal.
const int _seamBright = 0xFFD8CCFF;
const int _glowBright = 0xFFB59CFF;

/// Pixels RGBA da matriz. Com [brightSeams], as costuras e o brilho ficam mais claros.
Uint8List spritePixels(List<String> rows, {bool brightSeams = false}) {
  assert(rows.length == spriteSize && rows.every((r) => r.length == spriteSize), 'sprite deve ser 48 x 48');
  final bytes = Uint8List(spriteSize * spriteSize * 4);
  for (var y = 0; y < spriteSize; y++) {
    for (var x = 0; x < spriteSize; x++) {
      final ch = rows[y][x];
      if (ch == '.') continue;
      var argb = spritePalette[ch] ?? (throw StateError('Caractere sem cor no sprite: "$ch"'));
      if (brightSeams && ch == 'v') argb = _seamBright;
      if (brightSeams && ch == 'u') argb = _glowBright;
      final i = (y * spriteSize + x) * 4;
      bytes[i] = (argb >> 16) & 0xff;
      bytes[i + 1] = (argb >> 8) & 0xff;
      bytes[i + 2] = argb & 0xff;
      bytes[i + 3] = (argb >> 24) & 0xff;
    }
  }
  return bytes;
}

Future<ui.Image> spriteToImage(List<String> rows, {bool brightSeams = false}) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    spritePixels(rows, brightSeams: brightSeams),
    spriteSize,
    spriteSize,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

/// PNG da matriz, em 48 x 48.
Future<Uint8List> spriteToPng(List<String> rows) async {
  final image = await spriteToImage(rows);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Sprite de um Eco em duas versões: normal e com as costuras acesas.
class EcoSprite {
  const EcoSprite(this.normal, this.bright);

  final ui.Image normal;
  final ui.Image bright;

  static Future<EcoSprite> load(String speciesId) =>
      _from(ecoSprites[speciesId] ?? (throw StateError('Sem sprite para $speciesId')));

  /// Silhueta neutra, para o modo de tipo oculto.
  static Future<EcoSprite> loadNeutral() => _from(neutralSprite);

  static Future<EcoSprite> _from(List<String> rows) async =>
      EcoSprite(await spriteToImage(rows), await spriteToImage(rows, brightSeams: true));
}
