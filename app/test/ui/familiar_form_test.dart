import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/ui/sprites/familiar_sprite.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';

void main() {
  const colorOf = {School.sealer: 0xFF9B7BFF, School.technomancer: 0xFF5FD3C6, School.shaman: 0xFFFF7A45};

  /// A cor do corpo (a que mais aparece, fora o contorno `O`) numa grade de caracteres.
  int dominant(List<String> rows, Map<String, int> palette) {
    final n = <int, int>{};
    for (final r in rows) {
      for (final ch in r.split('')) {
        if (ch == '.' || ch == 'O') continue;
        n[palette[ch]!] = (n[palette[ch]!] ?? 0) + 1;
      }
    }
    return n.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  test('sem escola, a forma é a de antes; cada escola tem a cor dela como a dominante', () {
    expect(familiarPaletteFor(null), familiarPalette);
    expect(familiarRows(null).join(), isNot(contains('A')));
    expect(dominant(familiarRows(null), familiarPaletteFor(null)), 0xFF9B7BFF);
    for (final s in School.values) {
      expect(dominant(familiarRows(s), familiarPaletteFor(s)), colorOf[s], reason: s.id);
    }
  });

  test('cada escola tem o seu acessório de pixels, sobre fundo transparente ou corpo, e as formas são todas diferentes', () {
    final forms = <String>{familiarRows(null).join('\n')};
    for (final s in School.values) {
      final rows = familiarRows(s);
      expect(rows.length, mapPlayerPx);
      expect(rows.every((r) => r.length == mapPlayerPx), isTrue);
      expect('A'.allMatches(rows.join()).length, familiarAccessory[s]!.length, reason: s.id);
      forms.add(rows.join('\n'));
    }
    expect(forms.length, 4);
  });

  testWidgets('a imagem carrega sem erro nas três escolas e sem escola, e o pixel do corpo é o da escola', (tester) async {
    await tester.runAsync(() async {
      final base = await loadFamiliarImage();
      expect((base.width, base.height), (mapPlayerPx, mapPlayerPx));
      for (final s in School.values) {
        final img = await loadFamiliarImage(school: s);
        expect((img.width, img.height), (mapPlayerPx, mapPlayerPx));
        final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final counts = <int, int>{};
        for (var i = 0; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i + 3) == 0) continue;
          final argb = 0xFF000000 | (bytes.getUint8(i) << 16) | (bytes.getUint8(i + 1) << 8) | bytes.getUint8(i + 2);
          if (argb == 0xFF1A1424) continue; // contorno
          counts[argb] = (counts[argb] ?? 0) + 1;
        }
        final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        expect(top, colorOf[s], reason: s.id);
      }
    });
  });
}
