import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/cover_blocks.dart';
import 'package:kenoma/world/cover_field.dart';
import 'package:kenoma/world/street_cover.dart';
import 'package:kenoma/world/visual_map.dart';

const mpc = 17.6;

/// Um cruzamento em cruz no meio do bloco (0, 0), com uma viela que acaba no meio do quarteirão.
List<CoverStreet> cross({double level = 1, double wear = 0}) => [
      CoverStreet(const [-1, 2, 5, 2], 6, 3, level: level, wear: wear),
      CoverStreet(const [2, -1, 2, 5], 3, 1, level: level, wear: wear),
      CoverStreet(const [2, 3.2, 3.3, 3.2], 1, 0, level: level),
    ];

CoverBlock snow(double amount, {double peak = 1, bool melting = false, double wear = 0, double windX = 0, List<CoverStreet>? streets}) =>
    buildCover(CoverInput(bx: 0, by: 0, mpc: mpc, kind: StreetCoverKind.snow, amount: amount, peak: peak, melting: melting, seed: 9, streets: streets ?? cross(wear: wear), windX: windX, alpha: 0.9));

int at(double cx, double cy) => (cy * coverRes).floor() * coverSize + (cx * coverRes).floor();

void main() {
  test('máscara única: no cruzamento cada pixel tem uma superfície só e a união não deixa ponta nem círculo', () {
    final b = snow(1);
    expect(CoverSurface.values[b.surface[at(2, 2)]], CoverSurface.principal, reason: 'no cruzamento vale a rua maior');
    expect(CoverSurface.values[b.surface[at(2, 0.5)]], CoverSurface.local);
    expect(CoverSurface.values[b.surface[at(0.5, 0.5)]], CoverSurface.ground);
    expect(CoverSurface.values[b.surface[at(2.22, 0.5)]], CoverSurface.sidewalk);
    // A borda da união é contínua: ao longo da avenida, fora do cruzamento, a distância à borda é a mesma em todo x.
    final e0 = b.edge[at(0.5, 2.2)];
    for (var x = 0.2; x < 1.5; x += 0.1) {
      expect(b.edge[at(x, 2.2)], closeTo(e0, 0.05));
    }
    // Dentro do cruzamento não há borda nenhuma (as pontas das ruas não aparecem): tudo é dentro.
    for (var x = 1.9; x <= 2.1; x += 0.05) {
      for (var y = 1.9; y <= 2.1; y += 0.05) {
        expect(b.edge[at(x, y)], lessThan(0));
      }
    }
    // A imagem não soma camadas: duas ruas sobrepostas dão a mesma cor que uma só.
    final twice = snow(1, streets: [...cross(), ...cross()]);
    expect(twice.rgba, b.rgba);
  });

  test('gelo, fuligem e água: a cor do cruzamento é a mesma do resto da rua (sem mancha clara)', () {
    for (final kind in [StreetCoverKind.flood, StreetCoverKind.ice, StreetCoverKind.soot]) {
      final b = buildCover(CoverInput(bx: 0, by: 0, mpc: mpc, kind: kind, amount: 1, seed: 9, streets: cross(), color: 0xFF4AA8FF, alpha: 0.55));
      final alphas = <int>{};
      for (var i = 3; i < b.rgba.length; i += 4) {
        alphas.add(b.rgba[i]);
      }
      expect(alphas, {0, (0.55 * 255).round()}, reason: '${kind.name}: um só nível de opacidade, nada somado');
      expect(b.rgba[at(2, 2) * 4 + 3], (0.55 * 255).round());
      expect(b.rgba[at(0.5, 0.5) * 4 + 3], 0, reason: 'fora das ruas, nada');
    }
    final dry = buildCover(CoverInput(bx: 0, by: 0, mpc: mpc, kind: StreetCoverKind.flood, amount: 1, seed: 9, streets: cross(level: 0), color: 0xFF4AA8FF, alpha: 0.55));
    expect(dry.painted, 0, reason: 'rua que não alaga');
  });

  test('profundidade da neve: igual para o mesmo tempo, e chega primeiro na grama e por último nas avenidas', () {
    expect(snow(0.63).depth, snow(0.63).depth);
    expect(snow(0.63).rgba, snow(0.63).rgba);
    // A ordem: chão antes da calçada, calçada antes da rua local, rua local antes da avenida.
    double first(CoverSurface s) {
      for (var a = 0.0; a <= 1.0; a += 0.01) {
        if (snowBaseDepth(s, a) > 0.3) return a;
      }
      return 2;
    }

    final order = [CoverSurface.green, CoverSurface.ground, CoverSurface.sidewalk, CoverSurface.path, CoverSurface.local, CoverSurface.secondary, CoverSurface.principal].map(first).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i], greaterThan(order[i - 1]));
    }
    expect(snowBaseDepth(CoverSurface.water, 1), 0);
    final early = snow(0.4), mid = snow(0.7), full = snow(1);
    expect(early.depth[at(0.5, 0.5)], greaterThan(0.2));
    expect(early.depth[at(2, 0.5)], 0, reason: 'a rua ainda limpa');
    expect(mid.depth[at(2.1, 0.5)], greaterThan(0));
    expect(mid.depth[at(0.5, 2)], lessThan(0.05), reason: 'a avenida é a última');
    expect(full.depth[at(0.5, 2)], greaterThan(0.05));
    // Monotônico: mais tempo, mais neve em todo pixel (sem contar os bancos, que só crescem também).
    for (var i = 0; i < full.depth.length; i += 37) {
      expect(full.depth[i], greaterThanOrEqualTo(mid.depth[i] - 1e-6));
      expect(mid.depth[i], greaterThanOrEqualTo(early.depth[i] - 1e-6));
    }
  });

  test('o tráfego limpa as faixas: trilhas na avenida, mais fundas onde os carros passaram', () {
    final none = snow(1), worn = snow(1, wear: 1);
    final centre = at(0.5, 2), lane = at(0.5, 2 + 3 / mpc); // o meio da avenida e o meio de uma faixa
    expect(none.depth[lane], lessThan(none.depth[centre]), reason: 'a trilha é mais rasa que o meio da pista');
    expect(worn.depth[lane], lessThan(none.depth[lane]), reason: 'o tráfego local limpa mais');
    expect(worn.depth[centre], closeTo(none.depth[centre], 1e-6));
    // Na rua local quase nada.
    final local = at(2, 0.5);
    expect(none.depth[local] / 0.7, greaterThan(0.85));
  });

  test('bancos de neve nas bordas da rua, mais altos do lado para onde o vento sopra, e os últimos a derreter', () {
    final b = snow(1, windX: 1);
    double col(CoverBlock k, double x) => k.depth[at(x, 0.5)];
    final east = 2 + 3.4 / mpc, west = 2 - 3.4 / mpc; // logo fora do meio-fio da rua local
    expect(col(b, east), greaterThan(col(b, 2 + 8 / mpc) + 0.2), reason: 'o banco é mais alto que a neve do chão');
    expect(col(b, east), greaterThan(col(b, 2) + 0.4), reason: 'e que a neve da rua');
    expect(col(b, east), greaterThan(col(b, west) + 0.1), reason: 'o vento sopra para leste: o banco do lado leste é maior');
    // Contínuo ao longo da rua: nenhum buraco no banco.
    for (var y = 0.1; y < 1.4; y += 0.05) {
      expect(b.depth[at(east, y)], greaterThan(0.9));
    }
    expect(snowBankAmount(0.5, 1, false), 0, reason: 'sem neve na rua, sem banco');
    // Derretendo: as ruas limpam primeiro e os bancos ficam.
    final melt = snow(0.45, melting: true);
    expect(melt.depth[at(2, 0.5)], lessThan(0.02), reason: 'rua limpa');
    expect(melt.depth[at(0.5, 2)], lessThan(0.02));
    expect(melt.depth[at(east, 0.5)], greaterThan(0.4), reason: 'o banco continua');
    expect(snowBankAmount(1, 1, true), closeTo(snowBankAmount(1, 1, false), 1e-9), reason: 'sem salto na virada');
    expect(snow(0.1, melting: true).depth[at(east, 0.5)], lessThan(0.2), reason: 'no fim o banco também some');
  });

  test('bordas em pixel: pontilhado ordenado, sem meio-tom e sem contorno', () {
    final b = snow(0.3);
    final alphas = <int>{};
    for (var i = 3; i < b.rgba.length; i += 4) {
      alphas.add(b.rgba[i]);
    }
    expect(alphas.length, 2, reason: 'cada pixel está coberto ou não: a borda é do pontilhado');
    expect(b.painted, inExclusiveRange(coverSize * coverSize ~/ 20, coverSize * coverSize));
    expect({for (var y = 0; y < 4; y++) for (var x = 0; x < 4; x++) coverDither(x, y)}.length, 16);
  });

  test('neve funda fecha uma parte das ruas locais para os carros, só no fim da nevasca', () {
    const cover = StreetCover(kind: StreetCoverKind.snow, growS: 1800, share: {'local': 0.15});
    var closed = 0;
    for (var i = 0; i < 400; i++) {
      expect(cover.stateOf(7, (1, 2, i), RoadClass.local, 0, 900), StreetState.normal, reason: 'no meio da nevasca ninguém fecha');
      expect(cover.stateOf(7, (1, 2, i), RoadClass.principal, 0, 5000), StreetState.normal, reason: 'avenida não fecha');
      if (cover.stateOf(7, (1, 2, i), RoadClass.local, 0, 5000) == StreetState.blocked) closed++;
    }
    expect(closed, inInclusiveRange(30, 90));
  });

  test('desempenho: um bloco de Campinas fica pronto em poucos milissegundos', () {
    final vm = VisualMap(VisualPack.parse(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()), cacheTiles: 64);
    final (x, y) = latLonToTileFraction(-22.9056, -47.0608, 21);
    const cover = StreetCover(kind: StreetCoverKind.snow, growS: 1800, tracks: true);
    const widths = {'principal': 12.0, 'secondary': 9.0, 'local': 6.0, 'pedestrian': 2.0};
    final bx = x ~/ coverBlockCells, by = y ~/ coverBlockCells;
    for (var k = 0; k < 60; k++) {
      buildCover(coverInputOf(vm, bx + k % 5, by + k % 4, cover: cover, seed: 1, window: 0, amount: 1, mpc: mpc, roadWidthM: widths, windX: 1)); // aquece
    }
    final sw = Stopwatch()..start();
    var streets = 0, gather = 0;
    for (var k = 0; k < 20; k++) {
      final t0 = sw.elapsedMicroseconds;
      final input = coverInputOf(vm, bx + k % 5, by + k ~/ 5, cover: cover, seed: 1, window: 0, amount: 0.3 + k * 0.03, mpc: mpc, roadWidthM: widths, windX: 1);
      streets += input.streets.length;
      gather += sw.elapsedMicroseconds - t0;
      buildCover(input);
    }
    // ignore: avoid_print
    print('juntar as ruas: ${(gather / 20000).toStringAsFixed(2)} ms por bloco');
    final ms = sw.elapsedMicroseconds / 20000;
    // ignore: avoid_print
    print('bloco médio: ${ms.toStringAsFixed(2)} ms, ${streets ~/ 20} ruas por bloco');
    expect(ms, lessThan(30));
  });

  // Exporta um mosaico para conferir a olho: KENOMA_SHOTS=/pasta flutter test test/world/cover_field_test.dart
  test('mosaico de Campinas (só com KENOMA_SHOTS)', () {
    final dir = Platform.environment['KENOMA_SHOTS'];
    if (dir == null) return;
    final vm = VisualMap(VisualPack.parse(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()), cacheTiles: 64);
    final (x, y) = latLonToTileFraction(-22.9040, -47.0590, 21);
    const widths = {'principal': 12.0, 'secondary': 9.0, 'local': 6.0, 'pedestrian': 2.0};
    const w = 4, h = 5;
    final bx = x ~/ coverBlockCells - w ~/ 2, by = y ~/ coverBlockCells - h ~/ 2;
    void shot(String name, StreetCover cover, double amount, {double peak = 1, bool melting = false, int color = 0xFFFFFFFF, double alpha = 0.9, double wear = 0}) {
      final out = Uint8List(w * coverSize * h * coverSize * 3);
      for (var j = 0; j < h; j++) {
        for (var i = 0; i < w; i++) {
          final b = buildCover(coverInputOf(vm, bx + i, by + j, cover: cover, seed: 0x6ebe19ac6345175f, window: 0, amount: amount, peak: peak, melting: melting, mpc: mpc, roadWidthM: widths, windX: 0.8, windY: 0.6, color: color, alpha: alpha, wearOf: (k) => ((k.$3 * 7) % 4) / 3 * wear));
          for (var py = 0; py < coverSize; py++) {
            for (var px = 0; px < coverSize; px++) {
              final s = CoverSurface.values[b.surface[py * coverSize + px]];
              // O chão do jogo, de longe: asfalto escuro, calçada, quarteirão e grama.
              final base = switch (s) { CoverSurface.water => 0x2B4A6B, CoverSurface.green => 0x3F6B4A, CoverSurface.ground => 0x4A4458, CoverSurface.sidewalk => 0x6A6478, _ => 0x2A2536 };
              final k = (py * coverSize + px) * 4, a = b.rgba[k + 3] / 255;
              final o = ((j * coverSize + py) * w * coverSize + i * coverSize + px) * 3;
              out[o] = (((base >> 16) & 0xff) * (1 - a) + b.rgba[k]).round().clamp(0, 255);
              out[o + 1] = (((base >> 8) & 0xff) * (1 - a) + b.rgba[k + 1]).round().clamp(0, 255);
              out[o + 2] = ((base & 0xff) * (1 - a) + b.rgba[k + 2]).round().clamp(0, 255);
            }
          }
        }
      }
      File('$dir/$name.ppm').writeAsBytesSync([...'P6\n${w * coverSize} ${h * coverSize}\n255\n'.codeUnits, ...out]);
    }

    const snowC = StreetCover(kind: StreetCoverKind.snow, growS: 1800, tracks: true);
    shot('neve_1_comeco', snowC, 0.3);
    shot('neve_2_cobertura', snowC, 0.7);
    shot('neve_3_cheia', snowC, 1, wear: 1);
    shot('neve_4_ruas_limpas_bancos', snowC, 0.45, melting: true);
    shot('diluvio', const StreetCover(kind: StreetCoverKind.flood, share: {'principal': 0.5, 'secondary': 0.5, 'local': 0.5}), 1, color: 0xFF4AA8FF, alpha: 0.55);
    shot('gelo', const StreetCover(kind: StreetCoverKind.ice), 1, color: 0xFFBFE9F0, alpha: 0.4);
    shot('fuligem', const StreetCover(kind: StreetCoverKind.soot, share: {'principal': 1, 'secondary': 1}), 1, color: 0xFF2A2236, alpha: 0.55);
  });
}
