import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/data/cycle_pack.dart';
import 'package:kenoma/world/sim/traffic_sim_config.dart';
import 'package:kenoma/world/sim/cyclists.dart';

const mpc = 17.6;

void main() {
  // Uma ciclovia de 40 células (700 m) no eixo x e uma ciclofaixa numa rua no eixo y.
  final track = CycleLine(false, Float64List.fromList([1000, 2000, 1020, 2000, 1040, 2000]));
  final lane = CycleLine(true, Float64List.fromList([1010, 1990, 1010, 2010]));
  final pack = CyclePack([track, lane]);
  bool nowhere(double x, double y) => false;

  test('ciclistas só nas ciclovias, pela direita, de uma ponta à outra', () {
    final c = Cyclists(pack: pack);
    c.update(0.1, 1010, 2000, mpc, 1, nowhere);
    expect(c.riders.length, greaterThanOrEqualTo(3));
    for (var i = 0; i < 600; i++) {
      c.update(0.1, 1010, 2000, mpc, 1, nowhere);
      for (final r in c.riders) {
        if (identical(r.line, track)) {
          expect((r.y - 2000).abs() * mpc, closeTo(0.7, 1e-6), reason: 'na ciclovia');
          expect((r.y > 2000) == (r.dir > 0), isTrue, reason: 'pela direita de quem pedala (leste: o lado sul)');
          expect(r.x, inInclusiveRange(1000, 1040));
        } else {
          expect((r.x - 1010).abs() * mpc, closeTo(2.6, 1e-6), reason: 'na ciclofaixa, na borda da rua');
        }
      }
    }
    expect(c.riders.map((r) => r.line).toSet(), {track, lane});
  });

  test('sem ciclovia por perto, nenhum ciclista; a densidade manda', () {
    final far = Cyclists(pack: pack)..update(0.1, 5000, 5000, mpc, 1, nowhere);
    expect(far.riders, isEmpty);
    final none = Cyclists(pack: pack)..update(0.1, 1010, 2000, mpc, 0, nowhere);
    expect(none.riders, isEmpty);
    expect((Cyclists(pack: null)..update(0.1, 1010, 2000, mpc, 1, nowhere)).riders, isEmpty);
  });

  test('ninguém nasce nem some na vista; na ponta à vista, meia-volta', () {
    final c = Cyclists(pack: pack);
    bool view(double x, double y) => x > 1030 && x < 1050 && (y - 2000).abs() < 3; // a ponta leste está na tela
    c.update(0.1, 1010, 2000, mpc, 1, nowhere);
    var seen = {for (final r in c.riders) r.id: view(r.x, r.y)};
    var turned = 0;
    for (var i = 0; i < 4000; i++) {
      final dirs = {for (final r in c.riders) r.id: r.dir};
      c.update(0.1, 1010, 2000, mpc, 1, view);
      final now = {for (final r in c.riders) r.id: view(r.x, r.y)};
      for (final e in now.entries) {
        if (!seen.containsKey(e.key)) expect(e.value, isFalse, reason: 'nasceu na vista');
      }
      for (final e in seen.entries) {
        if (!now.containsKey(e.key)) expect(e.value, isFalse, reason: 'sumiu na vista');
      }
      for (final r in c.riders) {
        if (dirs[r.id] != null && dirs[r.id] != r.dir && view(r.x, r.y)) turned++;
      }
      seen = now;
    }
    expect(turned, greaterThan(0), reason: 'deu meia-volta na ponta que está na tela');
    expect(c.riders.length, greaterThanOrEqualTo(2), reason: 'a ciclovia continua com gente');
  });

  test('jogos do events.json assinado: só as entradas de jogo, em UTC; o resto é ignorado', () {
    final starts = matchStartsOf([
      {'kind': 'match', 'starts_utc': '2026-11-21T19:00:00Z'},
      {'kind': 'climate', 'climate': 'rain', 'starts_utc': '2026-11-21T19:00:00Z', 'ends_utc': '2026-11-21T22:00:00Z'},
      {'kind': 'match', 'starts_utc': 'amanhã'},
      {'kind': 'match', 'starts_utc': '2026-11-21T19:00:00'},
      {'kind': 'match'},
    ]);
    expect(starts, [DateTime.utc(2026, 11, 21, 19).millisecondsSinceEpoch ~/ 1000]);
    const c = TrafficSimConfig();
    expect(c.matchUtc, isEmpty, reason: 'o calendário do balance fica vazio');
    expect(c.matchAt(starts.single - 3600, starts), isTrue);
    expect(c.matchAt(starts.single - 3600), isFalse);
    expect(c.matchAt(starts.single + 1, starts), isFalse);
  });

  test('o arquivo de ciclovias de Campinas abre e tem ciclovias e ciclofaixas', () {
    final p = CyclePack.parse(File('assets/regions/campinas_e0_cycle.bin').readAsBytesSync());
    expect(p.lines.length, 665);
    expect(p.lines.where((l) => l.onRoad).length, 326);
  });

  test('formato CYC1', () {
    expect(() => CyclePack.parse(Uint8List.fromList([1, 2, 3, 4, 5])), throwsFormatException);
    expect(pack.linesIn(990, 1990, 1005, 2005), [track]);
    expect(math.sqrt(2), greaterThan(1));
  });
}
