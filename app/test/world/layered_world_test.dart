import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/nowalk_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/layered_world.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';

import '../support/fallback_fixtures.dart';
import '../support/fixtures.dart';

void main() {
  final biomes = loadBiomes();
  final schedule = loadEpochs();
  final seed = seedGlobal('KENOMA-TESTE');
  final pack = loadCampinasPack();
  final visual = VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()));
  final noWalk = NoWalkPack.parse(Uint8List.fromList(File('assets/regions/campinas_e2_nowalk.bin').readAsBytesSync()));
  final t = schedule.epochs.last.startsUtc + 3600;

  LayeredWorld world() => LayeredWorld(regions: [LoadedRegion(id: 'campinas', grid: pack, visual: visual, noWalk: noWalk)]);

  SpawnField field(RegionMap map, VisualMap vis, WalkPaths paths) => SpawnField(seed: seed, schedule: schedule, map: map, snapper: paths);

  // Um tile longe de Campinas (centro de São Paulo), sem pacote.
  const lat = -23.55, lon = -46.63;
  final (tx, ty) = latLonToTile(lat, lon, blockZoom);

  group('escolha da fonte por bloco', () {
    test('dentro do pacote: pack; com bloco: overpass; sem nada: floor', () {
      final w = world();
      expect(w.sourceAt(kCentroCampinas.$1, kCentroCampinas.$2), MapSourceKind.pack);
      expect(w.sourceAt(lat, lon), MapSourceKind.floor);
      w.putBlock(fakeBlock(tx, ty, 4));
      expect(w.sourceAt(lat, lon), MapSourceKind.overpass);
    });

    test('o pacote vence o bloco no mesmo tile, e a borda de fora fica com o bloco', () {
      final w = world();
      final x = pack.x0 + 1, y = pack.y0 + 1;
      final before = w.biomeAt(x, y);
      final (bx, by) = (x >>> 6, y >>> 6);
      expect(w.needsBlock(bx, by), isTrue, reason: 'o tile cruza a borda do pacote');
      w.putBlock(fakeBlock(bx, by, 4));
      expect(w.biomeAt(x, y), before);
      expect(w.sourceAtCell(x, y), MapSourceKind.pack);
      expect(w.biomeAt(pack.x0 - 1, pack.y0 + 1), kFakeBiome);
      expect(w.sourceAtCell(pack.x0 - 1, pack.y0 + 1), MapSourceKind.overpass);
    });

    test('tile todo dentro do pacote não pede bloco; o piso só vale onde não há dado nenhum', () {
      final w = world();
      final (cx, cy) = latLonToTile(kCentroCampinas.$1, kCentroCampinas.$2, blockZoom);
      expect(w.needsBlock(cx, cy), isFalse);
      expect(w.isFloorTile(cx, cy), isFalse);
      expect(w.isFloorTile(tx, ty), isTrue);
      w.putBlock(fakeBlock(tx, ty, 4));
      expect(w.isFloorTile(tx, ty), isFalse);
    });
  });

  test('Campinas idêntica: mesmo uid e posição que o RegionMap puro, com bloco fora do pacote carregado', () {
    final pureVis = VisualMap(visual);
    final pure = field(RegionMap(pack: pack, biomes: biomes), pureVis, WalkPaths(pureVis, blocked: noWalk));
    final w = world();
    final layeredVis = VisualMap(w);
    final layered = field(RegionMap(pack: w, biomes: biomes), layeredVis, WalkPaths(layeredVis, blocked: w));
    w.putBlock(fakeBlock(tx, ty, 4)); // sobe a revisão: refazer os caches não pode mudar nada
    final (c0x, c0y) = spawnCellAt(kCentroCampinas.$1, kCentroCampinas.$2);
    var compared = 0;
    for (var dy = -24; dy <= 24; dy += 4) {
      for (var dx = -24; dx <= 24; dx += 4) {
        final a = pure.cellItems(c0x + dx, c0y + dy, t), b = layered.cellItems(c0x + dx, c0y + dy, t);
        expect(b.length, a.length);
        for (var i = 0; i < a.length; i++) {
          expect((b[i].uid, b[i].px, b[i].py, b[i].exists, b[i].entryId), (a[i].uid, a[i].px, a[i].py, a[i].exists, a[i].entryId));
          compared++;
        }
      }
    }
    expect(compared, greaterThan(400));
    // E o mesmo na borda do pacote: a célula de spawn que cruza a borda continua igual sem bloco ali.
    final edgeX = pack.x0 ~/ 2, edgeY = (pack.y0 + pack.height ~/ 2) ~/ 2;
    final a = pure.cellItems(edgeX, edgeY, t), b = layered.cellItems(edgeX, edgeY, t);
    expect([for (final i in b) (i.uid, i.px, i.py, i.entryId)], [for (final i in a) (i.uid, i.px, i.py, i.entryId)]);
  });

  test('piso sem dados: Vazio spawna como Residencial, com a posição crua do sorteio', () {
    final w = world();
    final vis = VisualMap(w), paths = WalkPaths(vis, blocked: w), map = RegionMap(pack: w, biomes: biomes);
    final (cx, cy) = spawnCellAt(lat, lon);
    expect(map.spawnBiomeAtCell(cx, cy), voidBiomeId);
    expect(biomes.spawnKey(voidBiomeId), 'residential');
    expect(paths.snap(cx, cy, 0.3, 0.7), isNull, reason: 'sem via nenhuma, o ponto fica onde o sorteio o pôs');
    expect(paths.walkLengthM(cx, cy), isNull);
    final items = field(map, vis, paths).cellItems(cx, cy, t);
    expect(items, isNotEmpty);
  });

  test('a revisão refaz o bloco sem reiniciar: biomas, caminhos e spawns mudam quando o bloco chega', () {
    final w = world();
    final vis = VisualMap(w), paths = WalkPaths(vis, blocked: w), map = RegionMap(pack: w, biomes: biomes);
    final f = field(map, vis, paths);
    // A célula z20 que a rua do bloco falso cruza (metade do tile).
    final cx = tx * 32 + 3, cy = ty * 32 + 16;
    expect(vis.tile(tx, ty), isNull);
    expect(paths.segments(cx, cy), isEmpty);
    final before = f.cellItems(cx, cy, t);
    final rev = w.revision;
    w.putBlock(fakeBlock(tx, ty, 4));
    expect(w.revision, greaterThan(rev));
    expect(vis.tile(tx, ty)?.lines.length, 1);
    expect(paths.segments(cx, cy), isNotEmpty);
    expect(paths.walkLengthM(cx, cy), greaterThan(0));
    final after = f.cellItems(cx, cy, t);
    expect(identical(after, before), isFalse);
    expect(map.spawnBiomeAtCell(cx, cy), kFakeBiome);
    expect([for (final i in after) i.uid], [for (final i in before) i.uid], reason: 'o uid sai da célula, não do bioma');
  });

  test('blocos em memória têm limite; o mais antigo sai', () {
    final w = LayeredWorld(regions: [LoadedRegion(id: 'campinas', grid: pack, visual: visual)], maxBlocks: 2);
    for (var i = 0; i < 3; i++) {
      w.putBlock(fakeBlock(tx + i, ty, 4));
    }
    expect(w.block(tx, ty), isNull);
    expect(w.block(tx + 2, ty), isNotNull);
  });
}
