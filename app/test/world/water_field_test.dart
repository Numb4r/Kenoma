import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/map_sources.dart';
import 'package:kenoma/data/relief_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/street_cover.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/water_field.dart';

/// Um relevo de fórmula: a altura (1/16 dm) de cada célula z21.
class Terrain implements ReliefSource {
  Terrain(this.f);
  final int Function(int x, int y) f;
  @override
  int? h16At(int cx, int cy) => f(cx, cy);
  @override
  double? heightAt(double x21, double y21) => f(x21.floor(), y21.floor()) / 160;
}

class Tiles implements VisualSource {
  Tiles([this.tiles = const {}]);
  final Map<(int, int), VisualTile> tiles;
  @override
  int get extent => 6400;
  @override
  int get tileZoom => 15;
  @override
  int get revision => 0;
  @override
  int get version => 2;
  @override
  bool hasTile(int x, int y) => tiles.containsKey((x, y));
  @override
  VisualTile? decode(int x, int y) => tiles[(x, y)];
}

const tx = 1000, ty = 1000, ox = tx * 64, oy = ty * 64;

void main() {
  test('a água para no ponto mais baixo: a poça fica no fundo da bacia', () {
    // Uma bacia redonda com o fundo em (20, 30) do tile.
    final w = WaterField(relief: Terrain((x, y) => ((x - ox - 20) * (x - ox - 20) + (y - oy - 30) * (y - oy - 30)) * 16), visual: VisualMap(Tiles()));
    final t = w.tile(tx, ty)!;
    final bottom = t.pool[30 * 64 + 20];
    expect(bottom, greaterThan(1024 * 100), reason: 'a água de toda a volta desce para lá');
    for (var i = 0; i < 64 * 64; i++) {
      if (i != 30 * 64 + 20) expect(t.pool[i], lessThan(bottom ~/ 3), reason: 'o fundo é de longe o que mais junta água');
    }
    final spots = w.spots(tx * 4 + 1, ty * 4 + 1, 3)!;
    expect((spots.first.x, spots.first.y), (ox + 20.5, oy + 30.5), reason: 'a poça mais funda é o fundo da bacia');
    expect(spots.first.depth, 1.0);
    expect(spots.skip(1).every((s) => s.depth < 0.34), isTrue);
    expect(w.poolAt(ox + 20, oy + 30), bottom);
  });

  test('igual em dois aparelhos, e o mesmo na emenda entre dois tiles', () {
    int hills(int x, int y) => (((x * 37 + y * 91) % 23) + ((x ~/ 5 + y ~/ 7) % 11) * 3 + (x - ox) * 2) * 16;
    final a = WaterField(relief: Terrain(hills), visual: VisualMap(Tiles())), b = WaterField(relief: Terrain(hills), visual: VisualMap(Tiles()));
    expect(a.tile(tx, ty)!.pool, b.tile(tx, ty)!.pool);
    expect(a.tile(tx, ty)!.flow, b.tile(tx, ty)!.flow);
    // A água que chega a uma célula não depende de em que tile ela foi calculada: a soma do que parou numa faixa que
    // atravessa a emenda é a mesma vista dos dois lados (cada célula pertence a um tile só e não há buraco nem dobra).
    final left = a.tile(tx, ty)!, right = a.tile(tx + 1, ty)!;
    expect(a.poolAt(ox + 63, oy + 10), left.pool[10 * 64 + 63]);
    expect(a.poolAt(ox + 64, oy + 10), right.pool[10 * 64]);
    // Um campo novo que só calcula o tile da direita dá o mesmo.
    final c = WaterField(relief: Terrain(hills), visual: VisualMap(Tiles()));
    expect(c.tile(tx + 1, ty)!.pool, right.pool);
  });

  test('ruas são canais com bueiro; rio leva a água embora; a margem alaga', () {
    // Um plano inclinado para o sul, com uma rua na diagonal e um lago embaixo.
    int slope(int x, int y) => (200 - (y - oy)) * 16 * 4;
    final plain = WaterField(relief: Terrain(slope), visual: VisualMap(Tiles()));
    final tile = VisualTile(lines: [
      VisualLine(RoadClass.principal, Int32List.fromList([1000, 0, 3000, 6400])),
    ], areas: [
      VisualArea(AreaKind.water, [Int32List.fromList([4000, 5000, 6000, 5000, 6000, 6000, 4000, 6000])]),
    ]);
    final w = WaterField(relief: Terrain(slope), visual: VisualMap(Tiles({(tx, ty): tile})));
    final t = w.tile(tx, ty)!, p = plain.tile(tx, ty)!;
    // Na rua (x = 20 na linha y = 32) passa muito mais água do que no plano sem rua, vinda dos lados.
    final onStreet = t.flow[32 * 64 + 20], off = t.flow[32 * 64 + 45];
    expect(onStreet, greaterThan(off));
    expect(onStreet, greaterThan(p.flow[32 * 64 + 20]) , reason: 'a rua junta a água dos vizinhos');
    // Dentro do lago nada para; a margem logo acima alaga no Dilúvio; longe dele, não.
    expect(t.pool[55 * 64 + 50], 0);
    expect(w.floodAt(ox + 50, oy + 48), 1.0);
    expect(w.floodAt(ox + 50, oy + 20), lessThan(1.0));
    expect(plain.floodAt(ox + 50, oy + 48), lessThan(1.0));
  });

  test('Dilúvio: alaga a rua que passa pela margem do lago, não a do alto do morro; o caminho de pedestre nunca', () {
    int slope(int x, int y) => (200 - (y - oy)) * 16 * 4;
    final tile = VisualTile(lines: [
      VisualLine(RoadClass.local, Int32List.fromList([4200, 4800, 5800, 4800])), // junto do lago
      VisualLine(RoadClass.local, Int32List.fromList([4200, 800, 5800, 800])), // no alto
      VisualLine(RoadClass.pedestrian, Int32List.fromList([4200, 4900, 5800, 4900])),
    ], areas: [
      VisualArea(AreaKind.water, [Int32List.fromList([4000, 5000, 6000, 5000, 6000, 6000, 4000, 6000])]),
    ]);
    final w = WaterField(relief: Terrain(slope), visual: VisualMap(Tiles({(tx, ty): tile})));
    expect(w.lineFloods(tx, ty, 0), isTrue);
    expect(w.lineFloods(tx, ty, 1), isFalse);
    final cover = const StreetCover(kind: StreetCoverKind.flood, share: {'local': 0}).withFloods((k) => w.lineFloods(k.$1, k.$2, k.$3));
    expect(cover.level(7, (tx, ty, 0), RoadClass.local, 0, 0.8), 0.8);
    expect(cover.level(7, (tx, ty, 1), RoadClass.local, 0, 0.8), 0);
    expect(cover.level(7, (tx, ty, 2), RoadClass.pedestrian, 0, 0.8), 0);
    expect(cover.stateOf(7, (tx, ty, 0), RoadClass.local, 0, 1e6), StreetState.flooded);
    // Sem relevo ali, vale o sorteio pela seed de antes.
    final none = const StreetCover(kind: StreetCoverKind.flood, share: {'local': 1}).withFloods((k) => null);
    expect(none.level(7, (tx, ty, 1), RoadClass.local, 0, 0.8), 0.8);
  });

  test('sem relevo no lugar não há campo (vale o sorteio antigo)', () {
    final w = WaterField(relief: Terrain((x, y) => 0), visual: VisualMap(Tiles()));
    expect(WaterField(relief: _None(), visual: VisualMap(Tiles())).tile(tx, ty), isNull);
    expect(w.spots(tx * 4, ty * 4, 3), isEmpty, reason: 'plano: a chuva sozinha, sem juntar água de lugar nenhum, não faz poça');
  });

  test('Campinas: poças nas baixadas de verdade, e o fundo do vale da Norte-Sul alaga', () {
    final vm = VisualMap(VisualPack.parse(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()), cacheTiles: 64);
    final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
    final w = WaterField(relief: relief, visual: vm);
    final sw = Stopwatch()..start();
    var puddles = 0, flooded = 0, cells = 0, tiles = 0;
    final hist = List.filled(5, 0);
    final (cx, cy) = latLonToTileFraction(-22.9056, -47.0608, 21);
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final t = w.tile(cx ~/ 64 + dx, cy ~/ 64 + dy)!;
        tiles++;
        for (var i = 0; i < 4096; i++) {
          cells++;
          for (final (k, th) in const [1100, 1200, 1536, 2048, 3072].indexed) {
            if (t.pool[i] >= th) hist[k]++;
          }
          if (t.pool[i] >= w.model.poolMin) puddles++;
          if (t.flood[i] >= 128) flooded++;
        }
      }
    }
    final ms = sw.elapsedMilliseconds / tiles;
    // ignore: avoid_print
    print('Centro, $tiles tiles: ${(puddles / tiles).toStringAsFixed(1)} poças por tile, ${(100 * flooded / cells).toStringAsFixed(1)}% das células alagam no Dilúvio, ${ms.toStringAsFixed(1)} ms por tile');
    // ignore: avoid_print
    print('poças por tile com limiar 1100/1200/1536/2048/3072: ${[for (final h in hist) (h / tiles).toStringAsFixed(1)]}');
    expect(puddles / tiles, inInclusiveRange(16, 400));
    expect(flooded / cells, inInclusiveRange(0.003, 0.25));
    // A água parada fica mais baixa que a média do terreno em volta dela.
    var lower = 0, total = 0;
    for (var y = cy.floor() - 64; y < cy.floor() + 64; y++) {
      for (var x = cx.floor() - 64; x < cx.floor() + 64; x++) {
        if (w.poolAt(x, y) < w.model.poolMin) continue;
        total++;
        var sum = 0, n = 0;
        for (var j = -6; j <= 6; j += 3) {
          for (var i = -6; i <= 6; i += 3) {
            sum += relief.h16At(x + i, y + j)!;
            n++;
          }
        }
        if (relief.h16At(x, y)! <= sum / n) lower++;
      }
    }
    expect(total, greaterThan(3));
    expect(lower / total, greaterThan(0.7));
  });
}

class _None implements ReliefSource {
  @override
  int? h16At(int cx, int cy) => null;
  @override
  double? heightAt(double x21, double y21) => null;
}
