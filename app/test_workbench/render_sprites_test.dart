// Renderiza para o workbench cada forma do Bestiário e cada variante, em PNG, nos dois tamanhos (Bestiário e mapa), e grava
// um manifesto que o `workbench/capture/catalogo.py` lê. Fica fora de `test/`: não roda na suíte.
// Uso: cd app && flutter test test_workbench/render_sprites_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/core/species_ids.dart';
import 'package:kenoma/player/attributes.dart' show abilityText;
import 'package:kenoma/player/circle.dart' show abilityLabel;
import 'package:kenoma/ui/type_label.dart';
import 'package:kenoma/player/bestiary_view.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';

import '../test/support/fixtures.dart';

const out = '../workbench/catalog/formas';
const bestiaryPx = 160; // o retrato do detalhe do Bestiário
const mapScale = 4; // o sprite do mapa em pixels de arte, ampliado sem suavizar

Future<void> png(ui.Image src, int side, String path, {int? tint, double alpha = 0.4}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  if (tint != null) paint.colorFilter = ui.ColorFilter.mode(ui.Color(tint).withValues(alpha: alpha), ui.BlendMode.srcATop);
  c.drawImageRect(src, ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()), paint);
  final img = await rec.endRecording().toImage(side, side);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('sprites do workbench', () async {
    final data = loadGameData();
    Directory(out).createSync(recursive: true);
    final rows = <Map<String, Object?>>[];
    final variants = [null, ...data.variants.keys];
    for (final f in bestiaryForms(data)) {
      final creature = !f.isSpark;
      final big = await EcoSprite.load(f.spriteKey);
      final small = creature ? await EcoSprite.loadMap(f.spriteKey) : null;
      for (final v in creature ? variants : [null]) {
        final info = v == null ? null : data.variants[v];
        final key = v == null ? f.id : '${f.id}@$v';
        final file = key.replaceAll('@', '__');
        final alpha = v == 'shiny' ? 0.55 : 0.4;
        await png(big.normal, bestiaryPx, '$out/${file}_bestiario.png', tint: info?.tint, alpha: alpha);
        if (small != null) await png(small.normal, small.normal.width * mapScale, '$out/${file}_mapa.png', tint: info?.tint, alpha: alpha);
        final sp = data.species(f.id);
        rows.add({
          'id': key,
          'form': f.id,
          'name': f.name,
          'variant': v,
          'variantName': info?.name,
          'variantTrait': info?.trait,
          'layer': f.layer.name,
          'family': f.family.id,
          'familyName': f.family.name,
          'type': f.family.type,
          'number': f.number,
          'ritual': sp?.ritualOnly ?? false,
          'tier': f.isSpark ? 'spark' : tierOfId(f.id).name,
          'bestiario': 'formas/${file}_bestiario.png',
          'mapa': small == null ? null : 'formas/${file}_mapa.png',
        });
      }
    }
    File('$out/manifesto.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(rows));
    // Os textos que o jogo mostra, pelas funções do próprio jogo: tipos, habilidades por faixa e apps do celular.
    final bands = data.tuning.abilityBands;
    final dados = {
      'tipos': {for (final t in EcoType.values) t.name: typeLabel(t)},
      'resistencia': {for (final t in EcoType.values) t.name: typePatternText(t)},
      'habilidades': [
        for (final sp in data.tuning.species)
          if (sp.ability case final a?)
            {
              'species': sp.id,
              'name': sp.name,
              'kind': a.kind,
              'faixas': [
                for (var k = 0; k < a.bands.length && k < bands.length; k++)
                  {'niveis': '${bands[k].$1}${k + 1 == bands.length ? '+' : ' a ${bands[k].$2}'}', 'curto': abilityLabel(a.kind, a.bands[k], data.personal), 'longo': abilityText(a, bands[k].$1, bands, data.personal)},
              ],
            },
      ],
      'apps': [for (final app in data.phone.apps) {'id': app.id, 'nome': app.label, 'nivel': app.unlockLevel}],
    };
    File('$out/../dados.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(dados));
    expect(rows, isNotEmpty);
  });
}
