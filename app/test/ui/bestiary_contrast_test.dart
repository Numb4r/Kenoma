import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/menu/screen_frame.dart' show kBacklightCenter, kBacklightRim;

/// O contraste do sprite contra a célula do Bestiário (26/nov: Umbrel e Shadekin quase sumiam). Mede, em cada pixel da
/// borda da silhueta (o contorno, quase sempre `#1a1424`), a razão de contraste WCAG contra o fundo atrás dele, e fica com
/// a mediana. De noite com as camadas emissivas por cima, de dia só o corpo. O fundo é a luz de [kBacklightCenter] no meio
/// até [kBacklightRim] na borda, como o `RadialGradient` de raio 0,5 do `SpeciesImage`.
void main() {
  const cell = Color(0xFF120E1A); // o miolo do `cell.png` do kit, o fundo de antes

  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double ratio(Color a, Color b) {
    final (x, y) = (lum(a), lum(b));
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  Color backlight(int x, int y, int side) {
    final d = math.min(1.0, math.sqrt(math.pow(x + 0.5 - side / 2, 2) + math.pow(y + 0.5 - side / 2, 2)) / (side / 2));
    return Color.lerp(kBacklightCenter, kBacklightRim, d)!;
  }

  Future<List<Color?>> frame0(WidgetTester tester, String path, int side, List<String> over) async {
    Future<ByteData> rgba(String p) async {
      final codec = await ui.instantiateImageCodec(await File(p).readAsBytes());
      return (await (await codec.getNextFrame()).image.toByteData())!;
    }

    final layers = [await tester.runAsync(() => rgba(path)), for (final o in over) await tester.runAsync(() => rgba(o))];
    final widths = [for (final p in [path, ...over]) (await tester.runAsync(() async => (await (await ui.instantiateImageCodec(await File(p).readAsBytes())).getNextFrame()).image.width))!];
    final out = List<Color?>.filled(side * side, null);
    for (var l = 0; l < layers.length; l++) {
      final b = layers[l]!, w = widths[l];
      for (var y = 0; y < side; y++) {
        for (var x = 0; x < side; x++) {
          final i = (y * w + x) * 4;
          if (b.getUint8(i + 3) < 128) continue;
          out[y * side + x] = Color.fromARGB(255, b.getUint8(i), b.getUint8(i + 1), b.getUint8(i + 2));
        }
      }
    }
    return out;
  }

  /// A mediana do contraste na borda da silhueta contra [bg].
  double edge(List<Color?> px, int side, Color Function(int x, int y) bg) {
    final v = <double>[];
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final c = px[y * side + x];
        if (c == null) continue;
        bool empty(int a, int b) => a < 0 || b < 0 || a >= side || b >= side || px[b * side + a] == null;
        if (empty(x + 1, y) || empty(x - 1, y) || empty(x, y + 1) || empty(x, y - 1)) v.add(ratio(c, bg(x, y)));
      }
    }
    v.sort();
    return v[v.length ~/ 2];
  }

  final index = jsonDecode(File('assets/art/creatures/index.json').readAsStringSync()) as Map<String, dynamic>;
  final folders = {for (final e in (index['species'] as Map<String, dynamic>).values) (e as Map<String, dynamic>)['folder'] as String};
  final sparks = (jsonDecode(File('assets/art/sparks/sparks.json').readAsStringSync())['types'] as Map<String, dynamic>).keys;

  testWidgets('toda criatura e toda Fagulha se lê na célula, de dia e de noite, e melhor que no fundo antigo', (tester) async {
    final rows = <(String, String, int, List<String>)>[
      for (final f in folders)
        (f, 'assets/art/creatures/$f/${f}_portrait.png', (jsonDecode(File('assets/art/creatures/$f/$f.json').readAsStringSync())['portrait']['frame'] as int),
            [for (final l in ['glow', 'leds']) if (File('assets/art/creatures/$f/${f}_portrait_$l.png').existsSync()) 'assets/art/creatures/$f/${f}_portrait_$l.png']),
      for (final t in sparks) ('spark_$t', 'assets/art/sparks/spark_$t.png', 12, [if (File('assets/art/sparks/spark_${t}_glow.png').existsSync()) 'assets/art/sparks/spark_${t}_glow.png']),
    ];
    final weak = <String>[];
    for (final (name, body, side, over) in rows) {
      for (final night in [true, false]) {
        final px = await frame0(tester, body, side, night ? over : const []);
        final now = edge(px, side, (x, y) => backlight(x, y, side)), before = edge(px, side, (_, _) => cell);
        if (now < 1.3) weak.add('$name ${night ? 'noite' : 'dia'} ${now.toStringAsFixed(2)}');
        if (now < before && now < 1.5) weak.add('$name ${night ? 'noite' : 'dia'} piorou: ${before.toStringAsFixed(2)} -> ${now.toStringAsFixed(2)}');
      }
    }
    expect(weak, isEmpty);
    expect(rows.any((r) => r.$1 == 'umbrel') && rows.any((r) => r.$1 == 'shadekin'), isTrue);
  });
}
