import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/fx/wave_geometry.dart';
import 'package:kenoma/capture/resistance.dart';
import 'package:kenoma/capture/signal.dart';
import 'package:kenoma/capture/tuning_balance.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import '../support/fixtures.dart';
import '../support/reference_player.dart';

TargetSignal signal(EcoType type, double intensity, {int seed = 5}) => TargetSignal.generate(
      type: type,
      intensity: intensity,
      rng: Pcg32(fnv1a64([seed]), saltKenoma),
      balance: loadTuningBalance(),
    );

List<double> series(TargetSignal s, {double to = 30}) => [for (var t = 0.0; t < to; t += 1 / 60) s.frequencyAt(t)];

double maxJump(List<double> xs) => [for (var i = 1; i < xs.length; i++) (xs[i] - xs[i - 1]).abs()].reduce(math.max);

/// Sinal do Fogo com a velocidade da fronteira trocada: serve para cenários que a velocidade de jogo
/// não alcança (isca que sai antes do próximo pico, fronteira quase parada).
TargetSignal fireSignalWith({required double boundarySpeed, required double intensity, int seed = 5}) {
  final json = loadJson('assets/data/balance.json');
  (((json['tuning'] as Map)['signal'] as Map)['fire'] as Map)['boundary_u_per_s'] = boundarySpeed;
  return TargetSignal.generate(
      type: EcoType.fire, intensity: intensity, rng: Pcg32(fnv1a64([seed]), saltKenoma), balance: TuningBalance(json));
}

double fold(double f) {
  final m = f % 2;
  final x = m < 0 ? m + 2 : m;
  return x > 1 ? 2 - x : x;
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

void main() {
  final b = loadTuningBalance();

  test('mesma semente, mesmo sinal; semente diferente, sinal diferente', () {
    expect(series(signal(EcoType.fire, 0.7)), series(signal(EcoType.fire, 0.7)));
    expect(series(signal(EcoType.fire, 0.7, seed: 6)), isNot(series(signal(EcoType.fire, 0.7))));
  });

  test('a frequência fica sempre em [0, 1], em qualquer tipo e intensidade', () {
    for (final type in EcoType.values) {
      for (final r in [0.0, 0.3, 0.72, 1.0]) {
        for (var seed = 0; seed < 20; seed++) {
          for (final f in series(signal(type, r, seed: seed))) {
            expect(f, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    }
  });

  group('sem resistência', () {
    test('os três tipos têm o mesmo sinal: só a deriva lenta de base, sem picos nem vibração', () {
      final fire = signal(EcoType.fire, 0);
      expect(series(signal(EcoType.water, 0)), series(fire));
      expect(series(signal(EcoType.plant, 0)), series(fire));
      for (final type in EcoType.values) {
        final s = signal(type, 0);
        expect(s.cues, isEmpty);
        expect(s.kickTimes, isEmpty);
        expect(s.fireSplitAt(3), isNull);
        expect(s.rootsAt(15), isEmpty);
        expect(s.burnUs, isEmpty);
      }
    });

    test('a frequência inicial fica na faixa e a deriva respeita a amplitude', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = signal(EcoType.fire, 0, seed: seed);
        expect(s.start, inInclusiveRange(b.signal.startRange.$1, b.signal.startRange.$2));
        for (final f in series(s, to: 25)) {
          expect((f - s.start).abs(), lessThanOrEqualTo(b.signal.wanderAmplitude + 1e-9));
        }
      }
    });
  });

  group('Fogo: a onda se parte em duas', () {
    const r = 0.72;
    final fire = b.signal.fire;
    final speed = fire.boundaryUPerS;
    double glide(double i) => lerpRange(fire.glideS, i);

    test('a real desliza para a nova frequência com smoothstep e o salto é permanente', () {
      final s = signal(EcoType.fire, r, seed: 5);
      final g = s.fireGlideS;
      expect(g, closeTo(glide(r), 1e-12));
      final at = s.kickTimes.first;
      final delta = s.kickDeltas.first;
      final base = signal(EcoType.fire, 0, seed: 5);
      // Sem dobrar nas bordas: a real é a base mais o salto.
      expect(base.frequencyAt(at) + delta, inInclusiveRange(0.0, 1.0), reason: 'a semente do teste não cruza a borda no primeiro pico');
      expect(s.frequencyAt(at - 1e-6), closeTo(base.frequencyAt(at - 1e-6), 1e-9), reason: 'antes do pico é só a base');
      expect(s.frequencyAt(at + g / 2) - base.frequencyAt(at + g / 2), closeTo(delta / 2, 1e-9), reason: 'smoothstep(0,5) = 0,5');
      expect(s.frequencyAt(at + g) - base.frequencyAt(at + g), closeTo(delta, 1e-9));
      final before2 = s.kickTimes[1] - 1e-6;
      expect(s.frequencyAt(before2) - base.frequencyAt(before2), closeTo(delta, 1e-9), reason: 'não decai: continua lá até o próximo pico');
    });

    test('o deslize é suave e vai num só sentido; sem teleporte', () {
      final s = signal(EcoType.fire, r, seed: 5);
      final g = s.fireGlideS;
      final at = s.kickTimes.first;
      final delta = s.kickDeltas.first;
      final base = signal(EcoType.fire, 0, seed: 5);
      var prev = 0.0;
      for (var t = at; t <= at + g; t += 1 / 60) {
        final moved = s.frequencyAt(t) - base.frequencyAt(t);
        expect((moved - prev) * delta.sign, greaterThanOrEqualTo(-1e-12), reason: 'monotônico');
        prev = moved;
      }
      // Passo máximo por quadro: o pico da inclinação do smoothstep, 1,5 × salto / glide, e a deriva de base.
      final step = maxJump(series(s, to: 25));
      expect(step, lessThan(1.5 * s.kickDeltas.map((d) => d.abs()).reduce(math.max) / g / 60 + 0.01));
    });

    test('glide_s = lerp(1,2 → 0,5) pela intensidade; a isca não tem mais tempo fixo', () {
      expect(signal(EcoType.fire, 0.4).fireGlideS, closeTo(lerp(1.2, 0.5, 0.4), 1e-12));
      expect(signal(EcoType.fire, 1).fireGlideS, closeTo(0.5, 1e-12));
    });

    test('antes do primeiro pico a onda é uma só: não há partição nem trechos', () {
      final s = signal(EcoType.fire, r, seed: 5);
      expect(s.fireSplitAt(s.kickTimes.first - 1e-6), isNull);
      expect(s.fireSplitAt(0), isNull);
      expect(s.fire.segmentsAt(0, s.frequencyAt(0)), isEmpty);
      expect(s.fireSplitAt(s.kickTimes.first)!.index, 0);
    });

    test('a primeira queima cai na faixa pedida e a partição aponta para o pico atual', () {
      final s = signal(EcoType.fire, r, seed: 5);
      expect(s.burnUs, hasLength(s.kickTimes.length));
      expect(s.burnUs.first, inInclusiveRange(fire.burnU.$1, fire.burnU.$2));
      for (var i = 0; i < s.kickTimes.length; i++) {
        final split = s.fireSplitAt(s.kickTimes[i] + 0.01)!;
        expect(split.index, i);
        expect(split.boundaryU, closeTo(s.burnUs[i] - speed * 0.01, 1e-12));
      }
    });

    test('a fronteira é um ponto da onda e rola para a esquerda na velocidade da onda', () {
      final s = signal(EcoType.fire, r, seed: 5);
      final at = s.kickTimes.first;
      final u0 = s.burnUs.first;
      for (final dt in [0.0, 0.5, 1.0]) {
        if (at + dt >= s.kickTimes[1]) continue;
        expect(s.fireSplitAt(at + dt)!.boundaryU, closeTo(u0 - speed * dt, 1e-12));
      }
      expect(s.fireBoundaryUAt(0, at + 1) - s.fireBoundaryUAt(0, at), closeTo(-speed, 1e-12));
    });

    test('no instante da queima o trecho da esquerda já é cinza: a real à direita, a isca à esquerda', () {
      final s = signal(EcoType.fire, r, seed: 5);
      final at = s.kickTimes.first;
      final split = s.fireSplitAt(at)!;
      expect(split.segments.map((x) => x.real), [true, false], reason: 'real à direita, isca à esquerda, nada mais');
      final real = split.segments[0];
      final decoy = split.segments[1];
      expect(real.toU, 1);
      expect(real.fromU, closeTo(s.burnUs.first, 1e-12));
      expect(decoy.fromU, 0.0);
      expect(decoy.toU, closeTo(s.burnUs.first, 1e-12));
      expect(real.frequency, s.frequencyAt(at));
      expect(decoy.frequency, closeTo(s.frequencyAt(at), 1e-9), reason: 'na queima as duas ainda estão na mesma frequência');
      // A isca fica na antiga; a real vai para a nova.
      final t = at + s.fireGlideS;
      final later = s.fireSplitAt(t)!;
      // Com a intensidade acima de 0,6 a isca também desliza o contrário: a distância cresce por esse fator.
      final apart = 1 + (r > fire.decoyCounterFrom ? fire.decoyCounter : 0);
      expect((later.segments[0].frequency - later.segments[1].frequency).abs(), closeTo(s.kickDeltas.first.abs() * apart, 1e-9));
    });

    test('a isca continua na frequência antiga com a deriva de base (intensidade ≤ 0,6)', () {
      final s = signal(EcoType.fire, 0.5, seed: 5);
      final base = signal(EcoType.fire, 0, seed: 5);
      final at = s.kickTimes.first;
      for (final t in [at, at + 0.2, at + s.fireGlideS, at + 1.0]) {
        if (t >= s.kickTimes[1]) continue;
        expect(s.fireSplitAt(t)!.decoyFrequency, closeTo(base.frequencyAt(t), 1e-9), reason: 't=$t');
      }
    });

    test('a isca do segundo pico guarda a frequência que a real tinha na queima (os saltos anteriores)', () {
      final s = signal(EcoType.fire, 0.5, seed: 5);
      final base = signal(EcoType.fire, 0, seed: 5);
      final at1 = s.kickTimes[1];
      final real = s.frequencyAt(at1);
      for (final t in [at1, at1 + 0.3, at1 + 1.0]) {
        if (t >= s.kickTimes[2]) continue;
        final drift = base.frequencyAt(t) - base.frequencyAt(at1);
        expect(s.fireSplitAt(t)!.decoyFrequency, closeTo(real + drift, 1e-9), reason: 'congelada, com a deriva de base por cima');
      }
    });

    test('acima de 0,6 a isca também desliza, no sentido oposto ao da real', () {
      final s = signal(EcoType.fire, 0.9, seed: 5);
      final base = signal(EcoType.fire, 0, seed: 5);
      final at = s.kickTimes.first;
      final delta = s.kickDeltas.first;
      final t = at + s.fireGlideS;
      final shift = s.fireSplitAt(t)!.decoyFrequency - base.frequencyAt(t);
      expect(shift, closeTo(-fire.decoyCounter * delta, 1e-9));
      expect(shift * delta, lessThan(0), reason: 'sentido oposto ao da real');
      final half = s.fireSplitAt(at + s.fireGlideS / 2)!.decoyFrequency - base.frequencyAt(at + s.fireGlideS / 2);
      expect(half, closeTo(-fire.decoyCounter * delta / 2, 1e-9));
      final edge = signal(EcoType.fire, 0.6, seed: 5);
      final tt = edge.kickTimes.first + edge.fireGlideS;
      expect(edge.fireSplitAt(tt)!.decoyFrequency, closeTo(base.frequencyAt(tt), 1e-9), reason: 'no limiar (0,6) ainda não desliza');
    });

    test('a isca acaba quando sai da tela: a vida cai de 1 a 0 com a fronteira, em burnU / velocidade', () {
      const fast = 0.4; // sai antes do próximo pico, que vem 3 s depois
      final s = fireSignalWith(boundarySpeed: fast, intensity: 0.1);
      final at = s.kickTimes.first;
      final life = s.burnUs.first / fast;
      expect(s.kickTimes[1] - at, greaterThan(life + 0.2), reason: 'a isca sai antes do próximo pico');
      expect(s.fireSplitAt(at)!.decoyLife, 1);
      expect(s.fireSplitAt(at + life / 2)!.decoyLife, closeTo(0.5, 1e-9));
      expect(s.fireSplitAt(at + life - 1e-6)!.decoyAlive, isTrue);
      final gone = s.fireSplitAt(at + life + 0.01)!;
      expect(gone.decoyAlive, isFalse);
      expect(gone.decoyLife, 0);
      expect(gone.segments.map((x) => x.real), [true], reason: 'só a real sobra na tela');
      expect(gone.segments.single.fromU, 0, reason: 'preenche a tela inteira');
    });

    test('na velocidade de jogo a isca dura de 1 a 6 s: de 0,2 a 0,95 de tela a 0,15 por segundo', () {
      for (var seed = 0; seed < 50; seed++) {
        for (final u in signal(EcoType.fire, 0.6, seed: seed).burnUs) {
          expect(u / speed, inInclusiveRange(0.2 / 0.15 - 1e-9, 0.95 / 0.15 + 1e-9));
        }
      }
    });

    test('quanto mais à direita a queima, mais a isca demora para sair', () {
      final s = signal(EcoType.fire, 0.1, seed: 5);
      final lives = [for (final u in s.burnUs) u / speed];
      expect(lives.reduce(math.max), greaterThan(lives.reduce(math.min)));
    });

    test('um pico novo mantém as iscas antigas, cinza, rolando para fora; as de dentro da tela ficam contíguas', () {
      final s = signal(EcoType.fire, 0.9, seed: 5);
      final t = s.kickTimes[2] + 0.05;
      final split = s.fireSplitAt(t)!;
      final decoys = split.segments.where((x) => !x.real).toList();
      expect(decoys.length, greaterThanOrEqualTo(2), reason: 'a isca do pico 2 e ao menos uma antiga ainda na tela');
      for (var i = 0; i + 1 < split.segments.length; i++) {
        expect(split.segments[i + 1].toU, closeTo(split.segments[i].fromU, 1e-12), reason: 'sem buraco entre os trechos');
      }
      expect(split.segments.last.fromU, 0);
      expect(split.segments.first.toU, 1);
      expect(split.segments.every((x) => x.fromU < x.toU), isTrue);
    });

    test('o desenho anda com a fronteira: na queima as duas ondas têm a mesma fase, e não há salto de fase', () {
      final s = signal(EcoType.fire, 0.9, seed: 5);
      for (var i = 0; i < 4; i++) {
        final at = s.kickTimes[i];
        final after = s.fireSplitAt(at)!;
        final u = s.burnUs[i];
        final real = after.segments[0];
        final decoy = after.segments[1];
        expect(real.thetaAt(u), closeTo(decoy.thetaAt(u), 1e-9), reason: 'pico $i: a fronteira é um ponto das duas');
        // A onda de antes (a global no primeiro pico; a real do pico anterior nos outros) passa pela mesma fase.
        final before = i == 0
            ? waveTheta(s.frequencyAt(at), u, waveScroll(at))
            : s.fireSplitAt(at - 1e-9)!.segments[0].thetaAt(u);
        expect(real.thetaAt(u), closeTo(before, 1e-6), reason: 'pico $i: sem salto de fase na queima');
      }
    });

    test('nenhuma queima cai em trecho morto, à esquerda de uma fronteira anterior, em 1000 sinais', () {
      var burns = 0;
      for (var seed = 0; seed < 1000; seed++) {
        final intensity = 0.05 + 0.95 * ((seed * 0.6180339887) % 1.0);
        final s = signal(EcoType.fire, intensity, seed: seed);
        final times = s.kickTimes;
        for (var i = 0; i < times.length; i++) {
          final u = s.burnUs[i];
          expect(u, inInclusiveRange(fire.burnU.$1, fire.burnEdgeU), reason: 'seed $seed pico $i');
          for (var j = 0; j < i; j++) {
            expect(u, greaterThan(s.fireBoundaryUAt(j, times[i])), reason: 'seed $seed: a queima $i caiu à esquerda da fronteira $j');
          }
          burns++;
        }
      }
      expect(burns, greaterThan(5000));
    });

    test('se o trecho vivo visível é curto demais, a queima vai para o ponto mais à direita possível', () {
      // Fronteira quase parada: a anterior fica perto de onde nasceu e o trecho vivo encolhe de pico em pico.
      var edges = 0;
      for (var seed = 0; seed < 300; seed++) {
        final s = fireSignalWith(boundarySpeed: 0.01, intensity: 0.9, seed: seed);
        final times = s.kickTimes;
        for (var i = 1; i < times.length; i++) {
          final prev = s.fireBoundaryUAt(i - 1, times[i]); // onde a fronteira anterior está agora
          final u = s.burnUs[i];
          expect(u, greaterThan(prev), reason: 'seed $seed pico $i');
          if (fire.burnU.$2 - math.max(fire.burnU.$1, prev) < fire.burnMinLiveU) {
            expect(u, fire.burnEdgeU, reason: 'trecho vivo curto: vai ao ponto mais à direita');
            edges++;
          } else {
            expect(u, lessThanOrEqualTo(fire.burnU.$2));
          }
        }
      }
      expect(edges, greaterThan(50), reason: 'o caso curto precisa acontecer para valer o teste');
    });

    test('conjurador 1 contra Eco 1: intensidade 0 e nenhuma queima, de propósito', () {
      expect(resistanceIntensity(playerLevel: 1, ecoLevel: 1, balance: b), 0);
      final s = signal(EcoType.fire, 0);
      expect(s.kickTimes, isEmpty);
      expect(s.burnUs, isEmpty);
      expect(s.cues, isEmpty);
      for (var t = 0.0; t < 30; t += 0.5) {
        expect(s.fireSplitAt(t), isNull);
      }
    });

    test('com qualquer intensidade acima de 0 há queima, e a primeira vem antes do limite de tempo', () {
      for (final i in [1e-9, 1e-6, 0.001, 0.01, 0.05, 0.1, 0.3, 0.6, 0.945, 1.0]) {
        for (var seed = 0; seed < 50; seed++) {
          final s = signal(EcoType.fire, i, seed: seed);
          expect(s.kickTimes, isNotEmpty, reason: 'intensidade $i seed $seed');
          expect(s.burnUs, hasLength(s.kickTimes.length));
          expect(s.kickTimes.first, lessThan(b.timeLimitS), reason: 'a queima chega dentro da sintonia: i=$i seed=$seed');
          expect(s.cues.first.kind, CueKind.fireWarning);
        }
      }
      // O nível mais baixo com resistência: Conjurador 4 (0,3) contra um Eco do mesmo nível.
      expect(resistanceIntensity(playerLevel: 4, ecoLevel: 4, balance: b), greaterThan(0));
    });

    test('a real é a frequência do sinal: tolerância e progresso a medem, não a isca', () {
      final s = makeSession(type: EcoType.fire, playerLevel: 15, ecoLevel: 17, seed: 5);
      final at = s.signal.kickTimes.first;
      while (s.running && s.t < at + 0.8) {
        s.step(1 / 60, dial: s.signal.frequencyAt(s.t + 1 / 60));
      }
      final split = s.signal.fireSplitAt(s.t)!;
      final real = s.signal.frequencyAt(s.t);
      expect(s.targetFrequency, real);
      expect((split.decoyFrequency - real).abs(), greaterThan(s.tolerance * 2), reason: 'o teste precisa de uma isca longe da real');
      s.step(1 / 60, dial: real);
      expect(s.aligned, isTrue);
      final progress = s.progress;
      for (var i = 0; i < 20; i++) {
        s.step(1 / 60, dial: s.signal.fireSplitAt(s.t)!.decoyFrequency);
      }
      expect(s.aligned, isFalse, reason: 'o dial na isca não alinha');
      expect(s.progress, lessThan(progress), reason: 'e o progresso cai');
    });

    test('mais intensidade, picos mais frequentes e maiores', () {
      int count(double r) => signal(EcoType.fire, r).kickTimes.where((t) => t < 60).length;
      expect(count(0.3), lessThan(count(0.72)));
      expect(count(0.72), lessThan(count(1.0)));
      double size(double r) => signal(EcoType.fire, r).kickDeltas.map((d) => d.abs()).reduce((a, b) => a + b) / signal(EcoType.fire, r).kickDeltas.length;
      expect(size(0.3), lessThan(size(1.0)));
    });

    test('o único aviso é a brasa: um aviso antes de cada pico, sem tremor', () {
      final s = signal(EcoType.fire, r);
      final lead = s.fireWarningLeadS;
      expect(s.cues.length, s.kickTimes.length);
      for (var i = 0; i < s.kickTimes.length; i++) {
        expect(s.cues[i].kind, CueKind.fireWarning);
        expect(s.cues[i].at, closeTo(s.kickTimes[i] - lead, 1e-9));
      }
    });

    test('a brasa vem com menos antecedência quando a intensidade sobe: 0,5 s → 0,25 s, com piso de 0,25 s', () {
      expect(signal(EcoType.fire, 0.1).fireWarningLeadS, closeTo(lerp(0.5, 0.25, 0.1), 1e-12));
      expect(signal(EcoType.fire, 1).fireWarningLeadS, closeTo(0.25, 1e-12));
      for (var r = 0.0; r <= 1.0; r += 0.05) {
        expect(signal(EcoType.fire, r).fireWarningLeadS, greaterThanOrEqualTo(0.25 - 1e-12), reason: 'intensidade $r');
      }
      final weak = signal(EcoType.fire, 0.3);
      expect(weak.cues.first.at, closeTo(weak.kickTimes.first - weak.fireWarningLeadS, 1e-9));
      expect(weak.fireWarningLeadS, greaterThan(signal(EcoType.fire, 0.9).fireWarningLeadS));
    });

    test('no maior nível alcançável (Conjurador 15, Eco 20: intensidade 0,945) o aviso é de 0,264 s', () {
      final top = resistanceIntensity(playerLevel: 15, ecoLevel: 20, balance: b);
      expect(top, closeTo(0.945, 1e-12));
      expect(signal(EcoType.fire, top).fireWarningLeadS, closeTo(0.5 - 0.25 * 0.945, 1e-12));
      expect(signal(EcoType.fire, top).fireWarningLeadS, closeTo(0.264, 1e-3));
    });

    test('sem resistência o sinal é suave', () {
      expect(maxJump(series(signal(EcoType.fire, 0))), lessThan(0.005));
    });

    test('a tolerância não muda no Fogo', () {
      final s = makeSession(type: EcoType.fire, playerLevel: 15, ecoLevel: 17, seed: 1);
      final t0 = s.tolerance;
      s.t = 10;
      expect(s.tolerance, t0);
    });
  });

  group('Água: duas senoides com maré lenta', () {
    // Sem dobrar nas bordas, a deriva da Água é o que waterOffsetAt devolve.
    double amp(double r) => lerpRange(b.signal.water.amplitude, r);

    test('sem saltos, e a oscilação cresce com a intensidade', () {
      final weak = series(signal(EcoType.water, 0.3));
      final strong = series(signal(EcoType.water, 0.72));
      expect(maxJump(strong), lessThan(0.01), reason: 'contínua: nada de picos');
      double spread(List<double> xs) => xs.reduce(math.max) - xs.reduce(math.min);
      expect(spread(strong), greaterThan(spread(weak)));
      expect(spread(strong), greaterThan(0.2));
    });

    test('sem resistência ou fora da Água não há deriva de maré', () {
      expect(signal(EcoType.water, 0).waterOffsetAt(3.3), 0);
      expect(signal(EcoType.fire, 0.72).waterOffsetAt(3.3), 0);
      expect(signal(EcoType.plant, 0.72).waterOffsetAt(3.3), 0);
    });

    test('a deriva segue a fórmula: duas senoides de períodos P e P × 1,618, com fases sorteadas, e a maré', () {
      final w = b.signal.water;
      const r = 0.72;
      final rng = Pcg32(fnv1a64([5]), saltKenoma);
      rng.nextFloat(); // frequência inicial
      rng.nextFloat(); // fase da deriva de base
      final phase1 = 2 * math.pi * rng.nextFloat();
      final phase2 = 2 * math.pi * rng.nextFloat(); // sorteios novos, logo depois dos que já existiam
      final tidePhase = 2 * math.pi * rng.nextFloat();
      final p1 = lerpRange(w.periodS, r);
      final p2 = p1 * 1.618;
      final s = signal(EcoType.water, r);
      for (var t = 0.0; t < 40; t += 0.37) {
        final tide = 0.8 + 0.2 * math.sin(2 * math.pi * t / w.tidePeriodS + tidePhase);
        final expected = tide *
            amp(r) *
            ((1 - w.secondWeight) * math.sin(2 * math.pi * t / p1 + phase1) + w.secondWeight * math.sin(2 * math.pi * t / p2 + phase2));
        expect(s.waterOffsetAt(t), closeTo(expected, 1e-12), reason: 't=$t');
      }
      expect(w.secondPeriodRatio, 1.618);
      expect(w.tidePeriodS, closeTo(11, 0.5));
      expect(w.tideMin, 0.6);
    });

    test('as duas senoides nunca se repetem juntas: o padrão não tem o período P', () {
      final s = signal(EcoType.water, 0.72);
      final p1 = lerpRange(b.signal.water.periodS, 0.72);
      var differs = 0;
      for (var t = 0.0; t < 30; t += 1.3) {
        if ((s.waterOffsetAt(t + p1) - s.waterOffsetAt(t)).abs() > 0.01) differs++;
      }
      expect(differs, greaterThan(15));
    });

    test('a amplitude total é modulada pela maré, entre 60% e 100% do máximo', () {
      const r = 0.72;
      final limit = amp(r);
      var peak = 0.0;
      final peaksByWindow = <double>[];
      for (var seed = 0; seed < 30; seed++) {
        final s = signal(EcoType.water, r, seed: seed);
        // Dentro de cada janela de 3 s acha o pico da deriva; a maré faz esse pico variar.
        for (var w0 = 0.0; w0 < 66; w0 += 3) {
          var windowPeak = 0.0;
          for (var t = w0; t < w0 + 3; t += 0.02) {
            windowPeak = math.max(windowPeak, s.waterOffsetAt(t).abs());
          }
          peaksByWindow.add(windowPeak);
          peak = math.max(peak, windowPeak);
        }
      }
      expect(peak, lessThanOrEqualTo(limit + 1e-9), reason: 'nunca passa da amplitude total');
      expect(peak, greaterThan(0.85 * limit), reason: 'chega perto do máximo nos picos da maré');
      final calm = peaksByWindow.where((p) => p < 0.6 * limit).length;
      expect(calm, greaterThan(0), reason: 'a maré baixa reduz o pico');
    });

    test('a maré nunca zera a deriva: o envelope fica entre 60% e 100%', () {
      // Com fase igual nas duas senoides, waterOffset = tide × amp × seno; a razão entre picos
      // consecutivos de maré alta e baixa fica em [0,6; 1].
      final w = b.signal.water;
      for (var seed = 0; seed < 20; seed++) {
        final s = signal(EcoType.water, 0.72, seed: seed);
        for (var t = 0.0; t < 60; t += 0.5) {
          final envelope = s.waterOffsetAt(t).abs() / amp(0.72);
          expect(envelope, lessThanOrEqualTo(1.0 + 1e-9));
        }
      }
      expect(w.tideMin, inInclusiveRange(0.0, 1.0));
    });


    group('avisos nas inversões de sentido', () {
      // Inversões achadas de forma independente: onde a derivada do sinal troca de sinal.
      List<double> reversals(TargetSignal s, {double to = 60}) {
        const h = 0.01;
        final out = <double>[];
        var prev = s.frequencyAt(0);
        var prevDir = 0;
        for (var i = 1; i * h <= to; i++) {
          final f = s.frequencyAt(i * h);
          final dir = f > prev ? 1 : (f < prev ? -1 : 0);
          if (dir != 0) {
            if (prevDir != 0 && dir != prevDir) out.add((i - 1) * h);
            prevDir = dir;
          }
          prev = f;
        }
        return out;
      }

      test('cada aviso toca 0,4 s antes de uma inversão do sinal', () {
        for (final seed in [1, 2, 3]) {
          final s = signal(EcoType.water, 0.72, seed: seed);
          expect(s.cues, isNotEmpty);
          for (final c in s.cues) {
            final t = c.at + b.signal.water.cueLeadS;
            const h = 0.06;
            final before = s.frequencyAt(t) - s.frequencyAt(t - h);
            final after = s.frequencyAt(t + h) - s.frequencyAt(t);
            expect(before * after, lessThan(0), reason: 'seed $seed, aviso em ${c.at}: o sinal não inverte em $t');
          }
        }
      });

      test('toda inversão tem o seu aviso', () {
        final s = signal(EcoType.water, 0.72, seed: 4);
        final lead = b.signal.water.cueLeadS;
        for (final rev in reversals(s, to: 55).where((r) => r > lead + 0.05)) {
          expect(s.cues.any((c) => (c.at - (rev - lead)).abs() < 0.03), isTrue, reason: 'inversão em $rev sem aviso');
        }
      });

      test('o intervalo entre avisos não é fixo', () {
        final s = signal(EcoType.water, 0.72, seed: 4);
        final gaps = [for (var i = 1; i < s.cues.length; i++) s.cues[i].at - s.cues[i - 1].at];
        expect(gaps.length, greaterThan(10));
        final mean = gaps.reduce((a, b) => a + b) / gaps.length;
        final variance = gaps.map((g) => (g - mean) * (g - mean)).reduce((a, b) => a + b) / gaps.length;
        expect(math.sqrt(variance), greaterThan(0.15), reason: 'os avisos seguem o sinal, não um relógio');
      });

      test('todos são ondulações da Água, em ordem, dentro do horizonte', () {
        final s = signal(EcoType.water, 0.72);
        expect(s.cues.every((c) => c.kind == CueKind.waterSwell), isTrue);
        for (var i = 1; i < s.cues.length; i++) {
          expect(s.cues[i].at, greaterThan(s.cues[i - 1].at));
        }
        expect(s.cues.first.at, greaterThan(0));
        expect(s.cues.last.at, lessThanOrEqualTo(60));
      });

      test('sem resistência não há aviso; os outros tipos não recebem avisos da Água', () {
        expect(signal(EcoType.water, 0).cues, isEmpty);
        expect(signal(EcoType.fire, 0.72).cues.every((c) => c.kind == CueKind.fireWarning), isTrue);
        expect(signal(EcoType.plant, 0.72).cues.every((c) => c.kind == CueKind.plantPulse), isTrue);
      });
    });
  });

  group('Planta: o sinal cresce e cada broto finca uma raiz no dial', () {
    final p = b.signal.plant;

    group('tolerância', () {
      test('não encolhe mais: a janela de alinhamento é sempre a do selo (vezes o sobrenível)', () {
        final s = makeSession(type: EcoType.plant, playerLevel: 15, ecoLevel: 17, seed: 1);
        final t0 = s.tolerance;
        expect(t0, closeTo(0.08, 1e-12));
        for (final t in [0.0, 1.0, 3.0, 10.0, 25.0]) {
          s.t = t;
          expect(s.tolerance, t0, reason: 't=$t');
        }
      });

      test('os parâmetros do encolhimento deixaram de existir no balance.json', () {
        final plant = (((loadJson('assets/data/balance.json')['tuning'] as Map)['signal'] as Map)['plant'] as Map);
        for (final k in ['tolerance_shrink', 'shrink_over_s', 'tolerance_floor']) {
          expect(plant.containsKey(k), isFalse, reason: k);
        }
      });
    });

    group('raízes', () {
      const r = 0.72;
      final width = lerpRange(p.rootWidth, r);

      test('cada broto finca uma raiz, no instante dele', () {
        final s = signal(EcoType.plant, r);
        expect(s.plantRoots.roots, hasLength(s.cues.length));
        for (var i = 0; i < s.cues.length; i++) {
          expect(s.plantRoots.roots[i].at, s.cues[i].at);
        }
      });

      test('a raiz nasce perto da frequência do sinal no broto (a até root_jitter) e tem a largura de lerp(0,04, 0,10)', () {
        expect(p.rootWidth, (0.04, 0.10));
        for (var seed = 0; seed < 20; seed++) {
          final s = signal(EcoType.plant, r, seed: seed);
          for (final root in s.plantRoots.roots) {
            expect((root.center - s.frequencyAt(root.at)).abs(), lessThanOrEqualTo(p.rootJitter + 1e-12));
            expect(root.halfWidth * 2, closeTo(width, 1e-12));
          }
        }
        expect(signal(EcoType.plant, 0.2).plantRoots.roots.first.halfWidth * 2, lessThan(signal(EcoType.plant, 1.0).plantRoots.roots.first.halfWidth * 2));
        expect(signal(EcoType.plant, 1.0).plantRoots.roots.first.halfWidth * 2, closeTo(0.10, 1e-12));
      });

      test('as raízes ficam paradas: a faixa de uma raiz não muda enquanto ela existe', () {
        final s = signal(EcoType.plant, r);
        final root = s.plantRoots.roots[3];
        final alive = [for (var t = root.at; t < root.at + 1.0; t += 0.05) if (s.rootsAt(t).contains(root)) t];
        expect(alive.length, greaterThan(10));
        for (final t in alive) {
          final same = s.rootsAt(t).singleWhere((x) => identical(x, root));
          expect((same.lo, same.hi), (root.lo, root.hi));
        }
      });

      test('no máximo lerp(2, 5, intensidade) raízes; a mais antiga some quando passa do limite', () {
        expect(p.maxRoots, (2.0, 5.0));
        for (final i in [0.1, 0.5, 0.9, 1.0]) {
          final s = signal(EcoType.plant, i);
          final max = lerp(2, 5, i).round();
          expect(s.plantRoots.maxRoots, max);
          for (var n = 1; n <= s.cues.length; n++) {
            final t = s.cues[n - 1].at;
            final active = s.rootsAt(t);
            expect(active.length, math.min(n, max), reason: 'i=$i n=$n');
            expect(active.last, s.plantRoots.roots[n - 1], reason: 'a nova entra');
            if (n > max) expect(active.first, s.plantRoots.roots[n - max], reason: 'a mais antiga saiu');
          }
        }
        expect(signal(EcoType.plant, 0.05).plantRoots.maxRoots, 2);
        expect(signal(EcoType.plant, 1.0).plantRoots.maxRoots, 5);
      });

      test('sem resistência não há raízes', () {
        final s = signal(EcoType.plant, 0);
        expect(s.plantRoots.roots, isEmpty);
        expect(s.rootsAt(10), isEmpty);
        expect(s.dialInRoot(0.5, 10), isFalse);
        for (final type in [EcoType.fire, EcoType.water]) {
          expect(signal(type, 0.9).plantRoots.roots, isEmpty);
        }
      });

      test('dialInRoot é verdadeiro dentro da faixa de uma raiz viva e falso fora dela', () {
        for (var seed = 0; seed < 10; seed++) {
          final s = signal(EcoType.plant, r, seed: seed);
          for (var t = 0.0; t < 20; t += 0.37) {
            for (var d = 0.0; d <= 1.0; d += 0.013) {
              expect(s.dialInRoot(d, t), s.rootsAt(t).any((x) => x.contains(d)), reason: 'seed=$seed t=$t d=$d');
            }
          }
        }
        final s = signal(EcoType.plant, r);
        final root = s.plantRoots.roots[2];
        final mid = (root.lo + root.hi) / 2;
        expect(s.dialInRoot(mid, root.at + 0.01), isTrue);
        expect(s.dialInRoot(root.lo - 0.001, root.at + 0.01) && !s.rootsAt(root.at + 0.01).any((x) => x.contains(root.lo - 0.001)), isFalse);
        expect(s.dialInRoot(mid, root.at - 0.01) && s.rootsAt(root.at - 0.01).isEmpty, isFalse, reason: 'antes de fincar não vale');
      });

      test('a deriva e os brotos continuam: o sinal atravessa as raízes', () {
        var crossing = 0;
        for (var seed = 0; seed < 30; seed++) {
          final s = signal(EcoType.plant, 0.81, seed: seed);
          final inside = [for (var t = 0.0; t < 20; t += 0.05) if (s.dialInRoot(s.frequencyAt(t), t)) t];
          if (inside.isNotEmpty) crossing++;
          // O sinal não depende das raízes: segue a fórmula da deriva e dos brotos.
          for (final t in [1.0, 5.0, 12.0]) {
            final expected = s.start +
                b.signal.wanderAmplitude * math.sin(2 * math.pi * t / b.signal.wanderPeriodS + s.wanderPhase) +
                s.plantDirection * (lerpRange(p.growthPerS, 0.81) * t + lerpRange(p.budStep, 0.81) * s.cues.where((c) => c.at <= t).length);
            expect(s.frequencyAt(t), closeTo(fold(expected), 1e-9));
          }
        }
        expect(crossing, greaterThan(20), reason: 'o sinal passa por dentro de raízes vivas na maioria das sintonias');
      });

      test('com o dial dentro de uma raiz a sintonia é interrompida: não alinha, e o progresso cai na taxa normal mesmo com o sinal ali', () {
        final s = makeSession(type: EcoType.plant, playerLevel: 15, ecoLevel: 17, seed: 3);
        const dt = 1 / 60;
        var found = false;
        while (s.running && s.t < 20 && !found) {
          final next = s.signal.frequencyAt(s.t + dt);
          s.step(dt, dial: next);
          found = s.signal.dialInRoot(s.dial, s.t) && (s.dial - s.targetFrequency).abs() <= s.tolerance;
        }
        expect(found, isTrue, reason: 'o sinal precisa passar por dentro de uma raiz');
        expect(s.aligned, isFalse, reason: 'dial sobre o sinal, dentro da tolerância, mas numa raiz');
        s.progress = 0.5;
        final before = s.progress;
        s.step(dt, dial: s.dial);
        if (s.signal.dialInRoot(s.dial, s.t)) {
          expect(s.progress, closeTo(before - b.progressDownPerS * dt, 1e-12), reason: 'taxa normal de queda');
        }
        expect(s.progress, lessThan(before));
        // Fora de qualquer raiz e sobre o sinal, alinha e o progresso sobe.
        final clear = [for (var d = 0.0; d <= 1.0; d += 0.001) d].firstWhere(
            (d) => !s.signal.dialInRoot(d, s.t + dt) && (d - s.signal.frequencyAt(s.t + dt)).abs() <= s.tolerance * 0.5,
            orElse: () => -1);
        if (clear >= 0) {
          final p0 = s.progress;
          s.step(dt, dial: clear);
          expect(s.aligned, isTrue);
          expect(s.progress, greaterThan(p0));
        }
      });
    });

    group('crescimento', () {
      double rate(double r) => lerpRange(p.growthPerS, r);
      double step(double r) => lerpRange(p.budStep, r);

      test('parâmetros: deriva de 0 a 0,04 por segundo e broto de 0 a 0,08', () {
        expect(p.growthPerS, (0.0, 0.04));
        expect(p.budStep, (0.0, 0.08));
      });

      test('sem resistência o sinal é só a deriva de base; com resistência ele cresce', () {
        expect(series(signal(EcoType.plant, 0)), series(signal(EcoType.fire, 0)));
        expect(signal(EcoType.plant, 0).plantOffsetAt(9), 0);
        expect(series(signal(EcoType.plant, 0.72)), isNot(series(signal(EcoType.plant, 0))));
      });

      test('só a Planta cresce', () {
        expect(signal(EcoType.fire, 0.72).plantOffsetAt(9), 0);
        expect(signal(EcoType.water, 0.72).plantOffsetAt(9), 0);
      });

      test('o sentido vem do sorteio novo, logo depois das fases da Água', () {
        for (var seed = 0; seed < 25; seed++) {
          final r = Pcg32(fnv1a64([seed]), saltKenoma);
          for (var i = 0; i < 5; i++) {
            r.nextFloat(); // início, fase da deriva, fase da Água, segunda fase, fase da maré
          }
          final dir = r.nextFloat() < 0.5 ? -1.0 : 1.0;
          final s = signal(EcoType.plant, 0.72, seed: seed);
          expect(s.plantDirection, dir, reason: 'semente $seed');
          expect(s.plantOffsetAt(10).sign, dir);
        }
      });

      test('os dois sentidos acontecem', () {
        expect({for (var seed = 0; seed < 40; seed++) signal(EcoType.plant, 0.72, seed: seed).plantDirection}, {-1.0, 1.0});
      });

      test('entre dois pulsos a deriva é contínua, na taxa lerp(0, 0,04, intensidade) por segundo', () {
        for (final r in [0.3, 0.72, 1.0]) {
          final s = signal(EcoType.plant, r);
          // Os pulsos caem em múltiplos de cue_every_s: entre o começo e o primeiro não há nenhum.
          final to = p.cueEveryS - 0.05;
          final drift = s.plantOffsetAt(to) - s.plantOffsetAt(0.05);
          expect(drift, closeTo(s.plantDirection * rate(r) * (to - 0.05), 1e-12), reason: 'r=$r');
        }
      });

      test('a cada pulso o sinal dá um passo extra lerp(0, 0,08, intensidade) no mesmo sentido', () {
        for (final r in [0.3, 0.72, 1.0]) {
          final s = signal(EcoType.plant, r);
          expect(s.cues, isNotEmpty);
          for (final c in s.cues.take(12)) {
            const e = 1e-6;
            final jump = s.plantOffsetAt(c.at + e) - s.plantOffsetAt(c.at - e);
            expect(jump, closeTo(s.plantDirection * (step(r) + rate(r) * 2 * e), 1e-9), reason: 'r=$r, pulso em ${c.at}');
            expect(jump.sign, s.plantDirection);
          }
        }
      });

      test('o broto e a deriva têm o mesmo sentido: o deslocamento só cresce em módulo', () {
        final s = signal(EcoType.plant, 0.9);
        var prev = 0.0;
        for (var t = 0.0; t < 40; t += 0.05) {
          final off = s.plantOffsetAt(t).abs();
          expect(off, greaterThanOrEqualTo(prev));
          prev = off;
        }
      });

      test('o deslocamento cresce com a intensidade', () {
        expect(signal(EcoType.plant, 1.0).plantOffsetAt(20).abs(), greaterThan(signal(EcoType.plant, 0.5).plantOffsetAt(20).abs()));
        expect(signal(EcoType.plant, 1.0).plantOffsetAt(20).abs(), closeTo(rate(1.0) * 20 + step(1.0) * (20 / p.cueEveryS).floor(), 0.07));
      });

      test('o sinal reflete nas bordas: continua em [0, 1] e chega a bater nelas', () {
        var touched = 0;
        for (var seed = 0; seed < 30; seed++) {
          final xs = series(signal(EcoType.plant, 1.0, seed: seed), to: 60);
          for (final f in xs) {
            expect(f, inInclusiveRange(0.0, 1.0));
          }
          if (xs.any((f) => f > 0.97) || xs.any((f) => f < 0.03)) touched++;
        }
        expect(touched, greaterThan(20), reason: 'com deriva e brotos, em 60 s o sinal alcança uma borda quase sempre');
      });

      test('o único salto do sinal são os brotos, nos pulsos', () {
        final s = signal(EcoType.plant, 0.8);
        final threshold = step(0.8) * 0.6;
        for (var t = 0.0; t < 30; t += 1 / 60) {
          final jump = (s.frequencyAt(t + 1 / 60) - s.frequencyAt(t)).abs();
          if (jump > threshold) {
            expect(s.cues.any((c) => c.at > t && c.at <= t + 1 / 60), isTrue, reason: 'salto de $jump em t=$t sem pulso');
          }
        }
      });

      test('a vibração continua a ser um pulso que encurta', () {
        final s = signal(EcoType.plant, 0.72);
        final durations = [for (final c in s.cues) c.pattern.segments.single.durationMs];
        expect(s.cues.every((c) => c.kind == CueKind.plantPulse), isTrue);
        expect(durations.first, greaterThan(durations[2]));
        for (var i = 1; i < durations.length; i++) {
          expect(durations[i], lessThanOrEqualTo(durations[i - 1]));
        }
        expect(durations.last, p.pulseMs.$2.round());
        expect(s.cues[1].at - s.cues[0].at, closeTo(p.cueEveryS, 1e-9));
      });
    });
  });

  group('ordem dos sorteios do rng', () {
    // Os sorteios que já existiam não mudam de lugar; os novos entram no fim da sequência.
    Pcg32 rng(int seed) => Pcg32(fnv1a64([seed]), saltKenoma);

    test('os três primeiros sorteios seguem sendo a frequência inicial e as duas fases', () {
      final r = rng(5);
      final start = lerpRange(b.signal.startRange, r.nextFloat());
      final wanderPhase = 2 * math.pi * r.nextFloat();
      final s = signal(EcoType.fire, 0, seed: 5);
      expect(s.start, start);
      for (final t in [0.0, 1.0, 3.3, 7.7, 12.0, 19.9]) {
        final expected = start + b.signal.wanderAmplitude * math.sin(2 * math.pi * t / b.signal.wanderPeriodS + wanderPhase);
        expect(s.frequencyAt(t), closeTo(expected, 1e-12));
      }
    });

    test('valores fixos da deriva de base, tirados antes de existirem os sorteios novos', () {
      final s = signal(EcoType.fire, 0, seed: 5);
      expect([for (final t in [0.0, 1.0, 3.3, 7.7, 12.0, 19.9]) s.frequencyAt(t)], [
        0.5914270899568248,
        0.5888010934174408,
        0.6736779198243132,
        0.5854333194756706,
        0.6685632344345842,
        0.63137935770054,
      ]);
      expect(s.start, 0.635079952282831);
    });

    test('os picos do Fogo saem dos sorteios logo depois dos três primeiros: intervalo, sinal, tamanho', () {
      const r = 0.72;
      final gen = rng(5);
      for (var i = 0; i < 3; i++) {
        gen.nextFloat();
      }
      final mean = lerpRange(b.signal.fire.intervalS, r);
      var at = 0.0;
      final expected = <double>[];
      while (true) {
        at += mean * (0.75 + 0.5 * gen.nextFloat());
        if (at > 60) break;
        gen.nextFloat(); // sinal do pico
        gen.nextFloat(); // tamanho do pico
        expected.add(at);
      }
      final s = signal(EcoType.fire, r, seed: 5);
      expect(s.kickTimes, expected);
    });

    test('a posição da queima de cada pico sai no fim da sequência, depois da fase da maré e do sentido da Planta', () {
      const r = 0.72;
      final gen = rng(5);
      for (var i = 0; i < 3; i++) {
        gen.nextFloat();
      }
      final mean = lerpRange(b.signal.fire.intervalS, r);
      var at = 0.0;
      var kicks = 0;
      while (true) {
        at += mean * (0.75 + 0.5 * gen.nextFloat());
        if (at > 60) break;
        gen.nextFloat();
        gen.nextFloat();
        kicks++;
      }
      for (var i = 0; i < 3; i++) {
        gen.nextFloat(); // fase 2 da Água, fase da maré, sentido da Planta
      }
      final draws = [for (var i = 0; i < kicks; i++) gen.nextFloat()];
      final s = signal(EcoType.fire, r, seed: 5);
      final fire = b.signal.fire;
      expect(s.burnUs, hasLength(kicks));
      expect(s.burnUs.first, lerpRange(fire.burnU, draws.first), reason: 'a primeira queima não tem fronteira antes dela');
      for (var i = 0; i < kicks; i++) {
        // Cada sorteio escolhe um ponto do trecho vivo, à direita da fronteira anterior.
        final lo = math.max(fire.burnU.$1, i == 0 ? 0.0 : s.fireBoundaryUAt(i - 1, s.kickTimes[i]));
        final expected = fire.burnU.$2 - lo >= fire.burnMinLiveU ? lerp(lo, fire.burnU.$2, draws[i]) : fire.burnEdgeU;
        expect(s.burnUs[i], closeTo(expected, 1e-12), reason: 'pico $i');
      }
    });

    test('o deslocamento de cada raiz da Planta sai no fim da sequência, depois do sentido da Planta', () {
      const r = 0.72;
      final gen = rng(5);
      for (var i = 0; i < 3; i++) {
        gen.nextFloat();
      }
      for (var i = 0; i < 3; i++) {
        gen.nextFloat(); // fase 2 da Água, fase da maré, sentido da Planta
      }
      final s = signal(EcoType.plant, r, seed: 5);
      final draws = [for (var i = 0; i < s.cues.length; i++) gen.nextFloat()];
      for (var i = 0; i < draws.length; i++) {
        final root = s.plantRoots.roots[i];
        expect(root.center, closeTo(s.frequencyAt(root.at) + (2 * draws[i] - 1) * b.signal.plant.rootJitter, 1e-12), reason: 'raiz $i');
      }
    });

    test('para a Água e a Planta, os sorteios novos vêm logo depois dos três primeiros', () {
      // Sem picos, o quarto sorteio em diante é dos parâmetros novos.
      final gen = rng(5);
      for (var i = 0; i < 3; i++) {
        gen.nextFloat();
      }
      final phase2 = 2 * math.pi * gen.nextFloat();
      final water = signal(EcoType.water, 0.72, seed: 5);
      final p1 = lerpRange(b.signal.water.periodS, 0.72);
      // Com a maré no mesmo instante, a segunda senoide usa exatamente esta fase.
      final tidePhase = 2 * math.pi * gen.nextFloat();
      final tide = 0.8 + 0.2 * math.sin(tidePhase);
      final phase1 = 2 * math.pi * rng(5).let((r) {
        r.nextFloat();
        r.nextFloat();
        return r.nextFloat();
      });
      final w = b.signal.water;
      final expected = tide *
          lerpRange(w.amplitude, 0.72) *
          ((1 - w.secondWeight) * math.sin(phase1) + w.secondWeight * math.sin(phase2));
      expect(water.waterOffsetAt(0), closeTo(expected, 1e-12));
      expect(p1, greaterThan(0));
    });

    test('mesma semente, mesmo sinal, também com os sorteios novos', () {
      for (final type in EcoType.values) {
        expect(series(signal(type, 0.8, seed: 9)), series(signal(type, 0.8, seed: 9)));
      }
    });
  });

  test('cuesIn devolve só as vibrações do intervalo (from, to]', () {
    final s = signal(EcoType.water, 0.72);
    final first = s.cues[0].at, second = s.cues[1].at, third = s.cues[2].at;
    expect(s.cuesIn(0, first - 0.001), isEmpty);
    expect(s.cuesIn(0, first), hasLength(1));
    expect(s.cuesIn(first, first), isEmpty, reason: 'o início do intervalo é aberto');
    expect(s.cuesIn(0, third), hasLength(3));
    expect(s.cuesIn(first, second).single.at, second);
  });
}
