import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/session_record.dart';
import 'package:kenoma/capture/tuning_setup.dart';

import '../support/reference_player.dart';

void main() {
  const dt = 1 / 60;

  group('estatísticas da sessão', () {
    TuningSession fresh() => makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 1)..dial = 0;
    double far(TuningSession s) => s.targetFrequency > 0.5 ? 0.0 : 1.0;

    void run(TuningSession s, int steps, {required bool aligned}) {
      for (var i = 0; i < steps; i++) {
        s.step(dt, dial: aligned ? s.targetFrequency : far(s));
      }
    }

    test('sem nunca alinhar: tempo alinhado 0 e nenhuma perda', () {
      final s = fresh();
      run(s, 120, aligned: false);
      expect(s.alignedTimeS, 0);
      expect(s.alignmentLosses, 0, reason: 'não dá para perder o que nunca se teve');
    });

    test('alinhado o tempo todo: tempo alinhado é o tempo da sessão, sem perdas', () {
      final s = fresh();
      run(s, 400, aligned: true);
      expect(s.alignedTimeS, closeTo(s.t, 1e-9));
      expect(s.alignmentLosses, 0);
      expect(s.phase, TuningPhase.success);
      expect(s.alignedTimeS, closeTo(5.0, 0.05));
    });

    test('cada passagem de alinhado para desalinhado conta uma perda; o tempo alinhado só soma alinhado', () {
      final s = fresh();
      run(s, 60, aligned: true); // 1 s alinhado
      run(s, 30, aligned: false); // perda 1
      run(s, 30, aligned: true); // 0,5 s alinhado
      run(s, 30, aligned: false); // perda 2
      run(s, 30, aligned: false); // continua fora: sem perda nova
      expect(s.alignmentLosses, 2);
      expect(s.alignedTimeS, closeTo(1.5, 1e-9));
    });

    test('a sessão terminada congela as estatísticas', () {
      final s = fresh();
      run(s, 400, aligned: true);
      final (aligned, losses) = (s.alignedTimeS, s.alignmentLosses);
      s.step(1, dial: 0);
      expect((s.alignedTimeS, s.alignmentLosses), (aligned, losses));
    });

    test('o alinhamento na borda da tolerância conta como alinhado', () {
      final s = fresh();
      s.step(dt, dial: s.signal.frequencyAt(dt) + s.baseTolerance - 1e-9);
      expect(s.alignedTimeS, closeTo(dt, 1e-12));
    });
  });

  group('linha do CSV', () {
    final at = DateTime.utc(2026, 9, 29, 14, 30, 5, 250);
    SessionRecord record({bool? guess, bool hidden = false, bool success = true, bool tonic = false, String seal = 'item.seal.simple'}) =>
        SessionRecord(
          timeUtc: at,
          type: EcoType.water,
          ecoLevel: 17,
          playerLevel: 15,
          sealId: seal,
          tonic: tonic,
          tolerance: 0.112,
          resistance: 0.76,
          durationS: 12.3456,
          success: success,
          alignedTimeS: 8.5,
          alignmentLosses: 4,
          hiddenType: hidden,
          guessCorrect: guess,
        );

    test('cabeçalho: os campos pedidos, na ordem', () {
      expect(SessionRecord.header,
          'timestamp_utc,type,eco_level,player_level,seal,tonic,tolerance,resistance,duration_s,result,aligned_s,alignment_losses,hidden_type,guess_correct');
      expect(SessionRecord.columns, hasLength(14));
    });

    test('linha completa, com horário em UTC', () {
      expect(record().toCsvLine(),
          '2026-09-29T14:30:05.250Z,water,17,15,item.seal.simple,0,0.112,0.760,12.35,success,8.50,4,0,');
    });

    test('a linha tem tantos campos quanto o cabeçalho', () {
      for (final r in [record(), record(guess: true, hidden: true), record(success: false, tonic: true)]) {
        expect(r.toCsvLine().split(','), hasLength(SessionRecord.columns.length));
      }
    });

    test('tônico, falha e tipo oculto', () {
      final fields = record(success: false, tonic: true, hidden: true, guess: false).toCsvLine().split(',');
      expect(fields[5], '1');
      expect(fields[9], 'fail');
      expect(fields[12], '1');
      expect(fields[13], '0');
      expect(record(guess: true, hidden: true).toCsvLine().split(',').last, '1');
      expect(record(hidden: true).toCsvLine().split(',').last, '', reason: 'sem marcação fica vazio');
    });

    test('horário local vira UTC e números usam ponto decimal', () {
      final local = SessionRecord(
        timeUtc: DateTime.parse('2026-09-29T11:30:05-03:00').toUtc(),
        type: EcoType.fire,
        ecoLevel: 1,
        playerLevel: 1,
        sealId: 'x',
        tonic: false,
        tolerance: 0.08,
        resistance: 0,
        durationS: 5,
        success: true,
        alignedTimeS: 5,
        alignmentLosses: 0,
      );
      final f = local.toCsvLine().split(',');
      expect(f[0], '2026-09-29T14:30:05.000Z');
      expect(f[6], '0.080');
      expect(f[7], '0.000');
    });

    test('campo com vírgula ou aspas vai entre aspas', () {
      final f = record(seal: 'selo "raro", forte').toCsvLine();
      expect(f, contains('"selo ""raro"", forte"'));
    });
  });

  test('SessionRecord.of copia o que a sessão e a preparação mediram', () {
    final b = loadTuningBalance();
    final setup = TuningSetup(
      type: EcoType.plant,
      ecoLevel: 17,
      playerLevel: 15,
      seal: sealById('item.seal.reinforced'),
      tonic: loadTuningItems().tonics.first,
    );
    final session = makeSession(type: EcoType.plant, playerLevel: 15, ecoLevel: 17, seed: 4);
    const ReferencePlayer().play(session);
    final at = DateTime(2026, 9, 29, 11, 30);
    final r = SessionRecord.of(setup: setup, session: session, balance: b, at: at, hiddenType: true, guessCorrect: true);
    expect(r.type, EcoType.plant);
    expect((r.ecoLevel, r.playerLevel), (17, 15));
    expect(r.sealId, 'item.seal.reinforced');
    expect(r.tonic, isTrue);
    expect(r.tolerance, closeTo(0.11, 1e-12));
    expect(r.resistance, closeTo(0.81, 1e-12));
    expect(r.durationS, session.t);
    expect(r.success, session.phase == TuningPhase.success);
    expect(r.alignedTimeS, session.alignedTimeS);
    expect(r.alignmentLosses, session.alignmentLosses);
    expect(r.hiddenType, isTrue);
    expect(r.guessCorrect, isTrue);
    expect(r.timeUtc.isUtc, isTrue);
    expect(r.timeUtc, at.toUtc());
  });
}
