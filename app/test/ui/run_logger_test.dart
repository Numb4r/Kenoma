import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';
import 'package:kenoma/data/session_log_store.dart';
import 'package:kenoma/data/tuning_data.dart';
import 'package:kenoma/ui/tuning/run_logger.dart';
import 'package:kenoma/ui/tuning/tuning_game.dart';

import '../support/reference_player.dart';

TuningRun makeRun({EcoType type = EcoType.water, int seed = 3, bool success = true}) {
  final b = loadTuningBalance();
  final setup = TuningSetup(type: type, ecoLevel: 6, playerLevel: 5, seal: sealById('item.seal.reinforced'));
  final session = setup.start(b, Pcg32(fnv1a64([seed]), saltKenoma));
  while (session.running) {
    session.step(1 / 60, dial: success ? session.targetFrequency : (session.targetFrequency > 0.5 ? 0 : 1));
  }
  return TuningRun(
    setup: setup,
    species: EcoSpecies(id: '$type', name: type.name, type: type),
    session: session,
    outcome: resolveTuning(session, Pcg32(1, saltKenoma)),
  );
}

void main() {
  late Directory dir;
  late SessionLogStore store;
  final b = loadTuningBalance();
  final now = DateTime.utc(2026, 9, 29, 15, 0, 0);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kenoma_logger_');
    store = SessionLogStore(File('${dir.path}/sessions.csv'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  RunLogger logger({required bool hidden}) => RunLogger(store: store, balance: b, hidden: hidden, clock: () => now);

  List<List<String>> rows() => [for (final l in store.file.readAsLinesSync().skip(1)) l.split(',')];

  test('fora do modo oculto grava assim que a sintonia termina, com o acerto em branco', () async {
    await logger(hidden: false).finished(makeRun());
    final r = rows().single;
    expect(r[0], '2026-09-29T15:00:00.000Z');
    expect(r[1], 'water');
    expect((r[2], r[3]), ('6', '5'));
    expect(r[4], 'item.seal.reinforced');
    expect(r[5], '0');
    expect(r[9], 'success');
    expect((r[12], r[13]), ('0', ''));
  });

  test('modo oculto: palpite certo grava guess_correct 1, errado grava 0', () async {
    final l = logger(hidden: true);
    l.guessed(EcoType.fire);
    await l.finished(makeRun(type: EcoType.fire));
    l.guessed(EcoType.water);
    await l.finished(makeRun(type: EcoType.plant));
    final r = rows();
    expect(r, hasLength(2));
    expect((r[0][1], r[0][12], r[0][13]), ('fire', '1', '1'));
    expect((r[1][1], r[1][12], r[1][13]), ('plant', '1', '0'));
  });

  test('o palpite vale só para a sintonia seguinte: sem novo palpite o acerto fica em branco', () async {
    final l = logger(hidden: true);
    l.guessed(EcoType.fire);
    await l.finished(makeRun(type: EcoType.fire));
    await l.finished(makeRun(type: EcoType.fire));
    final r = rows();
    expect(r[0][13], '1');
    expect(r[1][13], '', reason: 'o palpite anterior não vaza para a sintonia seguinte');
  });

  test('fora do modo oculto um palpite perdido no ar não entra no registro', () async {
    final l = logger(hidden: false);
    l.guessed(EcoType.fire);
    await l.finished(makeRun(type: EcoType.fire));
    expect(rows().single[13], '');
  });

  test('sintonia que não terminou não é gravada', () async {
    final l = logger(hidden: true);
    l.guessed(EcoType.fire);
    expect(store.file.existsSync(), isFalse);
  });

  test('grava o que a sessão mediu: falha, tempo alinhado e perdas', () async {
    final run = makeRun(success: false);
    await logger(hidden: false).finished(run);
    final r = rows().single;
    expect(r[9], 'fail');
    expect(double.parse(r[8]), closeTo(run.session.t, 0.005));
    expect(double.parse(r[10]), closeTo(run.session.alignedTimeS, 0.005));
    expect(int.parse(r[11]), run.session.alignmentLosses);
    expect(run.session.phase, TuningPhase.failed);
  });

  test('uma falha de escrita não derruba o jogo', () async {
    final broken = SessionLogStore(File('${dir.path}/sessions.csv/x/y.csv'));
    File('${dir.path}/sessions.csv').writeAsStringSync('arquivo no lugar da pasta');
    final l = RunLogger(store: broken, balance: b, hidden: false, clock: () => now);
    await l.finished(makeRun());
  });
}
