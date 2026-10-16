import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/steps.dart';

import '../support/fixtures.dart';

void main() {
  const b = StepsBalance(perSpark: 1000, maxJump: 20000);
  final epoch = loadEpochs().epochs.last;

  group('applySteps', () {
    test('primeira leitura só fixa a base', () {
      final r = applySteps(const StepState(), 5000, b);
      expect((r.sparks, r.state.last, r.state.remainder), (0, 5000, 0));
    });

    test('2.500 passos = 2 Fagulhas com resto 500; o resto acumula na leitura seguinte', () {
      var r = applySteps(const StepState(last: 10000), 12500, b);
      expect((r.sparks, r.state.remainder), (2, 500));
      r = applySteps(r.state, 13000, b);
      expect((r.sparks, r.state.remainder), (1, 0));
    });

    test('reboot (leitura menor): contam os passos desde o boot', () {
      final r = applySteps(const StepState(last: 90000, remainder: 700), 400, b);
      expect((r.sparks, r.state.last, r.state.remainder), (1, 400, 100));
    });

    test('salto absurdo é ignorado, inclusive depois de reboot, e a base avança', () {
      final r = applySteps(const StepState(last: 100, remainder: 300), 100 + 20001, b);
      expect((r.sparks, r.state.last, r.state.remainder), (0, 20101, 300));
      expect(applySteps(const StepState(last: 50000), 25000, b).sparks, 0, reason: 'reboot e já 25 000 desde o boot');
    });

    test('leitura igual não rende nada', () {
      expect(applySteps(const StepState(last: 10, remainder: 5), 10, b).sparks, 0);
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

    test('converte, guarda base e resto nos settings e registra o evento', () async {
      final s = fresh()..setSetting('last_biome', 'green');
      var reading = 1000;
      final t = StepTracker(state: s, balance: b, read: () async => reading);
      expect(await t.sync(epoch), 0);
      reading = 3500;
      expect(await t.sync(epoch), 2);
      expect(s.count('item.dust.plant'), 2);
      expect(s.settings['steps_rem'], 500);
      expect(s.story.count('steps'), 2);
    });

    test('sem posição conhecida usa urban; sem sensor não faz nada', () async {
      final s = fresh();
      var reading = 0;
      final t = StepTracker(state: s, balance: b, read: () async => reading);
      await t.sync(epoch);
      reading = 1000;
      expect(await t.sync(epoch), 1);
      expect(s.count('item.dust.fire'), 1);
      expect(await StepTracker(state: s, balance: b, read: () async => null).sync(epoch), 0);
    });

    test('reset esquece a base', () async {
      final s = fresh();
      final t = StepTracker(state: s, balance: b, read: () async => 5000);
      await t.sync(epoch);
      t.reset();
      expect(s.settings.containsKey('steps_last'), isFalse);
    });
  });
}
