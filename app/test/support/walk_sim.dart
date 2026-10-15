import 'dart:math' as math;

import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';

import 'fixtures.dart';

/// O que uma caminhada simulada mediu.
class WalkStats {
  WalkStats({
    required this.ecosIn120,
    required this.screenItems,
    required this.auraEcoEntries,
    required this.seconds,
  });

  /// Ecos a até 120 m, uma amostra por segundo.
  final List<int> ecosIn120;

  /// Fagulhas e pontos de material dentro da tela (retângulo de 90 × 195 m), uma amostra por segundo.
  final List<int> screenItems;

  /// Segundos em que um Eco novo (uid nunca visto na Aura) entrou na Aura.
  final List<double> auraEcoEntries;
  final int seconds;

  double fractionIn(List<int> v, int lo, int hi) => v.where((x) => x >= lo && x <= hi).length / v.length;

  /// Tempo médio entre dois Ecos novos na Aura, em segundos.
  double get meanEcoGapS => seconds / math.max(1, auraEcoEntries.length);
}

const double _walkMps = 1.4;

/// Anda [seconds] a 1,4 m/s a partir de [start] no rumo [headingDeg] (0 = norte), a partir de [t0] UTC.
/// Fagulhas e materiais na Aura são coletados (somem), como no jogo; Ecos ficam, para contar só os novos.
WalkStats walk({
  required EpochSchedule schedule,
  required int t0,
  required double headingDeg,
  required double auraM,
  double viewM = 120,
  int seconds = 1800,
  (double, double) start = kUnicamp,
  String code = 'KENOMA-TESTE',
  RegionMap? map,
}) {
  final field = SpawnField(
    seed: seedGlobal(code),
    schedule: schedule,
    map: map ?? RegionMap(pack: loadCampinasPack(), biomes: loadBiomes()),
  );
  final h = headingDeg * math.pi / 180;
  final done = <int>{};
  final seenInAura = <int>{};
  final ecos = <int>[], items = <int>[];
  final entries = <double>[];
  var lat = start.$1, lon = start.$2;
  for (var s = 0; s < seconds; s++) {
    final mPerDegLat = 111320.0, mPerDegLon = 111320.0 * math.cos(lat * math.pi / 180);
    lat += _walkMps * math.cos(h) / mPerDegLat;
    lon += _walkMps * math.sin(h) / mPerDegLon;
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    final mpc = metersPerCell(lat);
    final all = field.around(lat: lat, lon: lon, tUtc: t0 + s, radiusM: viewM, playerLevel: 1);
    var eco120 = 0, onScreen = 0;
    for (final sp in all) {
      if (done.contains(sp.uid)) continue;
      final d = sp.distanceM(px, py, mpc);
      if (!sp.isEco && d <= auraM) {
        done.add(sp.uid);
        continue;
      }
      if (sp.isEco) {
        eco120++;
        if (d <= auraM && seenInAura.add(sp.uid)) entries.add(s.toDouble());
      } else if (((sp.x - px) * mpc).abs() <= 45 && ((sp.y - py) * mpc).abs() <= 97.5) {
        onScreen++;
      }
    }
    ecos.add(eco120);
    items.add(onScreen);
  }
  return WalkStats(ecosIn120: ecos, screenItems: items, auraEcoEntries: entries, seconds: seconds);
}
