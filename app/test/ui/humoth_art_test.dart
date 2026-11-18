import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/creature_anim.dart';
import 'package:kenoma/ui/game/creature_art.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart' show mapEcoPx;

/// Lê os assets direto do disco (o Humoth de verdade, sem o bundle do Flutter).
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(await File(key).readAsBytes()));
}

/// 0.25.0: o Humoth oficial (conceito A, "Letreiro"): as animações da lista na grade de 2 dp, as três camadas e as
/// variantes legíveis em escala de cinza (valor e acessório, não só cor).
void main() {
  testWidgets('as animações estão completas, na grade do mapa, com corpo, LEDs e brilho do mesmo tamanho', (tester) async {
    await tester.runAsync(() => CreatureArt.loadAll(_DiskBundle()));
    final art = CreatureArt.of('hum.eco')!;
    expect(art.frame, mapEcoPx, reason: '28 px: o tamanho do Eco na grade de 2 dp');
    expect(art.anims.keys.toSet(), CreatureAnim.values.toSet(), reason: 'parado, deriva, alerta, fuga, nascer, sintonizado');
    for (final e in art.anims.entries) {
      final s = e.value;
      expect((s.body.width, s.body.height), (s.frames * art.frame, art.frame), reason: e.key.name);
      for (final layer in [s.leds, s.glow]) {
        expect(layer, isNotNull, reason: '${e.key.name}: as três camadas');
        expect((layer!.width, layer.height), (s.body.width, s.body.height), reason: e.key.name);
      }
    }
    expect(art.portrait!.body.height, 96);
    expect(art.portrait!.frames, greaterThanOrEqualTo(4));
  });

  testWidgets('cada variante é distinta das outras e da comum em escala de cinza', (tester) async {
    await tester.runAsync(() => CreatureArt.loadAll(_DiskBundle()));
    final art = CreatureArt.of('hum.eco')!;
    final keys = (jsonDecode(File('assets/art/creatures/humoth/humoth_variants.json').readAsStringSync()) as Map<String, dynamic>).keys.toList();
    expect(keys.toSet(), {'urban', 'green', 'water', 'residential', 'lit', 'sacred', 'crimson'});
    // A luminância do quadro 0 do `idle` de cada aparência (transparente = -1).
    Future<List<double>> gray(ui.Image img) async {
      final b = (await tester.runAsync(() => img.toByteData()))!;
      return [
        for (var y = 0; y < art.frame; y++)
          for (var x = 0; x < art.frame; x++)
            if (b.getUint8((y * img.width + x) * 4 + 3) < 128) -1.0 else 0.299 * b.getUint8((y * img.width + x) * 4) + 0.587 * b.getUint8((y * img.width + x) * 4 + 1) + 0.114 * b.getUint8((y * img.width + x) * 4 + 2),
      ];
    }

    final looks = {'comum': await gray(art.anims[CreatureAnim.idle]!.body), for (final k in keys) k: await gray(art.bodyOf(CreatureAnim.idle, k))};
    final names = looks.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final a = looks[names[i]]!, b = looks[names[j]]!;
        // Pixels que diferem bem em cinza (valor) ou em presença (o acessório muda a silhueta).
        var differ = 0;
        for (var p = 0; p < a.length; p++) {
          if ((a[p] < 0) != (b[p] < 0) || (a[p] >= 0 && (a[p] - b[p]).abs() > 24)) differ++;
        }
        expect(differ, greaterThanOrEqualTo(12), reason: '${names[i]} × ${names[j]} em cinza: só $differ pixels diferentes');
      }
    }
  });
}
