/// Converte as matrizes de caracteres de `sprite_data.dart` em imagem e em PNG.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../core/species_ids.dart';
import 'phase1_sprites.dart';
import 'sprite_data.dart';
import 'sprite_downscale.dart';
import 'variant_art.dart';

const int spriteSize = 48;

/// 0.26.2: o sprite provisório (o gerado por código, a bolha com olhos) só na build de debug (emulador, testes). Na
/// release (e na profile, que mede como ela) toda criatura tem a arte do Aseprite; enquanto ela não carregou, o
/// [EcoSprite] é a silhueta escura (a das não vistas no Bestiário) e o mapa não desenha a criatura. Os testes trocam para
/// conferir a release.
bool provisionalArt = kDebugMode;

/// A cor da silhueta (a `kPanelLine` das células não vistas).
const int kSilhouetteArgb = 0xFF3D3357;

/// A paleta da silhueta de [rows]: todo pixel com cor vira [kSilhouetteArgb].
Map<String, int> _silhouetteOf(List<String> rows) => {for (final r in rows) for (final c in r.split('')) if (c != '.') c: kSilhouetteArgb};

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
      if (brightSeams && ch == 'v' && argb != kSilhouetteArgb) argb = _seamBright;
      if (brightSeams && ch == 'u' && argb != kSilhouetteArgb) argb = _glowBright;
      final i = (y * side + x) * 4;
      bytes[i] = (argb >> 16) & 0xff;
      bytes[i + 1] = (argb >> 8) & 0xff;
      bytes[i + 2] = argb & 0xff;
      bytes[i + 3] = (argb >> 24) & 0xff;
    }
  }
  return bytes;
}

/// O mesmo sprite, montado na hora (sem decodificar): para as centenas de variantes pequenas do mapa, sem fila de
/// decodificação.
ui.Image spriteToImageSync(List<String> rows, {Map<String, int> palette = spritePalette}) {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final p = ui.Paint()..isAntiAlias = false;
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final ch = rows[y][x];
      if (ch == '.') continue;
      c.drawRect(ui.Rect.fromLTWH(x + 0.0, y + 0.0, 1, 1), p..color = ui.Color(palette[ch] ?? (throw StateError('Caractere sem cor no sprite: "$ch"'))));
    }
  }
  return rec.endRecording().toImageSync(rows.length, rows.length);
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
///
/// As famílias da fase 1 (e as Fagulhas, `hum.mote`) têm o sprite provisório de `phase1_sprites.dart`, com a paleta de
/// [spritePaletteOf].
List<String> ecoSpriteRows(String speciesId) {
  // A Entidade Maior e o Arquétipo só têm a arte do Aseprite: o placeholder (o que o código gera quando falta arte) é o do
  // Espírito da família.
  final tier = tierOfId(speciesId);
  if (tier == SpeciesTier.major || tier == SpeciesTier.archetype) return ecoSpriteRows('${familyOfId(speciesId)}.spirit');
  if (_ritualStandIn(speciesId) case final spirit?) return ecoSpriteRows(spirit);
  if (hasPhase1Sprite(speciesId)) return phase1Rows(speciesId);
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

/// A paleta do sprite de [key]: a do tipo nos provisórios da fase 1, a fixa nos três do MVP.
Map<String, int> spritePaletteOf(String key) {
  if (_ritualStandIn(key) case final spirit?) return spritePaletteOf(spirit);
  // 0.27.0: a Entidade e o Arquétipo usam as linhas do Espírito da família ([ecoSpriteRows]); a paleta vai junto.
  final tier = tierOfId(key);
  if (key.contains('.') && (tier == SpeciesTier.major || tier == SpeciesTier.archetype)) return spritePaletteOf('${familyOfId(key)}.spirit');
  return hasPhase1Sprite(key) ? phase1Palette(spriteTypeOf(key)) : spritePalette;
}

/// O Espírito de ritual das famílias da fase 1 (Stormlamp...) só tem a arte do Aseprite: o placeholder (as linhas e a
/// paleta) é o do Espírito da família. Os três do MVP têm o próprio na tabela: `null`.
String? _ritualStandIn(String speciesId) =>
    speciesId.endsWith('.ritual') && !ecoSprites.containsKey(speciesId) ? '${familyOfId(speciesId)}.spirit' : null;

/// Sprite de um Eco em duas versões: normal e com as costuras acesas.
class EcoSprite {
  const EcoSprite(this.normal, this.bright);

  final ui.Image normal;
  final ui.Image bright;

  static Future<EcoSprite> load(String speciesId) {
    final rows = ecoSpriteRows(speciesId);
    return _from(rows, provisionalArt ? spritePaletteOf(speciesId) : _silhouetteOf(rows));
  }

  /// Silhueta neutra, para o modo de tipo oculto.
  static Future<EcoSprite> loadNeutral() => _from(neutralSprite);

  /// O Eco redesenhado na grade do mapa ([mapEcoPx] pixels de lado), para o mapa de jogo.
  static Future<EcoSprite> loadMap(String speciesId) =>
      _from(downscaleRows(ecoSpriteRows(speciesId), mapPxOf(speciesId)), spritePaletteOf(speciesId));

  /// 0.21.0: a variante [variant] (`urban`, `lit`, `shiny`...) no tamanho do mapa, com o valor e o acessório de
  /// `variant_art.dart`. O acessório entra na votação da redução, senão some.
  static ui.Image loadMapVariant(String speciesId, String variant) {
    final px = mapPxOf(speciesId);
    return spriteToImageSync(downscaleRows(variantRows(ecoSpriteRows(speciesId), variant), px, keep: ecoIdentity + variantIdentity), palette: variantPalette(spritePaletteOf(speciesId), variant));
  }

  /// O contorno de luz neon da Iluminada no tamanho do mapa (por baixo do sprite), ou `null` nas outras variantes.
  static ui.Image? loadMapGlow(String speciesId, String variant) {
    final glow = variantGlowRows(ecoSpriteRows(speciesId), variant);
    if (glow == null) return null;
    final px = mapPxOf(speciesId);
    return spriteToImageSync(downscaleRows(glow, px, keep: 'N'), palette: variantPalette(spritePaletteOf(speciesId), variant));
  }

  static Future<EcoSprite> _from(List<String> rows, [Map<String, int> palette = spritePalette]) async =>
      EcoSprite(await spriteToImage(rows, palette: palette), await spriteToImage(rows, brightSeams: true, palette: palette));
}

/// Lado, em pixels, dos sprites do mapa: Ecos e Conjurador/Familiar. 0.25.0: o pixel de arte passou de 3 dp para 2 dp
/// (`map.art_pixel_dp`) com os mesmos metros no mundo, então cada sprite tem 1,5 vez os pixels (19 → 28, 16 → 24).
const int mapEcoPx = 28;
const int mapPlayerPx = 24;

/// O Espírito (9 m, contra 7 m do Eco): 28 × 9 / 7 = 36 pixels.
const int mapSpiritPx = 36;

/// A Entidade Maior (12 m) e o Arquétipo (16 m), a 4 pixels por metro (docs/art/estilo-criaturas.md).
const int mapMajorPx = 48;
const int mapArchetypePx = 64;

/// O lado do quadro do mapa da espécie [speciesId], pela camada.
int mapPxOf(String speciesId) => switch (tierOfId(speciesId)) {
      SpeciesTier.eco => mapEcoPx,
      SpeciesTier.spirit => mapSpiritPx,
      SpeciesTier.major => mapMajorPx,
      SpeciesTier.archetype => mapArchetypePx,
    };

/// Os quadros do Conjurador para o mapa: os de 24 × 24 desenhados à mão na grade de 2 dp (0.25.0), ou os reduzidos por
/// código se [mapPlayerPx] não for 24.
Future<List<ui.Image>> loadPlayerFramesMap() async => [
      for (final (hand, big) in [(playerMap24, playerSprite), (playerMapStepA24, playerStepASprite), (playerMapStepB24, playerStepBSprite)])
        await spriteToImage(mapPlayerPx == 24 ? hand : downscaleRows(big, mapPlayerPx, keep: 'C'), palette: playerPalette),
    ];

/// Os quadros do Conjurador: parado e os dois do passo, nesta ordem.
Future<List<ui.Image>> loadPlayerFrames() async => [
      await spriteToImage(playerSprite, palette: playerPalette),
      await spriteToImage(playerStepASprite, palette: playerPalette),
      await spriteToImage(playerStepBSprite, palette: playerPalette),
    ];
