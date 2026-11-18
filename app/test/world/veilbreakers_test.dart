import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/veilbreaker_model.dart';
import 'package:kenoma/core/windows.dart';
import 'package:kenoma/world/npc_data.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/veilbreakers.dart';

import '../support/fixtures.dart';

/// 0.24.5 (docs/GDD.md, "Outros Veilbreakers"): NPCs gerados pela seed, iguais para amigos, que só sintonizam Ecos que já
/// iam sumir.
void main() {
  final data = NpcData.fromJson(loadJson('assets/data/npc.json'));
  final epochModel = loadEpochs().epochs.firstWhere((e) => e.id == 12).veilbreakers!;
  const seed = 0x5eed1234, mpc = 17.6;
  const x0 = 1550000.0, y0 = 1180000.0; // células z21
  const t0 = 1795800000 - 1795800000 % 900 + 900 * 4;

  // Ecos de teste em volta de (x0, y0): um por célula z20 vizinha, com janelas que fecham em instantes diferentes.
  List<WorldSpawn> ecos(int t) => [
        for (var i = 0; i < 24; i++)
          for (final w in [(t + windowOffset(seed, 775000 + i % 5, 590000 + i ~/ 5)) ~/ windowSeconds])
            WorldSpawn(uid: 9000 + i, kind: 'eco', entryId: 'soot.eco', quantity: 1, x: x0 + (i % 5) * 0.8 - 2, y: y0 + (i ~/ 5) * 0.8 - 2, cellX: 775000 + i % 5, cellY: 590000 + i ~/ 5, window: w, level: 3),
      ];

  VeilbreakerField field({int s = seed, VeilbreakerModel? model}) => VeilbreakerField(
        seed: s,
        modelAt: (_) => model ?? const VeilbreakerModel(baseChance: 1, tuneChance: 1, tuneMax: 3),
        epochAt: (_) => 12,
        biomeAt: (_, _) => 'lit',
        ecosNear: (x, y, t, r) => ecos(t),
        mpcAt: (_) => mpc,
        data: data,
      );

  int endOf(WorldSpawn e) => (e.window + 1) * windowSeconds - windowOffset(seed, e.cellX, e.cellY);

  test('dois aparelhos com a mesma seed veem os mesmos NPCs no mesmo lugar e hora; outra seed, outros', () {
    String trace(VeilbreakerField f) => [
          for (var t = t0; t < t0 + 3600; t += 450)
            for (final v in f.around(x0, y0, t, 300)) '${v.id}:${v.school}:${v.outfit}:${v.at(t + 0.5).x.toStringAsFixed(4)},${v.at(t + 0.5).y.toStringAsFixed(4)}:${v.tunes.map((u) => '${u.eco.uid}@${u.atUtc}').join('+')}',
        ].join('|');
    final a = trace(field());
    expect(a, isNotEmpty);
    expect(trace(field()), a, reason: 'o segundo aparelho, com cache vazio');
    expect(trace(field(s: seed + 1)), isNot(a));
  });

  test('só sintoniza Ecos cuja janela já ia fechar dentro da fatia, e o Eco some só depois da animação', () {
    final f = field();
    final vs = [for (var t = t0; t < t0 + 4 * 900; t += 900) ...f.inCell((x0 / 8).floor(), (y0 / 8).floor(), t ~/ 900, const VeilbreakerModel(baseChance: 1, tuneChance: 1, tuneMax: 3))];
    final tunes = [for (final v in vs) for (final u in v.tunes) (v, u)];
    expect(tunes, isNotEmpty);
    const m = VeilbreakerModel();
    for (final (v, u) in tunes) {
      expect(u.atUtc, endOf(u.eco) - m.tuneLeadS.round(), reason: 'some ${m.tuneLeadS} s antes de a janela fechar');
      expect(u.atUtc, inInclusiveRange(v.startUtc, v.endUtc - 1), reason: 'dentro da fatia do NPC');
      expect(f.tunedAt(u.eco, u.atUtc), u.atUtc);
      expect(f.goneAt(u.eco, u.atUtc, playerDistM: 500), isFalse, reason: 'a animação ainda está correndo');
      expect(f.goneAt(u.eco, u.atUtc + 2, playerDistM: 500), isTrue);
      expect(f.goneAt(u.eco, u.atUtc + 2, playerDistM: 10), isFalse, reason: 'nunca na frente do jogador');
    }
    // Um Eco que ninguém sintoniza continua até o fim da janela.
    final tuned = {for (final (_, u) in tunes) u.eco.uid};
    final free = ecos(t0).where((e) => !tuned.contains(e.uid) && endOf(e) > t0 + 4 * 900 + 200);
    for (final e in free) {
      expect(f.goneAt(e, t0, playerDistM: 500), isFalse);
    }
  });

  test('o NPC para enquanto sintoniza e anda pelo caminho no resto da fatia', () {
    final f = field();
    final v = f.inCell((x0 / 8).floor(), (y0 / 8).floor(), t0 ~/ 900, const VeilbreakerModel(baseChance: 1, tuneChance: 1, tuneMax: 3)).first;
    final walking = v.at(v.startUtc + 30.0);
    expect(walking.walking, isTrue);
    if (v.tunes.isNotEmpty) {
      final u = v.tunes.first;
      final a = v.at(u.atUtc - 1.0), b = v.at(u.atUtc + 1.0);
      expect((a.walking, b.walking), (false, false));
      expect((a.x, a.y), (b.x, b.y), reason: 'parado no mesmo lugar');
      expect(v.tuningAt(u.atUtc + 0.5), u);
    }
  });

  test('de madrugada quase ninguém; no fim da tarde mais, com o modelo da época 12', () {
    final f = field(model: epochModel);
    int count(int localHour) {
      // Um dia qualquer: o instante UTC dessa hora local (UTC-3).
      final t = 1795737600 + (localHour + 3) * 3600;
      var n = 0;
      for (var j = 0; j < 40; j++) {
        for (var i = 0; i < 40; i++) {
          n += f.inCell(190000 + i, 147000 + j, t ~/ 900, epochModel).where((v) => v.known == null).length;
        }
      }
      return n;
    }

    final night = count(3), evening = count(18);
    expect(evening, greaterThan(night * 10), reason: 'madrugada $night, fim da tarde $evening');
    expect(evening, lessThan(1600 * 0.4), reason: 'densidade baixa');
  });

  test('os conhecidos aparecem só nos dias e horas da rotina deles', () {
    final f = field();
    final k = data.known.first;
    for (var d = 0; d < 7; d++) {
      for (var h = 0; h < 24; h++) {
        final t = 1795737600 + d * 86400 + (h + 3) * 3600 + 60; // hora local h
        final wd = VeilbreakerField.localWeekday(t);
        final seen = <String>{};
        for (var j = 0; j < 8; j++) {
          for (var i = 0; i < 8; i++) {
            for (final v in f.inCell(190000 + i, 147000 + j, t ~/ 900, const VeilbreakerModel(baseChance: 0, knownPerTile: 8))) {
              if (v.known != null) seen.add(v.id);
            }
          }
        }
        expect(seen.contains(k.id), k.activeAt(wd, VeilbreakerField.localHour(t)), reason: '${k.id} no dia $wd às $h h');
      }
    }
  });

  test('0.25.0: o caminho segue a calçada da rua (dobra na esquina) em vez de cortar em reta', () {
    // Uma rua em L com a esquina perto da célula do NPC: 6 m de largura, calçada a 4,2 m do eixo.
    final cx = (x0 / 8).floor(), cy = (y0 / 8).floor();
    final corner = (cx * 8 + 6.0, cy * 8 + 6.0);
    final road = [(corner.$1 - 20, corner.$2), corner, (corner.$1, corner.$2 + 20)];
    final f = VeilbreakerField(
      seed: seed,
      modelAt: (_) => const VeilbreakerModel(baseChance: 1),
      epochAt: (_) => 12,
      biomeAt: (_, _) => 'lit',
      ecosNear: (_, _, _, _) => const [],
      mpcAt: (_) => mpc,
      data: data,
      roadsNear: (_, _, _) => [(pts: road, halfM: 3)],
    );
    double distToRoad(double x, double y) {
      var best = double.infinity;
      for (var i = 0; i + 1 < road.length; i++) {
        final (ax, ay) = road[i];
        final (bx, by) = road[i + 1];
        final dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy;
        final t = (((x - ax) * dx + (y - ay) * dy) / l2).clamp(0.0, 1.0);
        best = math.min(best, math.sqrt(math.pow(ax + dx * t - x, 2) + math.pow(ay + dy * t - y, 2)));
      }
      return best * mpc;
    }

    var n = 0;
    for (var slot = 0; slot < 40; slot++) {
      for (final v in f.inCell(cx, cy, t0 ~/ 900 + slot, const VeilbreakerModel(baseChance: 1))) {
        for (var t = v.startUtc.toDouble(); t < v.endUtc; t += 3) {
          final p = v.at(t);
          final d = distToRoad(p.x, p.y);
          expect(d, inInclusiveRange(3.0, 6.1), reason: 'na calçada (fora da rua, sem cortar a esquina), a ${d.toStringAsFixed(1)} m do eixo');
          n++;
        }
      }
    }
    expect(n, greaterThan(100));
  });
}

