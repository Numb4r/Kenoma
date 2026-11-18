/// O tráfego comum e as Fagulhas desenhados no Aseprite (0.25.1, pixel de 2 dp; fontes em `tools/art/traffic/` e
/// `tools/art/sparks/`). O tráfego vem em cores-chave (`traffic_keys.json`) que o código troca pela paleta de cada
/// fantasma, como fazia com as matrizes; as roupas do clima são camadas por cima do corpo. Sem os arquivos (testes), o
/// tráfego e as Fagulhas continuam desenhados em código.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../colors.dart' show kOutline;

/// Uma tira de quadros lida em RGBA (para trocar as cores na hora de gravar a `Picture`).
class RgbaStrip {
  const RgbaStrip(this.width, this.height, this.frames, this.px);

  final int width, height, frames;
  final Uint8List px;

  int get frameWidth => width ~/ frames;
}

/// Um sprite do tráfego: corpo, brilho (faróis e janelas, de noite) e o ponto de ancoragem no quadro.
class TrafficSprite {
  const TrafficSprite(this.body, this.glow, this.anchorX, this.anchorY);

  final RgbaStrip body;
  final RgbaStrip? glow;
  final double anchorX, anchorY;
}

class TrafficArt {
  TrafficArt({required this.sprites, required this.outfits, required this.keys, required this.carRefPx, required this.pedRefPx});

  /// O que já carregou (`null` até lá: o tráfego desenhado em código).
  static TrafficArt? current;

  @visibleForTesting
  static set testing(TrafficArt? a) => current = a;

  /// Por nome do arquivo sem extensão (`sedan`, `ped_adult`, `bus_city`).
  final Map<String, TrafficSprite> sprites;

  /// As peças de roupa por `<modelo>_<peça>` (`ped_adult_umbrella`).
  final Map<String, RgbaStrip> outfits;

  /// Os grupos de `traffic_keys.json`: grupo → papel → {hex, kind, of, shade, tint}.
  final Map<String, Map<String, Map<String, dynamic>>> keys;

  /// As medidas que valem `ghost_car_m` (comprimento do sedan) e `ghost_pedestrian_m` (altura do adulto), em pixels.
  final int carRefPx, pedRefPx;

  static Future<void>? _loading;

  static Future<void> load([AssetBundle? bundle]) => _loading ??= _load(bundle ?? rootBundle).then((a) => current = a, onError: (Object _) => null);

  static Future<RgbaStrip> decode(AssetBundle b, String path, int frames) async {
    final img = (await (await ui.instantiateImageCodec((await b.load(path)).buffer.asUint8List())).getNextFrame()).image;
    final bytes = (await img.toByteData())!.buffer.asUint8List();
    return RgbaStrip(img.width, img.height, frames, bytes);
  }

  static Future<TrafficArt> _load(AssetBundle b) async {
    const dir = 'assets/art/traffic/';
    final meta = jsonDecode(await b.loadString('${dir}traffic.json')) as Map<String, dynamic>;
    final raw = jsonDecode(await b.loadString('${dir}traffic_keys.json')) as Map<String, dynamic>;
    final keys = {
      for (final g in raw.entries)
        if (g.value is Map<String, dynamic> && !(g.value as Map<String, dynamic>).containsKey('hex'))
          g.key: {
            for (final r in (g.value as Map<String, dynamic>).entries)
              if (r.value is Map<String, dynamic>) r.key: r.value as Map<String, dynamic>,
          },
    };
    final sprites = <String, TrafficSprite>{};
    final outfits = <String, RgbaStrip>{};
    for (final group in ['top', 'upright']) {
      for (final e in (meta[group] as Map<String, dynamic>).entries) {
        if (e.value is! Map<String, dynamic>) continue;
        final m = e.value as Map<String, dynamic>, frames = m['frames'] as int, anchor = (m['anchor'] as List<dynamic>).cast<num>();
        final glow = m['glow'] as String?;
        sprites[e.key] = TrafficSprite(
          await decode(b, '$dir${m['file']}', frames),
          glow == null ? null : await decode(b, '$dir$glow', frames),
          anchor[0].toDouble(),
          anchor[1].toDouble(),
        );
        if (group == 'upright') {
          for (final piece in ((meta['outfits'] as Map<String, dynamic>)['pieces'] as List<dynamic>).cast<String>()) {
            outfits['${e.key}_$piece'] = await decode(b, '$dir${e.key}_$piece.png', frames);
          }
        }
      }
    }
    // 0.26.0: os extras (barco, canoa, cachorro e o carro da corrida) e os papéis de cor deles, somados grupo a grupo.
    try {
      final extra = jsonDecode(await b.loadString('${dir}traffic_extra.json')) as Map<String, dynamic>;
      for (final group in ['top', 'upright']) {
        for (final e in ((extra[group] as Map<String, dynamic>?) ?? const {}).entries) {
          if (e.value is! Map<String, dynamic>) continue;
          final m = e.value as Map<String, dynamic>, frames = m['frames'] as int, anchor = (m['anchor'] as List<dynamic>).cast<num>();
          final glow = m['glow'] as String?, leash = m['leash'] as String?;
          sprites[e.key] = TrafficSprite(await decode(b, '$dir${m['file']}', frames), glow == null ? null : await decode(b, '$dir$glow', frames), anchor[0].toDouble(), anchor[1].toDouble());
          if (leash != null) outfits['${e.key}_leash'] = await decode(b, '$dir$leash', frames);
        }
      }
      final rawExtra = jsonDecode(await b.loadString('${dir}traffic_keys_extra.json')) as Map<String, dynamic>;
      for (final g in rawExtra.entries) {
        if (g.value is! Map<String, dynamic>) continue;
        (keys[g.key] ??= {}).addAll({
          for (final r in (g.value as Map<String, dynamic>).entries)
            if (r.value is Map<String, dynamic>) r.key: r.value as Map<String, dynamic>,
        });
      }
    } catch (_) {
      // sem os extras: barco, cachorro e carro da corrida continuam em código
    }
    final ref = meta['ref_px'] as Map<String, dynamic>;
    return TrafficArt(sprites: sprites, outfits: outfits, keys: keys, carRefPx: ref['car'] as int, pedRefPx: ref['pedestrian'] as int);
  }

  /// A troca de cores: cada hex-chave dos [groups] vai para a cor do papel em [roles]; os derivados saem do papel de que
  /// derivam (sombra = mistura com o contorno, `tint` = mistura com branco). Papel sem cor em [roles] fica como está.
  Map<int, ui.Color> remap(List<String> groups, Map<String, ui.Color> roles) {
    final byRole = <String, ui.Color>{};
    final out = <int, ui.Color>{};
    int hex(Map<String, dynamic> r) => int.parse((r['hex'] as String).substring(1), radix: 16);
    final entries = [for (final g in groups) ...?keys[g]?.entries];
    for (final e in entries) {
      final c = roles[e.key];
      if (e.value['kind'] == 'key' && c != null) {
        byRole[e.key] = c;
        out[hex(e.value)] = c;
      }
    }
    // Os derivados podem derivar de derivados (a sombra da blusa leve): até estabilizar.
    for (var pass = 0; pass < 3; pass++) {
      for (final e in entries) {
        if (e.value['kind'] != 'derived' || byRole.containsKey(e.key)) continue;
        final parent = byRole[e.value['of']];
        if (parent == null) continue;
        final shade = (e.value['shade'] as num?)?.toDouble(), tint = (e.value['tint'] as num?)?.toDouble();
        final c = tint != null ? ui.Color.lerp(parent, const ui.Color(0xFFFFFFFF), tint)! : ui.Color.lerp(parent, kOutline, shade ?? 0)!;
        byRole[e.key] = c;
        out[hex(e.value)] = c;
      }
    }
    return out;
  }
}

/// Grava o quadro [frame] de [s] (e a peça [over] por cima), 1 unidade por pixel, com as cores trocadas por [remap].
ui.Picture recordStrip(RgbaStrip s, int frame, Map<int, ui.Color> remap, {RgbaStrip? over}) {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  final paint = ui.Paint()..isAntiAlias = false;
  void layer(RgbaStrip l) {
    final fw = l.frameWidth, x0 = (frame % l.frames) * fw;
    for (var y = 0; y < l.height; y++) {
      for (var x = 0; x < fw; x++) {
        final i = (y * l.width + x0 + x) * 4, a = l.px[i + 3];
        if (a == 0) continue;
        final rgb = (l.px[i] << 16) | (l.px[i + 1] << 8) | l.px[i + 2];
        paint.color = (remap[rgb] ?? ui.Color(0xFF000000 | rgb)).withAlpha(a);
        canvas.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
  }

  layer(s);
  if (over != null) layer(over);
  return rec.endRecording();
}

/// As Fagulhas do Aseprite: uma tira em laço por tipo, com o brilho por cima de noite.
class SparkArt {
  SparkArt(this.frame, this.frames, this.fps, this.strips);

  static SparkArt? current;
  static Future<void>? _loading;

  final int frame, frames;
  final double fps;

  /// Tipo (`fire`...) → (corpo, brilho).
  final Map<String, (ui.Image, ui.Image?)> strips;

  static Future<void> load([AssetBundle? bundle]) => _loading ??= _load(bundle ?? rootBundle).then((a) => current = a, onError: (Object _) => null);

  static Future<SparkArt> _load(AssetBundle b) async {
    const dir = 'assets/art/sparks/';
    final meta = jsonDecode(await b.loadString('${dir}sparks.json')) as Map<String, dynamic>;
    Future<ui.Image> img(String p) async => (await (await ui.instantiateImageCodec((await b.load(p)).buffer.asUint8List())).getNextFrame()).image;
    final strips = <String, (ui.Image, ui.Image?)>{};
    for (final t in (meta['types'] as Map<String, dynamic>).keys) {
      ui.Image? glow;
      try {
        glow = await img('${dir}spark_${t}_glow.png');
      } catch (_) {
        glow = null;
      }
      strips[t] = (await img('${dir}spark_$t.png'), glow);
    }
    return SparkArt((meta['frame'] as List<dynamic>).first as int, meta['frames'] as int, (meta['fps'] as num).toDouble(), strips);
  }
}
