/// A arte animada das criaturas desenhadas no Aseprite (0.25.0; a primeira é o Humoth): as tiras de cada animação em
/// três camadas (corpo, LEDs e brilho), as variantes montadas na carga (troca de cores e acessório em cada quadro) e o
/// retrato do Bestiário. O formato está em docs/art/estilo-criaturas.md. Criatura sem arte aqui usa o sprite de sempre.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../../core/epochs.dart';
import '../../core/species_ids.dart';
import 'creature_anim.dart';

/// Uma animação: as três tiras (mesmos quadros), quantos quadros, a velocidade e quanto o corpo sobe em cada quadro.
class CreatureStrip {
  CreatureStrip({required ui.Image body, required ui.Image? leds, required ui.Image? glow, required this.frames, required this.fps, required this.bodyDy, this.bodyVisible = const []})
      : _body = (() => body),
        _leds = leds == null ? null : (() => leds),
        _glow = glow == null ? null : (() => glow);

  /// 0.26.2: as camadas recortadas da folha da família só quando são desenhadas pela primeira vez. Recortar as 1680 na
  /// abertura enfileirava 1680 desenhos fora da tela na thread de raster e segurava o primeiro quadro do mapa.
  CreatureStrip.lazy({required ui.Image Function() cutBody, ui.Image Function()? cutLeds, ui.Image Function()? cutGlow, required this.frames, required this.fps, required this.bodyDy, this.bodyVisible = const []})
      : _body = cutBody,
        _leds = cutLeds,
        _glow = cutGlow;

  final ui.Image Function() _body;
  final ui.Image Function()? _leds, _glow;

  late final ui.Image body = _body();
  late final ui.Image? leds = _leds?.call();
  late final ui.Image? glow = _glow?.call();

  final int frames;
  final double fps;
  final List<int> bodyDy;

  /// Os quadros em que o corpo aparece (vazio: todos). Nos que são só faísca (o começo do nascer, o fim da sintonia), o
  /// acessório da variante não entra.
  final List<bool> bodyVisible;
}

/// A receita de uma variante: a troca de cores (0xRRGGBB → 0xRRGGBB) e o acessório de um quadro por cima.
typedef VariantSpec = ({Map<int, int> map, ui.Image Function()? accessory});

class CreatureArt {
  CreatureArt({required this.frame, required this.anims, required this.variants, this.specs = const {}, this.portrait, Map<String, ui.Image>? portraitVariants, this.spawn})
      : portraitVariants = portraitVariants ?? {};

  /// Lado do quadro do mapa (28 na grade de 2 dp).
  final int frame;
  final Map<CreatureAnim, CreatureStrip> anims;

  /// O corpo de cada animação com a variante aplicada: variante → animação → tira. 0.26.2: só as já montadas
  /// ([buildVariant]); as outras estão em [specs].
  final Map<String, Map<CreatureAnim, ui.Image>> variants;

  /// 0.26.2: a receita de cada variante (troca de cores e acessório), montada na primeira vez que aparece.
  final Map<String, VariantSpec> specs;

  /// As variantes que a criatura tem (montadas ou não).
  Iterable<String> get variantKeys => {...specs.keys, ...variants.keys};

  final _building = <String, Future<void>>{};

  /// Monta a variante [variant] (o corpo de cada animação e o do retrato), uma vez.
  Future<void> buildVariant(String variant) => _building[variant] ??= _build(variant);

  Future<void> _build(String variant) async {
    final spec = specs[variant];
    if (spec == null || variants.containsKey(variant)) return;
    final acc = spec.accessory?.call();
    final built = {for (final a in anims.entries) a.key: await _variant(a.value, spec.map, acc, frame)};
    if (portrait case final p?) portraitVariants[variant] = await _variant(p, spec.map, null, p.body.height);
    variants[variant] = built;
  }

  /// O retrato do Bestiário (96 × 96), pairando com os LEDs.
  final CreatureStrip? portrait;

  /// 0.25.1: o corpo do retrato em cada variante, pela mesma troca de cores do mapa (sem o acessório, que é do quadro de
  /// 28 px).
  final Map<String, ui.Image> portraitVariants;

  /// 0.25.1: de onde a criatura nasce no desenho (`assets/art/creatures/index.json`, `spawn`): `lightning_lamp` (o raio
  /// na tempestade, senão o poste mais perto à noite), `puddle`, `ground`, `fog`. `null`: onde o Eco aparece.
  final String? spawn;

  /// O corpo do retrato na variante [variant] (`null` ou sem arte: o comum). Variante ainda não montada: `null`, e ela
  /// começa a ser montada (quem desenha pula este quadro).
  ui.Image? portraitOf(String? variant) {
    if (variant == null || !specs.containsKey(variant) && !variants.containsKey(variant)) return portrait?.body;
    if (portraitVariants[variant] case final img?) return img;
    if (variants.containsKey(variant)) return portrait?.body;
    unawaited(buildVariant(variant));
    return null;
  }

  /// A tira do corpo de [a] na variante [variant] (`null` ou sem arte: a comum). Variante ainda não montada: `null`, e
  /// ela começa a ser montada (quem desenha pula a criatura neste quadro, em vez de mostrar as cores erradas).
  ui.Image? bodyOf(CreatureAnim a, String? variant) {
    if (variant == null || !specs.containsKey(variant) && !variants.containsKey(variant)) return anims[a]!.body;
    if (variants[variant] case final v?) return v[a] ?? anims[a]!.body;
    unawaited(buildVariant(variant));
    return null;
  }

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

  /// As famílias que nascem na época [epoch] (os Ecos das tabelas de spawn): o que a tela de carregamento espera.
  static List<String> familiesOf(Epoch epoch) => {
        for (final item in epoch.items)
          if (item.kind == 'eco')
            for (final t in item.table.values)
              for (final w in t) familyOfId(w.id),
      }.toList();

  static Future<void>? _index;
  static final _families = <String, Future<void>>{};

  /// Só para testes: esquece as cargas em andamento (a de um teste anterior morre com a zona dele e nunca termina). O que
  /// já carregou fica.
  @visibleForTesting
  static void resetLoading() {
    _index = null;
    _families.clear();
  }

  /// As famílias com arte, pelo índice (depois de [loadAll] ou [loadFamilies]).
  static Iterable<String> get families => {for (final id in folders.keys) familyOfId(id)};

  /// Carrega tudo o que há (uma vez): as famílias de [first] antes, o resto junto. Família sem folha ou com a folha
  /// quebrada fica sem arte: a criatura usa o sprite de sempre (só fora da release, `provisionalArt`).
  static Future<void> loadAll([AssetBundle? bundle, Iterable<String> first = const []]) async {
    final b = bundle ?? rootBundle;
    await loadFamilies(first, b);
    await loadFamilies(families, b);
  }

  /// Carrega as famílias [ids] (`soot`...), em paralelo. Cada família vem de uma folha só (0.26.2:
  /// `scripts/pack_creature_atlas.py`): uma leitura e uma decodificação no lugar das 140 de antes.
  static Future<void> loadFamilies(Iterable<String> ids, [AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    await (_index ??= _readIndex(b));
    await Future.wait([for (final f in ids.toSet()) _families[f] ??= _loadFamily(b, f)]);
  }

  static Future<void> _readIndex(AssetBundle b) async {
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
  }

  static Future<void> _loadFamily(AssetBundle b, String family) async {
    final ui.Image sheet;
    final Map<String, dynamic> atlas;
    try {
      atlas = jsonDecode(await b.loadString('assets/art/creatures/atlas/$family.json')) as Map<String, dynamic>;
      sheet = await _image((await b.load('assets/art/creatures/atlas/$family.png')).buffer.asUint8List());
    } catch (_) {
      return; // sem a folha (testes sem a arte): fica o sprite de sempre
    }
    final spawnOf = {for (final e in folders.entries) e.value: _spawns[e.key]};
    for (final e in (atlas['folders'] as Map<String, dynamic>).entries) {
      if (_byFolder.containsKey(e.key) || !spawnOf.containsKey(e.key)) continue;
      try {
        final a = _fromAtlas(sheet, e.key, e.value as Map<String, dynamic>, spawn: spawnOf[e.key]);
        if (a != null) _byFolder[e.key] = a;
      } catch (_) {
        // pasta incompleta: fica o sprite de sempre
      }
    }
    // A folha fica: cada camada se recorta dela na primeira vez que é desenhada.
  }

  static Future<ui.Image> _image(Uint8List bytes) async => (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

  /// O pedaço [r] (x, y, largura, altura) da folha, como imagem própria (copiado na GPU, sem decodificar de novo).
  static ui.Image _cut(ui.Image sheet, List<dynamic> r) {
    final x = (r[0] as num).toDouble(), y = (r[1] as num).toDouble(), w = r[2] as int, h = r[3] as int;
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawImageRect(sheet, ui.Rect.fromLTWH(x, y, w.toDouble(), h.toDouble()), ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.none);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    return img;
  }

  static CreatureArt? _fromAtlas(ui.Image sheet, String folder, Map<String, dynamic> entry, {String? spawn}) {
    final meta = entry['meta'] as Map<String, dynamic>;
    final rects = entry['rects'] as Map<String, dynamic>;
    ui.Image Function()? lazy(String name) => rects[name] == null ? null : () => _cut(sheet, rects[name] as List<dynamic>);
    final dy = (meta['body_dy'] as Map<String, dynamic>?) ?? const {};
    final visible = (meta['body_visible'] as Map<String, dynamic>?) ?? const {};
    final anims = <CreatureAnim, CreatureStrip>{};
    for (final e in (meta['anims'] as Map<String, dynamic>).entries) {
      final a = CreatureAnim.values.where((x) => x.name == e.key).firstOrNull;
      if (a == null) continue;
      final m = e.value as Map<String, dynamic>;
      final body = lazy('${folder}_${e.key}.png');
      if (body == null) continue;
      anims[a] = CreatureStrip.lazy(
        cutBody: body,
        cutLeds: lazy('${folder}_${e.key}_leds.png'),
        cutGlow: lazy('${folder}_${e.key}_glow.png'),
        frames: m['frames'] as int,
        fps: (m['fps'] as num).toDouble(),
        bodyDy: [for (final v in (dy[e.key] as List<dynamic>?) ?? const []) (v as num).toInt()],
        bodyVisible: [for (final v in (visible[e.key] as List<dynamic>?) ?? const []) v == true || v == 1],
      );
    }
    if (!anims.containsKey(CreatureAnim.idle)) return null;
    final frame = (meta['frame'] as int?) ?? 28;
    // As variantes: a troca de cores e o acessório, montados só quando a variante aparece (0.26.2: montar as sete de
    // todas as criaturas na abertura levava 38 s no g54).
    final specs = <String, VariantSpec>{
      for (final v in ((entry['variants'] as Map<String, dynamic>?) ?? const {}).entries)
        v.key: (
          map: {for (final c in (((v.value as Map<String, dynamic>)['map'] as Map<String, dynamic>?) ?? const {}).entries) _hex(c.key): _hex(c.value as String)},
          accessory: switch ((v.value as Map<String, dynamic>)['accessory']) { final String n => lazy(n), _ => null },
        ),
    };
    CreatureStrip? portrait;
    if (rects['${folder}_portrait.png'] case final List<dynamic> pr) {
      final pm = meta['portrait'] as Map<String, dynamic>?;
      portrait = CreatureStrip.lazy(
        cutBody: lazy('${folder}_portrait.png')!,
        cutLeds: lazy('${folder}_portrait_leds.png'),
        cutGlow: lazy('${folder}_portrait_glow.png'),
        frames: (pm?['frames'] as int?) ?? ((pr[2] as int) / (pr[3] as int)).floor(),
        fps: (pm?['fps'] as num?)?.toDouble() ?? 6,
        bodyDy: const [],
      );
    }
    return CreatureArt(frame: frame, anims: anims, variants: {}, specs: specs, portrait: portrait, spawn: spawn);
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
