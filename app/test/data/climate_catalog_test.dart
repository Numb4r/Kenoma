import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/ui/game/moon_hud.dart' show WeatherGlyphPainter;

import '../support/fixtures.dart';

/// Os tipos de camada que o código sabe desenhar (`climate_painter.dart` e `climate_layers.dart`) e os estilos de peça
/// (`climate_fx.dart`).
const _layerKinds = {'particles', 'tint', 'vignette', 'desaturate', 'shimmer', 'shadows', 'sheen', 'arc', 'aurora', 'glitch', 'ripple', 'funnel', 'figures', 'cracks', 'meteors', 'breath'};
const _shapes = {'streak', 'wisp', 'leaf', 'ember', 'flake', 'hail', 'dust', 'ash', 'pixel'};
const _styles = {'bolt', 'meteor', 'fall', 'zone', 'puddle', 'glow', 'whirl', 'ghost', 'figures'};

void main() {
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
  final model = loadEpochs().epochs.firstWhere((e) => e.id == 6).climate!;

  test('os 36 climas do GDD carregam: 14 nativos, 9 de outras regiões e 13 místicos, com o mundo na época e o visual no clima.json', () {
    expect(model.defs.length, 36);
    expect(catalog.climates.keys.toSet(), model.defs.keys.toSet());
    int n(ClimateCategory c) => model.defs.values.where((d) => d.category == c).length;
    expect((n(ClimateCategory.native), n(ClimateCategory.otherRegion), n(ClimateCategory.mystic)), (14, 9, 13));
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
        expect(_layerKinds, contains(l.kind), reason: '${c.id}: camada ${l.kind}');
        if (l.kind == 'particles') expect(_shapes, contains(l.str('shape')), reason: '${c.id}: forma ${l.str('shape')}');
      }
      expect(c.maxParticles, lessThanOrEqualTo(260), reason: '${c.id}: limite fixo de partículas por estado');
    }
  });

  test('toda peça de toda época tem visual com estilo conhecido', () {
    for (final d in model.defs.values) {
      for (final p in d.pieces) {
        if (p is DropPiece || p is ZonePiece) {
          expect(catalog.pieces.keys, contains(p.name), reason: '${d.id}: ${p.name}');
          expect(_styles, contains(catalog.piece(p.name).style), reason: p.name);
        }
      }
    }
  });

  test('o Eco do raio declara o tipo Elétrico com fallback e marca: hoje um Sootling carregado, ciano', () {
    final bolt = model.def('storm')!.pieces.whereType<DropPiece>().single;
    expect((bolt.name, bolt.impact, bolt.everyS), ('lightning', true, (20, 60)));
    expect((bolt.spawn!.type, bolt.spawn!.fallbackSpecies, bolt.spawn!.tag), ('electric', 'soot.eco', 'charged'));
    expect(catalog.tags['charged']!.tint, 0xFF5FD3C6);
    expect(catalog.tags['charged']!.name, 'Eco carregado');
  });
}
