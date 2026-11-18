/// A arte animada das criaturas desenhadas no Aseprite (0.25.0; a primeira é o Humoth): as tiras de cada animação em
/// três camadas (corpo, LEDs e brilho), as variantes montadas na carga (troca de cores e acessório em cada quadro) e o
/// retrato do Bestiário. O formato está em docs/art/estilo-criaturas.md. Criatura sem arte aqui usa o sprite de sempre.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'creature_anim.dart';

/// Uma animação: as três tiras (mesmos quadros), quantos quadros, a velocidade e quanto o corpo sobe em cada quadro.
class CreatureStrip {
  const CreatureStrip({required this.body, required this.leds, required this.glow, required this.frames, required this.fps, required this.bodyDy, this.bodyVisible = const []});

  final ui.Image body;
  final ui.Image? leds, glow;
  final int frames;
  final double fps;
  final List<int> bodyDy;

  /// Os quadros em que o corpo aparece (vazio: todos). Nos que são só faísca (o começo do nascer, o fim da sintonia), o
  /// acessório da variante não entra.
  final List<bool> bodyVisible;
}

class CreatureArt {
  CreatureArt({required this.frame, required this.anims, required this.variants, this.portrait, this.portraitVariants = const {}, this.spawn});

  /// Lado do quadro do mapa (28 na grade de 2 dp).
  final int frame;
  final Map<CreatureAnim, CreatureStrip> anims;

  /// O corpo de cada animação já com a variante aplicada: variante → animação → tira.
  final Map<String, Map<CreatureAnim, ui.Image>> variants;

  /// O retrato do Bestiário (96 × 96), pairando com os LEDs.
  final CreatureStrip? portrait;

  /// 0.25.1: o corpo do retrato em cada variante, pela mesma troca de cores do mapa (sem o acessório, que é do quadro de
  /// 28 px).
  final Map<String, ui.Image> portraitVariants;

  /// 0.25.1: de onde a criatura nasce no desenho (`assets/art/creatures/index.json`, `spawn`): `lightning_lamp` (o raio
  /// na tempestade, senão o poste mais perto à noite), `puddle`, `ground`, `fog`. `null`: onde o Eco aparece.
  final String? spawn;

  /// O corpo do retrato na variante [variant] (`null` ou sem arte: o comum).
  ui.Image? portraitOf(String? variant) => portraitVariants[variant] ?? portrait?.body;

  /// A tira do corpo de [a] na variante [variant] (`null` ou sem arte: a comum).
  ui.Image bodyOf(CreatureAnim a, String? variant) => variants[variant]?[a] ?? anims[a]!.body;

  static final _byFolder = <String, CreatureArt>{};

  /// As espécies com arte animada e a pasta de cada uma em `assets/art/creatures/` (0.25.1: lidas do `index.json`, que
  /// também diz o gatilho de nascer de cada uma).
  static final Map<String, String> folders = {'hum.eco': 'humoth'};
  static final Map<String, String> _spawns = {'hum.eco': 'lightning_lamp'};

  /// 0.25.1: os climas que valem como raio, poça e neblina para o gatilho de nascer, e até onde se procura o poste (m).
  static final Map<String, Set<String>> triggerClimates = {
    'lightning': {'storm', 'dry_thunder', 'hurricane'},
  };
  static double lampM = 30;

  /// A arte de [speciesId], se já carregada.
  static CreatureArt? of(String speciesId) => _byFolder[folders[speciesId]] ?? _testing[speciesId];

  static final _testing = <String, CreatureArt>{};

  /// Só para testes: uma arte feita à mão para [speciesId] (`null` tira).
  @visibleForTesting
  static void registerForTest(String speciesId, CreatureArt? art) => art == null ? _testing.remove(speciesId) : _testing[speciesId] = art;

  /// Carrega tudo o que há (uma vez). Pasta sem o JSON ou com arquivo faltando fica sem arte: a criatura usa o sprite de
  /// sempre.
  static Future<void> loadAll([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    try {
      final index = jsonDecode(await b.loadString('assets/art/creatures/index.json')) as Map<String, dynamic>;
      for (final e in ((index['climates'] as Map<String, dynamic>?) ?? const {}).entries) {
        triggerClimates[e.key] = {...(e.value as List<dynamic>).cast<String>()};
      }
      lampM = (index['lamp_m'] as num?)?.toDouble() ?? lampM;
      for (final e in ((index['species'] as Map<String, dynamic>?) ?? const {}).entries) {
        final m = e.value as Map<String, dynamic>;
        folders[e.key] = m['folder'] as String;
        if (m['spawn'] case final String s) _spawns[e.key] = s;
      }
    } catch (_) {
      // sem índice (testes): só o que já está na lista
    }
    for (final MapEntry(key: id, value: folder) in folders.entries.toList()) {
      if (_byFolder.containsKey(folder)) continue;
      try {
        final a = await _load(b, folder, spawn: _spawns[id]);
        if (a != null) _byFolder[folder] = a;
      } catch (_) {
        // sem a arte (testes, ou pasta incompleta): fica o sprite de sempre
      }
    }
  }

  static Future<ui.Image> _image(Uint8List bytes) async => (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

  static Future<CreatureArt?> _load(AssetBundle b, String folder, {String? spawn}) async {
    final base = 'assets/art/creatures/$folder/$folder';
    final meta = jsonDecode(await b.loadString('$base.json')) as Map<String, dynamic>;
    Future<ui.Image?> opt(String path) async {
      try {
        return await _image((await b.load(path)).buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }

    final dy = (meta['body_dy'] as Map<String, dynamic>?) ?? const {};
    final visible = (meta['body_visible'] as Map<String, dynamic>?) ?? const {};
    final anims = <CreatureAnim, CreatureStrip>{};
    for (final e in (meta['anims'] as Map<String, dynamic>).entries) {
      final a = CreatureAnim.values.where((x) => x.name == e.key).firstOrNull;
      if (a == null) continue;
      final m = e.value as Map<String, dynamic>;
      final body = await opt('${base}_${e.key}.png');
      if (body == null) continue;
      anims[a] = CreatureStrip(
        body: body,
        leds: await opt('${base}_${e.key}_leds.png'),
        glow: await opt('${base}_${e.key}_glow.png'),
        frames: m['frames'] as int,
        fps: (m['fps'] as num).toDouble(),
        bodyDy: [for (final v in (dy[e.key] as List<dynamic>?) ?? const []) (v as num).toInt()],
        bodyVisible: [for (final v in (visible[e.key] as List<dynamic>?) ?? const []) v == true || v == 1],
      );
    }
    if (!anims.containsKey(CreatureAnim.idle)) return null;
    final frame = (meta['frame'] as int?) ?? 28;
    // As variantes: troca de cores do corpo e o acessório por cima de cada quadro, acompanhando o corpo.
    final variants = <String, Map<CreatureAnim, ui.Image>>{};
    final maps = <String, Map<int, int>>{};
    try {
      final vj = jsonDecode(await b.loadString('${base}_variants.json')) as Map<String, dynamic>;
      for (final v in vj.entries) {
        final spec = v.value as Map<String, dynamic>;
        final map = maps[v.key] = {for (final c in ((spec['map'] as Map<String, dynamic>?) ?? const {}).entries) _hex(c.key): _hex(c.value as String)};
        final accName = spec['accessory'] as String?;
        final acc = accName == null ? null : await opt('assets/art/creatures/$folder/$accName');
        variants[v.key] = {
          for (final a in anims.entries) a.key: await _variant(a.value, map, acc, frame),
        };
      }
    } catch (_) {
      // sem variantes: todas usam o corpo comum
    }
    CreatureStrip? portrait;
    final portraitVariants = <String, ui.Image>{};
    final pb = await opt('${base}_portrait.png');
    if (pb != null) {
      final pm = meta['portrait'] as Map<String, dynamic>?;
      portrait = CreatureStrip(
        body: pb,
        leds: await opt('${base}_portrait_leds.png'),
        glow: await opt('${base}_portrait_glow.png'),
        frames: (pm?['frames'] as int?) ?? (pb.width / pb.height).floor(),
        fps: (pm?['fps'] as num?)?.toDouble() ?? 6,
        bodyDy: const [],
      );
      for (final e in maps.entries) {
        portraitVariants[e.key] = await _variant(portrait, e.value, null, pb.height);
      }
    }
    return CreatureArt(frame: frame, anims: anims, variants: variants, portrait: portrait, portraitVariants: portraitVariants, spawn: spawn);
  }

  static int _hex(String s) => int.parse(s.replaceFirst('#', ''), radix: 16) & 0xFFFFFF;

  /// A tira do corpo com as cores trocadas por [map] e o acessório [acc] (um quadro) por cima de cada quadro, subindo
  /// com o corpo (`bodyDy`).
  static Future<ui.Image> _variant(CreatureStrip s, Map<int, int> map, ui.Image? acc, int frame) async {
    final w = s.body.width, h = s.body.height;
    final px = (await s.body.toByteData())!.buffer.asUint8List();
    final out = Uint8List.fromList(px);
    for (var i = 0; i < out.length; i += 4) {
      if (out[i + 3] == 0) continue;
      final rgb = (out[i] << 16) | (out[i + 1] << 8) | out[i + 2];
      final to = map[rgb];
      if (to == null) continue;
      out[i] = (to >> 16) & 0xff;
      out[i + 1] = (to >> 8) & 0xff;
      out[i + 2] = to & 0xff;
    }
    if (acc != null) {
      final ap = (await acc.toByteData())!.buffer.asUint8List();
      for (var f = 0; f < s.frames; f++) {
        if (f < s.bodyVisible.length && !s.bodyVisible[f]) continue;
        final dy = f < s.bodyDy.length ? s.bodyDy[f] : 0;
        for (var y = 0; y < acc.height; y++) {
          for (var x = 0; x < acc.width; x++) {
            final ai = (y * acc.width + x) * 4;
            if (ap[ai + 3] == 0) continue;
            final ty = y + dy, tx = f * frame + x;
            if (ty < 0 || ty >= h || tx >= w) continue;
            final oi = (ty * w + tx) * 4;
            out.setRange(oi, oi + 4, ap.sublist(ai, ai + 4));
          }
        }
      }
    }
    final buf = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    return (await (await desc.instantiateCodec()).getNextFrame()).image;
  }
}
