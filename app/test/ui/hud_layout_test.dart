import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/climate_layers.dart' show screenLayerKinds;
import 'package:kenoma/ui/game/hud_layout.dart';

void main() {
  const sizes = [Size(360, 800), Size(412, 915), Size(480, 1000)];

  void expectNoOverlap(HudLayout l, Size s, String why) {
    final all = l.all.entries.toList();
    for (final e in all) {
      expect(e.value.left >= 0 && e.value.top >= 0 && e.value.right <= s.width && e.value.bottom <= s.height, isTrue, reason: '$why: ${e.key} fora da tela ${e.value}');
      expect(e.value.width >= 48 || e.key == 'marks', isTrue, reason: '$why: ${e.key} menor que o toque mínimo');
    }
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final a = all[i], b = all[j];
        expect(a.value.intersect(b.value).isEmpty, isTrue, reason: '$why: ${a.key} ${a.value} cobre ${b.key} ${b.value}');
      }
    }
  }

  test('nenhuma zona do HUD cobre outra nos três tamanhos, com tudo ligado e desligado', () {
    for (final s in sizes) {
      for (final insets in const [(0.0, 0.0), (24.0, 48.0)]) {
        for (var bits = 0; bits < 16; bits++) {
          final patrolOrRide = bits & 1 != 0, compass = bits & 2 != 0, radar = bits & 4 != 0, sim = bits & 8 != 0;
          final l = hudLayout(s, top: insets.$1, bottom: insets.$2, trackerMax: 4, marks: 9, shortcuts: patrolOrRide, compass: compass, radar: radar, simulator: sim);
          expectNoOverlap(l, s, '$s insets $insets patrulha/corrida=$patrolOrRide bússola=$compass radar=$radar simulador=$sim');
        }
      }
    }
  });

  test('os elementos do céu (lua, segunda lua da Lua Dupla, Sol Negro) ficam fora de todas as zonas do HUD, nos três tamanhos', () {
    for (final s in sizes) {
      for (final insets in const [(0.0, 0.0), (24.0, 48.0)]) {
        for (var bits = 0; bits < 16; bits++) {
          final l = hudLayout(s, top: insets.$1, bottom: insets.$2, trackerMax: 4, marks: 9, shortcuts: bits & 1 != 0, compass: bits & 2 != 0, radar: bits & 4 != 0, simulator: bits & 8 != 0);
          final why = '$s insets $insets bits $bits';
          expect(l.sky.keys, unorderedEquals(['moon', 'moon2', 'black_sun']));
          final sky = l.sky.entries.toList();
          for (final (i, e) in sky.indexed) {
            expect(e.value.left >= 0 && e.value.top >= 0 && e.value.right <= s.width && e.value.bottom <= s.height, isTrue, reason: '$why: ${e.key} fora da tela');
            for (final z in l.all.entries) {
              expect(e.value.intersect(z.value).isEmpty, isTrue, reason: '$why: ${e.key} ${e.value} fica embaixo de ${z.key} ${z.value}');
            }
            for (final o in sky.skip(i + 1)) {
              expect(e.value.intersect(o.value).isEmpty, isTrue, reason: '$why: ${e.key} cobre ${o.key}');
            }
          }
        }
      }
    }
    // O arco-íris não é mais da tela: é um objeto do mapa, desenhado por baixo do HUD (`rainbow_painter.dart`).
    expect(screenLayerKinds, isNot(contains('arc')));
  });

  test('as zonas ficam onde o pedido diz: bússola abaixo da barra à direita, faixa logo acima do celular, Radar acima do rastreador', () {
    final l = hudLayout(const Size(360, 800), compass: true, shortcuts: true, radar: true, simulator: true, marks: 3);
    expect(l.compass!.top, greaterThan(l.bar.bottom));
    expect(l.compass!.right, l.bar.right);
    expect(l.strip!.bottom, lessThan(l.phone.top));
    expect(l.strip!.center.dx, closeTo(l.phone.center.dx, 1e-9));
    expect(l.radar!.bottom, lessThan(l.tracker.top));
    expect(l.portrait.left, l.bar.left);
    expect(l.phone.center.dx, 180);
    expect(l.marks.height, 3 * HudSize.markH + 2 * HudSize.markGap);
    expect(l.tracker.height, 4 * HudSize.trackerEntry, reason: 'o rastreador cheio cabe sempre');
  });

  test('sem nada temporário a faixa some, e as marcações nunca passam do que cabe', () {
    final l = hudLayout(const Size(360, 800), marks: 40);
    expect(l.strip, isNull);
    expect(l.compass, isNull);
    expect(l.marksFit, lessThan(40));
    expect(l.marks.bottom, lessThan(l.portrait.top));
  });
}
