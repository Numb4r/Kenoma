import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';

import '../support/fixtures.dart';
import '../support/walk_sim.dart';

/// Metas de densidade da época 1, medidas andando a 1,4 m/s por Barão Geraldo (docs/fase0-spec.md, seção 3).
/// A Aura tem 25 m e a visão 120 m, do `balance.json`. As caminhadas saem da Unicamp em 8 rumos e 2 horários.
void main() {
  // Só até a época 1: as metas de densidade são dela, e a época 2 muda o hash do mundo.
  final schedule = EpochSchedule([for (final e in loadEpochs().epochs) if (e.id <= 1) e]);
  final aura = (loadJson('assets/data/balance.json')['map'] as Map<String, dynamic>)['aura_m'] as num;
  final epoch1 = schedule.epochs.firstWhere((e) => e.id == 1);

  test('a época 0 não mudou: o que ela usa é o que foi publicado', () {
    final e0 = schedule.epochs.firstWhere((e) => e.id == 0);
    expect(e0.items.map((i) => i.chance['urban']).toList(), [0.1, 0.25, 0.125, 0.12]);
    expect(e0.items.map((i) => i.chance['residential']).toList(), [0.08, 0.25, 0.125, 0.12]);
  });

  test('a época 1 usa o mesmo pacote de região e o mesmo pacote visual, e os mesmos pesos por bioma', () {
    final e0 = (epochsJson()['epochs'] as List)[0] as Map<String, dynamic>;
    final e1 = (epochsJson()['epochs'] as List)[1] as Map<String, dynamic>;
    expect(e1['region_packs'], e0['region_packs']);
    expect(e1['visual_packs'], e0['visual_packs']);
    for (var i = 0; i < 4; i++) {
      final a = (e0['spawn']['items'] as List)[i] as Map<String, dynamic>;
      final b = (e1['spawn']['items'] as List)[i] as Map<String, dynamic>;
      expect(b['table'], a['table'], reason: 'item $i: mudam só as chances');
      expect(b['qty'], a['qty']);
    }
    expect(epoch1.startsUtc, greaterThan(schedule.epochs.first.startsUtc));
  });

  group('metas, andando a 1,4 m/s', () {
    final stats = <WalkStats>[];
    setUpAll(() {
      for (final h in [0, 45, 90, 135, 180, 225, 270, 315]) {
        for (final off in [0, 7]) {
          stats.add(walk(schedule: schedule, t0: epoch1.startsUtc + 3600 * 5 + off * 3600 + h * 600, headingDeg: h.toDouble(), auraM: aura.toDouble()));
        }
      }
    });

    double avg(double Function(WalkStats) f) => stats.map(f).reduce((a, b) => a + b) / stats.length;
    double meanOf(List<int> v) => v.reduce((a, b) => a + b) / v.length;

    test('de 3 a 5 Ecos dentro de 120 m na maior parte do tempo', () {
      expect(avg((w) => meanOf(w.ecosIn120)), inInclusiveRange(3.5, 5.5));
      expect(avg((w) => w.fractionIn(w.ecosIn120, 3, 5)), greaterThanOrEqualTo(0.45));
      expect(avg((w) => w.fractionIn(w.ecosIn120, 2, 6)), greaterThanOrEqualTo(0.7));
    });

    test('um Eco novo ao alcance da Aura a cada 1 ou 2 minutos', () {
      final gaps = [for (final w in stats) w.meanEcoGapS]..sort();
      expect(gaps[gaps.length ~/ 2], lessThanOrEqualTo(150), reason: 'mediana das caminhadas');
      expect(gaps[(gaps.length * 0.9).floor()], lessThanOrEqualTo(300), reason: 'as piores caminhadas não passam de 5 min');
    });

    test('Fagulhas e materiais: de 8 a 12 na tela na maior parte do tempo', () {
      expect(avg((w) => meanOf(w.screenItems)), inInclusiveRange(8, 12));
      expect(avg((w) => w.fractionIn(w.screenItems, 8, 12)), greaterThanOrEqualTo(0.45));
      expect(avg((w) => w.fractionIn(w.screenItems, 4, 14)), greaterThanOrEqualTo(0.9), reason: 'nunca fica vazio');
    });
  });
}
