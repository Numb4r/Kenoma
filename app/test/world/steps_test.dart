import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/progression.dart' show localDay;
import 'package:kenoma/world/steps.dart';

import '../support/fixtures.dart';

void main() {
  const b = StepsBalance(perSpark: 1000, maxJump: 20000, dailyCap: 12000, milestones: [5000, 10000], bootToleranceS: 120);
  final epoch = loadEpochs().epochs.last;
  const day = 20000;
  const boot = 1790000000;
  StepReading at(int steps, [int bootUtc = boot]) => StepReading(steps, bootUtc);

  group('applySteps', () {
    test('primeira leitura só fixa a base', () {
      final r = applySteps(const StepState(), at(5000), b, day: day);
      expect((r.sparks, r.state.last, r.state.remainder, r.state.bootUtc), (0, 5000, 0, boot));
    });

    test('2.500 passos = 2 Fagulhas com resto 500; o resto acumula na leitura seguinte', () {
      var r = applySteps(const StepState(last: 10000, bootUtc: boot), at(12500), b, day: day);
      expect((r.sparks, r.state.remainder), (2, 500));
      r = applySteps(r.state, at(13000), b, day: day);
      expect((r.sparks, r.state.remainder), (1, 0));
    });

    test('teto diário: passa de 12 mil no dia e o resto não vira nada; no dia seguinte volta a contar', () {
      var s = const StepState(last: 0, bootUtc: boot);
      var sparks = 0;
      for (var n = 5000; n <= 20000; n += 5000) {
        final r = applySteps(s, at(n), b, day: day);
        sparks += r.sparks;
        s = r.state;
      }
      expect((sparks, s.converted, s.today), (12, 12000, 20000));
      final next = applySteps(s, at(21500), b, day: day + 1);
      expect((next.sparks, next.state.converted, next.state.today, next.state.remainder), (1, 1500, 1500, 500));
    });

    test('marcos de 5 e 10 mil saem uma vez por dia', () {
      var r = applySteps(const StepState(last: 0, bootUtc: boot), at(5200), b, day: day);
      expect(r.milestones, [5000]);
      r = applySteps(r.state, at(6000), b, day: day);
      expect(r.milestones, isEmpty);
      r = applySteps(r.state, at(19000), b, day: day);
      expect(r.milestones, [10000]);
      r = applySteps(r.state, at(24500), b, day: day + 1);
      expect(r.milestones, [5000], reason: 'dia novo');
    });

    test('reinício com a hora do boot: contam os passos desde o boot, mesmo andando mais que a leitura anterior', () {
      // A regra antiga ("leitura menor = reiniciou") erra aqui: reiniciou com 400, andou até 3.000, e 3.000 > 400.
      final r = applySteps(const StepState(last: 400, remainder: 700, bootUtc: boot), at(3000, boot + 86400), b, day: day);
      expect((r.sparks, r.state.last, r.state.remainder, r.state.bootUtc), (3, 3000, 700, boot + 86400));
    });

    test('mesmo boot (relógio acertado em segundos) não é reinício; leitura menor no mesmo boot não conta', () {
      final same = applySteps(const StepState(last: 1000, bootUtc: boot), at(2000, boot + 30), b, day: day);
      expect(same.sparks, 1);
      final lower = applySteps(const StepState(last: 9000, remainder: 300, bootUtc: boot), at(500), b, day: day);
      expect((lower.sparks, lower.state.last, lower.state.remainder), (0, 500, 300));
    });

    test('nunca em dobro: duas leituras iguais depois do reinício não repetem', () {
      var r = applySteps(const StepState(last: 90000, bootUtc: boot), at(1500, boot + 99), b, day: day);
      r = applySteps(r.state, at(1500, boot + 3600), b, day: day); // reinício
      expect(r.sparks, 1);
      r = applySteps(r.state, at(1500, boot + 3600), b, day: day);
      expect(r.sparks, 0);
    });

    test('save da 0.15 (sem boot guardado): leitura menor ainda é reinício, e o boot passa a ser guardado', () {
      final r = applySteps(const StepState(last: 90000, remainder: 700), at(400), b, day: day);
      expect((r.sparks, r.state.last, r.state.remainder, r.state.bootUtc), (1, 400, 100, boot));
    });

    test('salto absurdo é ignorado, inclusive depois de reinício, e a base avança', () {
      final r = applySteps(const StepState(last: 100, remainder: 300, bootUtc: boot), at(100 + 20001), b, day: day);
      expect((r.sparks, r.state.last, r.state.remainder), (0, 20101, 300));
      expect(applySteps(const StepState(last: 50000, bootUtc: boot), at(25000, boot + 9999), b, day: day).sparks, 0);
    });

    test('leitura igual não rende nada', () {
      expect(applySteps(const StepState(last: 10, remainder: 5, bootUtc: boot), at(10), b, day: day).sparks, 0);
    });
  });

  group('passos da Patrulha não contam duas vezes', () {
    test('o trecho da Patrulha sai da conta; o de outro boot não', () {
      const spans = [PatrolSpan(bootUtc: boot, from: 2000, to: 5000), PatrolSpan(bootUtc: boot - 86400, from: 0, to: 9000)];
      final r = applySteps(const StepState(last: 1000, bootUtc: boot), at(6000), b, day: day, patrol: spans);
      expect((r.sparks, r.state.converted, r.state.today), (2, 2000, 5000), reason: '5.000 andados, 3.000 na Patrulha');
    });

    test('Patrulha ainda ligada: o que passou do começo dela não conta, nem numa leitura seguinte', () {
      const spans = [PatrolSpan(bootUtc: boot, from: 3000)];
      var r = applySteps(const StepState(last: 1000, bootUtc: boot), at(4000), b, day: day, patrol: spans);
      expect(r.state.converted, 2000);
      r = applySteps(r.state, at(9000), b, day: day, patrol: spans);
      expect(r.state.converted, 2000);
      r = applySteps(r.state, at(10000), b, day: day, patrol: const [PatrolSpan(bootUtc: boot, from: 3000, to: 9500)]);
      expect(r.state.converted, 2500);
    });

    test('patrolOverlap nunca passa do trecho', () {
      expect(patrolOverlap(0, 100, boot, const [PatrolSpan(bootUtc: boot, from: 0), PatrolSpan(bootUtc: boot, from: 50, to: 80)], 120), 100);
    });
  });

  group('sparkForBiome', () {
    test('a Fagulha mais pesada do bioma; sem bioma ou bioma desconhecido, urban', () {
      expect(sparkForBiome(epoch, 'urban'), 'item.dust.fire');
      expect(sparkForBiome(epoch, 'green'), 'item.dust.plant');
      expect(sparkForBiome(epoch, 'water'), 'item.dust.water');
      expect(sparkForBiome(epoch, null), 'item.dust.fire');
      expect(sparkForBiome(epoch, 'lava'), 'item.dust.fire');
    });
  });

  group('StepTracker', () {
    GameState fresh() => GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance());
    const now = 1790000000;

    test('converte, guarda base e resto nos settings e registra o evento', () async {
      final s = fresh()..setSetting('last_biome', 'green');
      var reading = 1000;
      final t = StepTracker(state: s, balance: b, read: () async => at(reading), nowUtc: () => now);
      expect(await t.sync(epoch), 0);
      reading = 3500;
      expect(await t.sync(epoch), 2);
      expect(s.count('item.dust.plant'), 2);
      expect(s.settings['steps_rem'], 500);
      expect(s.story.count('steps'), 2);
      expect(stepsToday(s, localDay(now)), 2500);
    });

    test('save antigo com só steps_last e steps_rem continua valendo', () async {
      final s = fresh()
        ..setSetting('steps_last', 4000)
        ..setSetting('steps_rem', 900);
      final t = StepTracker(state: s, balance: b, read: () async => at(4200), nowUtc: () => now);
      expect(await t.sync(epoch), 1);
      expect(s.settings['steps_rem'], 100);
      expect(s.settings['steps_boot'], boot);
    });

    test('marco do dia vira fala do Familiar no chat', () async {
      final s = fresh();
      var reading = 0;
      final t = StepTracker(state: s, balance: b, read: () async => at(reading), nowUtc: () => now);
      await t.sync(epoch);
      reading = 5100;
      await t.sync(epoch);
      expect(s.story.chat.delivered.map((e) => e.id), ['steps_5k']);
      expect(loadGameData().mentor.byId('steps_5k')?.from, 'familiar');
    });

    test('trecho fechado da Patrulha some depois de descontado', () async {
      final s = fresh();
      setPatrolSpans(s, const [PatrolSpan(bootUtc: boot, from: 2000, to: 3000), PatrolSpan(bootUtc: boot, from: 9000)]);
      var reading = 1000;
      final t = StepTracker(state: s, balance: b, read: () async => at(reading), nowUtc: () => now);
      await t.sync(epoch);
      reading = 4000;
      expect(await t.sync(epoch), 2);
      expect(patrolSpansOf(s).map((p) => p.from), [9000]);
    });

    test('sem posição conhecida usa urban; sem sensor não faz nada', () async {
      final s = fresh();
      var reading = 0;
      final t = StepTracker(state: s, balance: b, read: () async => at(reading), nowUtc: () => now);
      await t.sync(epoch);
      reading = 1000;
      expect(await t.sync(epoch), 1);
      expect(s.count('item.dust.fire'), 1);
      expect(await StepTracker(state: s, balance: b, read: () async => null).sync(epoch), 0);
    });

    test('reset esquece a base', () async {
      final s = fresh();
      final t = StepTracker(state: s, balance: b, read: () async => at(5000), nowUtc: () => now);
      await t.sync(epoch);
      t.reset();
      expect(s.settings.containsKey('steps_last'), isFalse);
    });
  });
}
