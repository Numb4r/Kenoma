import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/signal.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import '../support/reference_player.dart';

final _balance = loadTuningBalance();

/// O número do balance na intensidade [i].
double _n(String type, String key, [double i = 1]) => _balance.signal.phase1.at(type, key, i);

TargetSignal signal(EcoType type, double intensity, {int seed = 5}) =>
    TargetSignal.generate(type: type, intensity: intensity, rng: Pcg32(fnv1a64([seed]), saltKenoma), balance: _balance);

TuningSession session(TargetSignal s) => TuningSession(signal: s, baseTolerance: 0.06, balance: _balance, timeLimitS: 20);

const _dt = 1 / 60;

void main() {
  group('padrões de resistência dos nove tipos da fase 1', () {
    test('os três do MVP e a intensidade zero não têm padrão; a mesma seed dá o mesmo sinal', () {
      for (final t in EcoType.mvp) {
        expect(signal(t, 0.8).pattern.isNone, isTrue);
      }
      for (final t in EcoType.values.where((t) => !EcoType.mvp.contains(t))) {
        expect(signal(t, 0).pattern.isNone, isTrue, reason: t.name);
        expect(signal(t, 0.7).pattern.isNone, isFalse, reason: t.name);
        final a = signal(t, 0.7), b = signal(t, 0.7);
        for (var x = 0.0; x < 20; x += 0.37) {
          expect(a.frequencyAt(x), b.frequencyAt(x), reason: t.name);
        }
      }
    });

    test('o sinal de todos fica em [0, 1] e não dá saltos de um quadro para o outro', () {
      for (final t in EcoType.values) {
        final s = signal(t, 1);
        var last = s.frequencyAt(0);
        for (var x = _dt; x < 25; x += _dt) {
          final f = s.frequencyAt(x);
          expect(f, inInclusiveRange(0, 1), reason: t.name);
          if (!EcoType.mvp.contains(t)) expect((f - last).abs(), lessThan(0.13), reason: '${t.name} em $x');
          last = f;
        }
      }
    });

    test('Terra: faixas pesadas e fixas no dial; dentro delas o progresso sobe mais devagar', () {
      final weak = signal(EcoType.earth, 0.1).pattern, strong = signal(EcoType.earth, 1).pattern;
      expect(strong.strata.length, greaterThan(weak.strata.length));
      for (final (lo, hi) in strong.strata) {
        expect(lo, greaterThanOrEqualTo(0));
        expect(hi, lessThanOrEqualTo(1));
        expect(strong.progressFactor((lo + hi) / 2, 3), closeTo(_n('earth', 'slow'), 1e-9));
        expect(strong.progressFactor((lo + hi) / 2, 17), closeTo(_n('earth', 'slow'), 1e-9), reason: 'a faixa não anda');
      }
      final sorted = [...strong.strata]..sort((a, b) => a.$1.compareTo(b.$1));
      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i].$1, greaterThan(sorted[i - 1].$2), reason: 'as faixas não se sobrepõem');
      }
      expect(strong.progressFactor((sorted[0].$2 + sorted[1].$1) / 2, 3), 1);
      // Na sessão: alinhado dentro da faixa, o progresso de um quadro é a fração `slow` do de fora.
      final s = signal(EcoType.earth, 1), run = session(s);
      var inBand = 0.0, outBand = 0.0;
      for (var x = 0.0; x < 20; x += _dt) {
        final f = s.frequencyAt(x), before = run.progress;
        run.step(_dt, dial: f);
        if (!run.running) break;
        if (s.pattern.progressFactor(run.dial, run.t) < 1) {
          inBand = math.max(inBand, run.progress - before);
        } else {
          outBand = math.max(outBand, run.progress - before);
        }
      }
      expect(inBand, greaterThan(0));
      expect(inBand, closeTo(outBand * _n('earth', 'slow'), 1e-9));
    });

    test('Elétrico: salta entre 2 ou 3 frequências em ritmo fixo, com aviso antes de cada salto', () {
      final s = signal(EcoType.electric, 1), p = s.pattern;
      final hops = p.hopTimes(20);
      expect(hops.length, greaterThan(5));
      final gaps = {for (var i = 1; i < hops.length; i++) (hops[i] - hops[i - 1]).toStringAsFixed(6)};
      expect(gaps.length, 1, reason: 'ritmo fixo');
      // Entre dois saltos o padrão fica parado; os patamares são 3 na intensidade 1 e 2 na baixa.
      Set<String> levels(TargetSignal sig) => {for (final at in sig.pattern.hopTimes(30)) sig.pattern.offsetAt(at + 0.6 * _n('electric', 'period_s', sig.intensity)).toStringAsFixed(4)};
      expect(levels(s).length, 3);
      expect(levels(signal(EcoType.electric, 0.1)).length, 2);
      expect(hops[1] - hops[0], closeTo(_n('electric', 'period_s'), 1e-9));
      expect(p.offsetAt(hops[1] + 0.3), p.offsetAt(hops[1] + 0.6));
      final cues = s.cuesIn(0, 20).where((c) => c.kind == CueKind.hop).toList();
      expect(cues.length, hops.length);
      expect(cues.first.at, lessThan(hops.first));
      expect(s.typeFxAt(hops[2] + 0.02).hopFlash, greaterThan(0.8));
      expect(s.typeFxAt(hops[2] + 0.5).hopFlash, 0);
    });

    test('Metal: com a blindagem de pé, alinhar não dá progresso (nem tira)', () {
      final s = signal(EcoType.metal, 1), p = s.pattern, run = session(s);
      var armoredS = 0.0, gained = 0.0, held = 0;
      for (var x = 0.0; x < 20 && run.running; x += _dt) {
        final before = run.progress;
        run.step(_dt, dial: s.frequencyAt(run.t + _dt));
        if (p.armoredAt(run.t)) {
          armoredS += _dt;
          expect(run.aligned, isTrue);
          expect(run.progress, before, reason: 'blindado em ${run.t}');
          held++;
        } else {
          gained += run.progress - before;
        }
      }
      expect(held, greaterThan(30));
      expect(gained, greaterThan(0));
      expect(armoredS / run.t, closeTo(_n('metal', 'duty'), 0.12), reason: 'a fração do tempo blindado na intensidade 1');
      final weak = signal(EcoType.metal, 0.1).pattern;
      final frac = [for (var x = 0.0; x < 60; x += 0.05) weak.armoredAt(x)].where((a) => a).length / 1200;
      expect(frac, lessThan(0.3));
      expect(s.typeFxAt(0).armored, p.armoredAt(0));
    });

    test('Luz: o clarão apaga a onda e deixa a imagem residual de onde ela estava', () {
      final s = signal(EcoType.light, 1), p = s.pattern;
      expect(p.flashTimes.length, greaterThan(8));
      final at = p.flashTimes[1];
      expect(p.flashAt(at - 0.01), isNull);
      final fx = s.typeFxAt(at + 0.05);
      expect(fx.flash, greaterThan(0.9));
      expect(fx.afterimage, s.frequencyAt(at), reason: 'a imagem fica onde a onda estava no clarão');
      final blind = _n('light', 'blind_s');
      expect(s.typeFxAt(at + blind - 0.01).flash, inExclusiveRange(0, 0.1));
      expect(s.typeFxAt(at + blind + 0.01).afterimage, isNull);
      // O clarão não mexe no progresso: só na vista.
      expect(p.progressFactor(0.5, at + 0.1), 1);
      expect(s.cuesIn(0, 60).where((c) => c.kind == CueKind.flash).length, p.flashTimes.length);
      for (var i = 1; i < p.flashTimes.length; i++) {
        expect(p.flashTimes[i] - p.flashTimes[i - 1], greaterThan(blind), reason: 'um clarão acaba antes do outro');
      }
    });

    test('Sombra: a onda afunda na tinta e volta; o sinal continua o mesmo por baixo', () {
      final s = signal(EcoType.shadow, 1), p = s.pattern;
      final ink = [for (var x = 0.0; x < 30; x += 0.02) p.inkAt(x)];
      expect(ink.reduce(math.max), closeTo(1, 1e-9));
      expect(ink.reduce(math.min), 0);
      expect(ink.where((k) => k > 0).length / ink.length, closeTo(_n('shadow', 'duty'), 0.05));
      for (var i = 1; i < ink.length; i++) {
        expect((ink[i] - ink[i - 1]).abs(), lessThan(0.15), reason: 'sobe e desce aos poucos');
      }
      expect(signal(EcoType.shadow, 0.1).pattern.inkAt(0.0) <= 0.65, isTrue);
      final deep = [for (var x = 0.0; x < 30; x += 0.02) x].firstWhere((x) => p.inkAt(x) > 0.99);
      expect(s.typeFxAt(deep).ink, greaterThan(0.99));
    });

    test('Espectral: a cópia cinza repete a onda real com atraso', () {
      final s = signal(EcoType.spectral, 1), delay = s.pattern.ghostDelayS;
      expect(delay, closeTo(_n('spectral', 'delay_s'), 1e-9));
      expect(signal(EcoType.spectral, 0.0001).pattern.ghostDelayS, greaterThan(delay), reason: 'mais fraco, a cópia vem mais atrasada e é mais fácil de separar');
      var apart = 0.0;
      for (var x = 1.0; x < 20; x += 0.1) {
        final fx = s.typeFxAt(x);
        expect(fx.ghost, s.frequencyAt(x - delay));
        apart = math.max(apart, (fx.ghost! - s.frequencyAt(x)).abs());
      }
      expect(apart, greaterThan(0.03), reason: 'a cópia se afasta da real');
      expect(s.typeFxAt(0.1).ghost, s.frequencyAt(0));
    });

    test('Digital: cópias falsas ao lado da real, que pulam de lugar com glitch', () {
      final s = signal(EcoType.digital, 1), p = s.pattern;
      final (d0, g0) = p.decoysAt(0.1);
      expect(d0.length, 3);
      expect(signal(EcoType.digital, 0.1).pattern.decoysAt(0).$1.length, 1);
      for (final d in d0) {
        expect(d.abs(), inInclusiveRange(0.5 * _n('digital', 'spread'), _n('digital', 'spread')), reason: 'longe o bastante para não valer como a real');
      }
      final (d1, g1) = p.decoysAt(0.1 + _n('digital', 'jump_s'));
      expect(g1, g0 + 1);
      expect(d1, isNot(d0));
      expect(p.decoysAt(0.3).$1, d0, reason: 'entre dois pulos as cópias ficam no lugar');
      final fx = s.typeFxAt(5);
      expect(fx.decoys.length, 3);
      for (final f in fx.decoys) {
        expect(f, inInclusiveRange(0, 1));
      }
    });

    test('Feérico: inverte o sentido do dial de tempos em tempos e troca de padrão no meio', () {
      final s = signal(EcoType.fae, 1), p = s.pattern;
      final signs = [for (var x = 0.0; x < 20; x += 0.05) p.dialSignAt(x)];
      expect(signs.toSet(), {1.0, -1.0});
      var flips = 0;
      for (var i = 1; i < signs.length; i++) {
        if (signs[i] != signs[i - 1]) flips++;
      }
      expect(flips, closeTo(20 / _n('fae', 'invert_every_s'), 1.01));
      final half = _n('fae', 'stage_s');
      expect(p.stageAt(half - 0.1), 0);
      expect(p.stageAt(half + 0.1), 1);
      // Antes da metade deriva em onda (não para); depois salta e fica em patamares.
      expect(p.offsetAt(half * 0.5), isNot(p.offsetAt(half * 0.5 + 0.4)));
      final hops = p.hopTimes(20);
      expect(hops.first, half);
      expect(p.offsetAt(hops[1] + 0.5), p.offsetAt(hops[1] + 1.0));
      expect(p.offsetAt(half).abs(), lessThan(1e-9), reason: 'a troca não dá salto');
      expect(s.typeFxAt(half + 0.5).stage, 1);
      expect({for (var x = 0.0; x < 20; x += 0.05) s.typeFxAt(x).inverted}, {true, false});
      // Os outros tipos nunca invertem.
      expect(signal(EcoType.draconic, 1).pattern.dialSignAt(5), 1);
    });

    test('Dracônico: começa calmo e a cada etapa soma o padrão de outro tipo', () {
      final s = signal(EcoType.draconic, 0.5), p = s.pattern;
      final third = _n('draconic', 'stage_s', 0.5);
      expect([p.stageAt(1), p.stageAt(third + 0.1), p.stageAt(2 * third + 0.1), p.stageAt(19.9)], [0, 1, 2, 2], reason: 'não passa de três padrões');
      for (var x = 0.0; x < third; x += 0.1) {
        expect(p.offsetAt(x), 0, reason: 'primeiro terço calmo');
        expect(p.armoredAt(x), isFalse);
      }
      final second = [for (var x = third; x < 2 * third; x += 0.05) p.offsetAt(x)];
      expect(second.reduce(math.max) - second.reduce(math.min), greaterThan(0.08), reason: 'segundo terço: deriva');
      expect([for (var x = third; x < 2 * third; x += 0.05) p.armoredAt(x)].contains(true), isFalse);
      expect(p.hopTimes(20).first, closeTo(2 * third, 1e-9), reason: 'último terço: saltos');
      expect([for (var x = 2 * third; x < 20; x += 0.05) p.armoredAt(x)].contains(true), isTrue, reason: 'último terço: blindagem');
      expect(p.offsetAt(third).abs(), lessThan(1e-9));
    });
  });
}
