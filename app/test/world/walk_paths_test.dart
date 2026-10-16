import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/features.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/region_loader.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';

import '../support/fixtures.dart';

/// Época 2: Fagulhas e materiais nascem sobre o que dá para andar, os Ecos a no máximo 15 m, e a geometria usada é a do
/// pacote visual que a época fixa pelo SHA-256.
void main() {
  final bytes = Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync());
  final visual = VisualMap(VisualPack.parse(bytes), cacheTiles: 16);
  final paths = WalkPaths(visual);
  final schedule = loadEpochs();
  final e2 = schedule.epochs.firstWhere((e) => e.id == 2);
  final seed = seedGlobal('KENOMA-TESTE');
  final (clat, clon) = kCentroCampinas;
  final (c0x, c0y) = spawnCellAt(clat, clon);

  /// Distância, em frações de célula, do ponto ao segmento mais próximo da célula.
  double distToPaths(int cx, int cy, double px, double py) {
    final s = paths.segments(cx, cy);
    var best = double.infinity;
    for (var i = 0; i < s.length; i += 4) {
      final dx = s[i + 2] - s[i], dy = s[i + 3] - s[i + 1];
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - s[i]) * dx + (py - s[i + 1]) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      best = math.min(best, math.sqrt(math.pow(px - (s[i] + t * dx), 2) + math.pow(py - (s[i + 1] + t * dy), 2)));
    }
    return best;
  }

  test('o pacote visual é o fixado pela época 2 (a geometria do mundo não muda sem época nova)', () {
    final ref = e2.visualPacks['campinas']!;
    expect(sha256Hex(bytes), ref.sha256);
    expect(e2.walkable?.ecoOffPathM, 15);
  });

  test('Fagulhas e materiais caem no caminho; Ecos a até 15 m; célula sem caminho fica como o sorteio', () {
    var snappedItems = 0, rawCells = 0, ecos = 0;
    for (var dx = -25; dx <= 25; dx++) {
      for (var dy = -25; dy <= 25; dy++) {
        final cx = c0x + dx, cy = c0y + dy;
        final withSnap = generateCell(seed: seed, epoch: e2, cellX: cx, cellY: cy, window: 1491700, biomeKey: 'urban', snapper: paths);
        final raw = generateCell(seed: seed, epoch: e2, cellX: cx, cellY: cy, window: 1491700, biomeKey: 'urban');
        final (lat, _) = tileFractionToLatLon(cx + 0.5, cy + 0.5, spawnZoom);
        final mPerFrac = metersPerCell(lat, zoom: spawnZoom);
        if (paths.segments(cx, cy).isEmpty) {
          rawCells++;
          for (var i = 0; i < raw.length; i++) {
            expect((withSnap[i].px, withSnap[i].py), (raw[i].px, raw[i].py));
          }
          continue;
        }
        for (var i = 0; i < raw.length; i++) {
          final it = withSnap[i];
          expect((it.exists, it.entryId, it.uid), (raw[i].exists, raw[i].entryId, raw[i].uid), reason: 'só a posição muda');
          expect(it.px, inInclusiveRange(0, 1));
          expect(it.py, inInclusiveRange(0, 1));
          final d = distToPaths(cx, cy, it.px, it.py) * mPerFrac;
          if (it.kind == 'eco') {
            ecos++;
            expect(d, lessThanOrEqualTo(15.001), reason: 'Eco a ${d.toStringAsFixed(1)} m do caminho em $cx,$cy');
          } else {
            snappedItems++;
            expect(d, lessThan(0.001), reason: 'item a ${d.toStringAsFixed(3)} m do caminho em $cx,$cy');
          }
        }
      }
    }
    expect(snappedItems, greaterThan(1000));
    expect(ecos, greaterThan(100));
    expect(rawCells, greaterThanOrEqualTo(0));
  });

  test('é determinístico: dois leitores independentes do pacote dão exatamente os mesmos pontos', () {
    final other = WalkPaths(VisualMap(VisualPack.parse(bytes), cacheTiles: 4), cacheCells: 8);
    for (var dx = -6; dx <= 6; dx++) {
      for (var dy = -6; dy <= 6; dy++) {
        final a = generateCell(seed: seed, epoch: e2, cellX: c0x + dx, cellY: c0y + dy, window: 1491701, biomeKey: 'green', snapper: paths);
        final b = generateCell(seed: seed, epoch: e2, cellX: c0x + dx, cellY: c0y + dy, window: 1491701, biomeKey: 'green', snapper: other);
        expect([for (final i in a) (i.px, i.py)], [for (final i in b) (i.px, i.py)]);
      }
    }
  });

  test('as épocas 0 e 1 não usam caminhos: o snapper não muda nada nelas', () {
    for (final id in [0, 1]) {
      final e = schedule.epochs.firstWhere((e) => e.id == id);
      expect(e.walkable, isNull);
      final a = generateCell(seed: seed, epoch: e, cellX: c0x, cellY: c0y, window: 1491700, biomeKey: 'urban');
      final b = generateCell(seed: seed, epoch: e, cellX: c0x, cellY: c0y, window: 1491700, biomeKey: 'urban', snapper: paths);
      expect([for (final i in a) (i.px, i.py)], [for (final i in b) (i.px, i.py)]);
    }
  });

  test('a época 3 (Rua viva) só existe com a funcionalidade ligada: a 0.13.1 não a conhece', () {
    expect(schedule.epochs.map((e) => e.id), [0, 1, 2, 3]);
    final before = streetLifeEnabled;
    addTearDown(() => streetLifeEnabled = before);
    streetLifeEnabled = false;
    final off = EpochSchedule.fromJson(epochsJson());
    expect(off.epochs.map((e) => e.id), [0, 1, 2]);
    expect(off.epochs.every((e) => e.ecoV2 == null), isTrue);
  });
}
