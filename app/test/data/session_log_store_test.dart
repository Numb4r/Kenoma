import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session_record.dart';
import 'package:kenoma/data/session_log_store.dart';

SessionRecord rec(int n) => SessionRecord(
      timeUtc: DateTime.utc(2026, 9, 29, 12, n),
      type: EcoType.fire,
      ecoLevel: n,
      playerLevel: 1,
      sealId: 'item.seal.simple',
      tonic: false,
      tolerance: 0.08,
      resistance: 0,
      durationS: 5.5,
      success: true,
      alignedTimeS: 5,
      alignmentLosses: 0,
    );

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kenoma_log_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('sem arquivo: zero sessões', () async {
    expect(await SessionLogStore(File('${dir.path}/sessions.csv')).count(), 0);
  });

  test('a primeira gravação escreve o cabeçalho, as seguintes só a linha', () async {
    final file = File('${dir.path}/sessions.csv');
    final store = SessionLogStore(file);
    await store.append(rec(1));
    await store.append(rec(2));
    await store.append(rec(3));
    final lines = file.readAsLinesSync();
    expect(lines, hasLength(4));
    expect(lines.first, SessionRecord.header);
    expect(lines[1], rec(1).toCsvLine());
    expect(lines[3], rec(3).toCsvLine());
    expect(lines.where((l) => l == SessionRecord.header), hasLength(1));
    expect(await store.count(), 3);
  });

  test('cria a pasta que faltar', () async {
    final store = SessionLogStore(File('${dir.path}/a/b/sessions.csv'));
    await store.append(rec(1));
    expect(await store.count(), 1);
  });

  test('um arquivo vazio recebe o cabeçalho', () async {
    final file = File('${dir.path}/sessions.csv')..writeAsStringSync('');
    await SessionLogStore(file).append(rec(1));
    expect(file.readAsLinesSync().first, SessionRecord.header);
  });

  test('outra instância continua o mesmo arquivo, sem repetir o cabeçalho', () async {
    final file = File('${dir.path}/sessions.csv');
    await SessionLogStore(file).append(rec(1));
    final again = SessionLogStore(file);
    await again.append(rec(2));
    expect(await again.count(), 2);
    expect(file.readAsLinesSync().where((l) => l == SessionRecord.header), hasLength(1));
  });
}
