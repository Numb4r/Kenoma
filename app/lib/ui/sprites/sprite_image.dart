/// Converte as matrizes de caracteres de `sprite_data.dart` em imagem e em PNG.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/species_ids.dart';
import 'sprite_data.dart';
import 'sprite_downscale.dart';

const int spriteSize = 48;

/// Cores das costuras na versão "acesa", para pulsar sobre a versão normal.
const int _seamBright = 0xFFD8CCFF;
const int _glowBright = 0xFFB59CFF;

/// Pixels RGBA da matriz. Com [brightSeams], as costuras e o brilho ficam mais claros.
Uint8List spritePixels(List<String> rows, {bool brightSeams = false, Map<String, int> palette = spritePalette}) {
  final side = rows.length;
  assert(side > 0 && rows.every((r) => r.length == side), 'sprite deve ser quadrado');
  final bytes = Uint8List(side * side * 4);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final ch = rows[y][x];
      if (ch == '.') continue;
      var argb = palette[ch] ?? (throw StateError('Caractere sem cor no sprite: "$ch"'));
      if (brightSeams && ch == 'v') argb = _seamBright;
      if (brightSeams && ch == 'u') argb = _glowBright;
      final i = (y * side + x) * 4;
      bytes[i] = (argb >> 16) & 0xff;
      bytes[i + 1] = (argb >> 8) & 0xff;
      bytes[i + 2] = argb & 0xff;
      bytes[i + 3] = (argb >> 24) & 0xff;
    }
  }
  return bytes;
}

Future<ui.Image> spriteToImage(List<String> rows, {bool brightSeams = false, Map<String, int> palette = spritePalette}) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    spritePixels(rows, brightSeams: brightSeams, palette: palette),
    rows.length,
    rows.length,
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

/// A matriz do sprite da espécie. Espíritos usam o sprite do Eco da família (visual provisório; a arte final vai para o backlog).
List<String> ecoSpriteRows(String speciesId) {
  final rows = ecoSprites[speciesId] ?? ecoSprites['${speciesId.split('.').first}.eco'] ?? (throw StateError('Sem sprite para $speciesId'));
  return tierOfId(speciesId) == SpeciesTier.spirit && !ecoSprites.containsKey(speciesId) ? spiritRows(rows) : rows;
}

/// O visual provisório do Espírito: o sprite do Eco com menos costuras violeta (só metade dos blocos de 2 x 2 mantém a
/// costura; o resto vira o corpo vizinho). O brilho suave do Véu em volta é desenhado por quem usa o sprite.
List<String> spiritRows(List<String> eco) {
  String at(int x, int y) => y < 0 || y >= eco.length || x < 0 || x >= eco[y].length ? '.' : eco[y][x];
  return [
    for (var y = 0; y < eco.length; y++)
      [
        for (var x = 0; x < eco[y].length; x++)
          if (eco[y][x] != 'v' || (x ~/ 2 + y ~/ 2) % 2 == 0)
            eco[y][x]
          else
            [at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)].firstWhere((c) => !'.vu'.contains(c), orElse: () => 'O'),
      ].join(),
  ];
}

/// Sprite de um Eco em duas versões: normal e com as costuras acesas.
class EcoSprite {
  const EcoSprite(this.normal, this.bright);

  final ui.Image normal;
  final ui.Image bright;

  static Future<EcoSprite> load(String speciesId) => _from(ecoSpriteRows(speciesId));

  /// Silhueta neutra, para o modo de tipo oculto.
  static Future<EcoSprite> loadNeutral() => _from(neutralSprite);

  /// O Eco redesenhado na grade do mapa ([mapEcoPx] pixels de lado), para o mapa de jogo.
  static Future<EcoSprite> loadMap(String speciesId) =>
      _from(downscaleRows(ecoSpriteRows(speciesId), tierOfId(speciesId) == SpeciesTier.spirit ? mapSpiritPx : mapEcoPx));

  static Future<EcoSprite> _from(List<String> rows) async =>
      EcoSprite(await spriteToImage(rows), await spriteToImage(rows, brightSeams: true));
}

/// Lado, em pixels, dos sprites do mapa: Ecos e Conjurador/Familiar. Com o pixel de arte em 2 dp (~0,44 m a 90 m de
/// largura), 20 pixels dão ~9 m e 18 pixels ~8 m.
const int mapEcoPx = 19;
const int mapPlayerPx = 16;

/// O Espírito (9 m, contra 7 m do Eco) é o mesmo sprite ampliado para 24 pixels: 19 × 9 / 7.
const int mapSpiritPx = 24;

/// Os quadros do Conjurador para o mapa, redesenhados em [mapPlayerPx] pixels.
Future<List<ui.Image>> loadPlayerFramesMap() async => [
      await spriteToImage(downscaleRows(playerSprite, mapPlayerPx, keep: 'C'), palette: playerPalette),
      await spriteToImage(downscaleRows(playerStepASprite, mapPlayerPx, keep: 'C'), palette: playerPalette),
      await spriteToImage(downscaleRows(playerStepBSprite, mapPlayerPx, keep: 'C'), palette: playerPalette),
    ];

/// Os quadros do Conjurador: parado e os dois do passo, nesta ordem.
Future<List<ui.Image>> loadPlayerFrames() async => [
      await spriteToImage(playerSprite, palette: playerPalette),
      await spriteToImage(playerStepASprite, palette: playerPalette),
      await spriteToImage(playerStepBSprite, palette: playerPalette),
    ];
