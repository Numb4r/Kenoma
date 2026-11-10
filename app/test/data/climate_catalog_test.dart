import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/ui/game/climate_ground.dart' show groundLayerKinds, groundStyles, markStyles;
import 'package:kenoma/ui/game/climate_layers.dart' show screenLayerKinds;
import 'package:kenoma/ui/game/moon_hud.dart' show WeatherGlyphPainter;

import '../support/fixtures.dart';

/// As formas de partícula da tela e de enfeite do chão que o código sabe desenhar, e os estilos de peça do céu
/// (`climate_fx.dart`); os do chão vêm de `climate_ground.dart`.
const _shapes = {'streak', 'wisp', 'leaf', 'ember', 'flake', 'hail', 'dust', 'ash', 'pixel', 'glyph'};
const _groundShapes = {'glint', 'frost', 'leaf', 'branch', 'ember', 'streak', 'float', 'glyph', 'pixel', 'hailstone', 'dust', 'ash', 'figure'};
const _skyStyles = {'bolt', 'meteor', 'fall'};

void main() {
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
  final e6 = loadEpochs().epochs.firstWhere((e) => e.id == 6).climate!;
  final model = loadEpochs().epochs.firstWhere((e) => e.id == 7).climate!;

  test('os 44 climas do GDD rev 328 carregam: 17 nativos, 11 de outras regiões e 16 místicos; a época 6 segue com os 36', () {
    expect(model.defs.length, 44);
    expect(e6.defs.length, 36);
    expect(catalog.climates.keys.toSet(), model.defs.keys.toSet());
    expect(model.defs.keys, containsAll(e6.defs.keys));
    int n(ClimateCategory c) => model.defs.values.where((d) => d.category == c).length;
    expect((n(ClimateCategory.native), n(ClimateCategory.otherRegion), n(ClimateCategory.mystic)), (17, 11, 16));
    for (final id in ['hard_frost', 'dry_thunder', 'smog', 'freezing_rain', 'hurricane', 'rune_rain', 'double_moon', 'vigil']) {
      expect(model.defs, contains(id));
    }
  });

  test('todo clima tem nome, linha do HUD, ícone conhecido e camadas que o código desenha (menos o Limpo, que não tem nada)', () {
    for (final c in catalog.climates.values) {
      expect(c.name, isNotEmpty, reason: c.id);
      expect(c.hud, startsWith(c.name.split(' ').first), reason: '${c.id}: a linha começa pelo nome');
      expect(c.icon, isNotEmpty, reason: c.id);
      for (final part in c.icon) {
        expect(WeatherGlyphPainter.parts.keys, contains(part), reason: '${c.id}: parte de ícone $part');
      }
      if (c.id != 'clear') expect(c.layers, isNotEmpty, reason: c.id);
      for (final l in c.layers) {
        expect(screenLayerKinds, contains(l.kind), reason: '${c.id}: camada de tela ${l.kind}');
        if (l.kind == 'particles') expect(_shapes, contains(l.str('shape')), reason: '${c.id}: forma ${l.str('shape')}');
      }
      for (final g in c.ground) {
        expect(groundLayerKinds, contains(g.kind), reason: '${c.id}: camada do chão ${g.kind}');
        if (g.kind == 'scatter') expect(_groundShapes, contains(g.str('shape')), reason: '${c.id}: enfeite ${g.str('shape')}');
      }
      expect(c.maxParticles, lessThanOrEqualTo(260), reason: '${c.id}: limite fixo de partículas por estado');
    }
  });

  test('duas camadas: o que está no chão (sombras, figuras, ondulação, asfalto, brilho, funil) não fica mais na tela', () {
    const ground = {'shadows', 'figures', 'ripple', 'shimmer', 'sheen', 'funnel'};
    for (final c in catalog.climates.values) {
      expect(c.layers.map((l) => l.kind).toSet().intersection(ground), isEmpty, reason: c.id);
    }
    for (final id in ['fog_procession', 'veil_tide', 'black_sun', 'cloudy']) {
      final pieces = model.def(id)!.pieces.whereType<ZonePiece>();
      expect(pieces, isNotEmpty, reason: '$id: a marca no chão é uma zona do mundo');
    }
  });

  test('toda peça das épocas 6 e 7 tem visual com estilo conhecido; impactos com marca no chão têm duração', () {
    for (final m in [e6, model]) {
      for (final d in m.defs.values) {
        for (final p in d.pieces) {
          if (p is DropPiece || p is ZonePiece || p is PuddlePiece) {
            expect(catalog.pieces.keys, contains(p.name), reason: '${d.id}: ${p.name}');
            expect({..._skyStyles, ...groundStyles}, contains(catalog.piece(p.name).style), reason: p.name);
          }
        }
      }
    }
    for (final v in catalog.pieces.values.where((v) => v.mark != null)) {
      expect(markStyles, contains(v.mark));
      expect(v.markS, greaterThan(0));
    }
    expect(catalog.piece('meteor').mark, 'crater');
    expect(catalog.piece('meteor').shake, isTrue);
  });

  test('todo clima tem marca no mapa e interação na época 7 (docs/clima-auditoria.md)', () {
    for (final d in model.defs.values) {
      final info = catalog.of(d.id);
      final marks = info.ground.isNotEmpty || d.pieces.any((p) => p is ZonePiece || p is PuddlePiece || (p is DropPiece && p.impact));
      expect(marks, isTrue, reason: '${d.id}: sem marca no mapa');
      expect(d.pieces, isNotEmpty, reason: '${d.id}: sem interação');
    }
  });

  test('todo evento do calendário e da astronomia tem nome e motivo no clima.json', () {
    for (final id in [...model.calendar.map((r) => r.id), ...model.astro.map((r) => r.id)]) {
      expect(catalog.events, contains(id), reason: id);
      expect(catalog.events[id]!.reason, isNotEmpty);
    }
    expect(catalog.reasons.keys, containsAll(['season', 'debug', 'feed']));
  });

  test('o Eco do raio declara o tipo Elétrico com fallback e marca: hoje um Sootling carregado, ciano', () {
    final bolt = e6.def('storm')!.pieces.whereType<DropPiece>().single;
    expect((bolt.name, bolt.impact, bolt.everyS), ('lightning', true, (20, 60)));
    expect((bolt.spawn!.type, bolt.spawn!.fallbackSpecies, bolt.spawn!.tag), ('electric', 'soot.eco', 'charged'));
    expect(catalog.tags['charged']!.tint, 0xFF5FD3C6);
    expect(catalog.tags['charged']!.name, 'Eco carregado');
  });
}
