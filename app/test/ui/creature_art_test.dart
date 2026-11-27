import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/species_ids.dart';
import 'package:kenoma/ui/game/creature_anim.dart';
import 'package:kenoma/ui/game/creature_art.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart' show mapPxOf;

/// Lê os assets direto do disco (a arte de verdade, sem o bundle do Flutter).
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(await File(key).readAsBytes()));
}

/// 0.25.0 e 0.25.1: toda criatura com arte do Aseprite (`assets/art/creatures/index.json`): as animações mínimas do GDD na
/// grade de 2 dp, as três camadas, o retrato de 96, as variantes legíveis em escala de cinza e o retrato com a mesma troca
/// de cores do mapa.
void main() {
  final index = jsonDecode(File('assets/art/creatures/index.json').readAsStringSync()) as Map<String, dynamic>;
  final species = (index['species'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as Map<String, dynamic>)['folder'] as String));
  const variantKeys = {'urban', 'green', 'water', 'residential', 'lit', 'sacred', 'crimson'};

  // A luminância de um quadro ([x0] em pixels) de [img] (transparente = -1).
  Future<List<double>> gray(WidgetTester tester, ui.Image img, int x0, int side) async {
    final b = (await tester.runAsync(() => img.toByteData()))!;
    int at(int x, int y, int c) => b.getUint8((y * img.width + x0 + x) * 4 + c);
    return [
      for (var y = 0; y < side; y++)
        for (var x = 0; x < side; x++) if (at(x, y, 3) < 128) -1.0 else 0.299 * at(x, y, 0) + 0.587 * at(x, y, 1) + 0.114 * at(x, y, 2),
    ];
  }

  int differ(List<double> a, List<double> b) {
    var n = 0;
    for (var p = 0; p < a.length; p++) {
      if ((a[p] < 0) != (b[p] < 0) || (a[p] >= 0 && (a[p] - b[p]).abs() > 24)) n++;
    }
    return n;
  }

  test('o índice tem o Humoth e só pastas que existem', () {
    expect(species['hum.eco'], 'humoth');
    for (final f in species.values) {
      expect(File('assets/art/creatures/$f/$f.json').existsSync(), isTrue, reason: f);
    }
  });

  for (final MapEntry(key: id, value: folder) in species.entries) {
    group('$id ($folder)', () {
      testWidgets('as seis animações na grade do mapa, com corpo, LEDs e brilho do mesmo tamanho, e o retrato de 96 (128 no Arquétipo)', (tester) async {
        await tester.runAsync(() => CreatureArt.loadAll(_DiskBundle()));
        final art = CreatureArt.of(id)!;
        expect(art.frame, mapPxOf(id), reason: 'Eco 28, Espírito 36, Entidade Maior 48, Arquétipo 64: o tamanho no mundo não muda');
        expect(art.anims.keys.toSet(), CreatureAnim.values.toSet(), reason: 'parado, deriva, alerta, fuga, nascer, sintonizado');
        for (final e in art.anims.entries) {
          final s = e.value;
          expect((s.body.width, s.body.height), (s.frames * art.frame, art.frame), reason: e.key.name);
          for (final layer in [s.leds, s.glow]) {
            expect(layer, isNotNull, reason: '${e.key.name}: as três camadas');
            expect((layer!.width, layer.height), (s.body.width, s.body.height), reason: e.key.name);
          }
        }
        expect(art.portrait!.body.height, tierOfId(id) == SpeciesTier.archetype ? 128 : 96, reason: 'retrato de 96; o do Arquétipo, 128');
        expect(art.portrait!.frames, greaterThanOrEqualTo(2));
      });

      testWidgets('cada variante é distinta das outras e da comum em escala de cinza; o retrato troca as cores igual', (tester) async {
        await tester.runAsync(() => CreatureArt.loadAll(_DiskBundle()));
        final art = CreatureArt.of(id)!;
        expect(art.variantKeys.toSet(), variantKeys);
        // 0.26.2: as variantes se montam na primeira vez que aparecem.
        for (final k in variantKeys) {
          await tester.runAsync(() => art.buildVariant(k));
        }
        final looks = {
          'comum': await gray(tester, art.anims[CreatureAnim.idle]!.body, 0, art.frame),
          for (final k in variantKeys) k: await gray(tester, art.bodyOf(CreatureAnim.idle, k)!, 0, art.frame),
        };
        final names = looks.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final d = differ(looks[names[i]]!, looks[names[j]]!);
            expect(d, greaterThanOrEqualTo(12), reason: '${names[i]} × ${names[j]} em cinza: só $d pixels diferentes');
          }
        }
        // O retrato da variante é a troca de cores do mapa (não um tom por cima): muda as cores sem mudar a silhueta.
        Future<List<int>> rgba(ui.Image img) async => (await tester.runAsync(() => img.toByteData()))!.buffer.asUint8List().toList();
        final base = await rgba(art.portrait!.body);
        for (final k in variantKeys) {
          final v = await rgba(art.portraitOf(k)!);
          var changed = 0, shape = 0;
          for (var p = 0; p < v.length; p += 4) {
            if ((v[p + 3] == 0) != (base[p + 3] == 0)) shape++;
            if (v[p] != base[p] || v[p + 1] != base[p + 1] || v[p + 2] != base[p + 2]) changed++;
          }
          expect(changed, greaterThan(0), reason: '$k: o retrato não mudou');
          expect(shape, 0, reason: '$k: a troca de cores mudou a silhueta');
        }
      });
    });
  }
}
