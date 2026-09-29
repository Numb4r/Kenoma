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
      balanceVersion: 'a1b2c3d4',
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

  test('gravações sobrepostas não perdem linhas: sai um cabeçalho e todas as linhas, na ordem', () async {
    final file = File('${dir.path}/sessions.csv');
    final store = SessionLogStore(file);
    await Future.wait([for (var i = 1; i <= 8; i++) store.append(rec(i))]);
    final lines = file.readAsLinesSync();
    expect(lines, hasLength(9));
    expect(lines.first, SessionRecord.header);
    expect(lines.skip(1).toList(), [for (var i = 1; i <= 8; i++) rec(i).toCsvLine()]);
    expect(await store.count(), 8);
  });

  test('uma gravação que falha não trava as seguintes', () async {
    final store = SessionLogStore(File('${dir.path}/sessions.csv'));
    final first = store.append(_Broken());
    final second = store.append(rec(2));
    await expectLater(first, throwsStateError);
    await second;
    expect(await store.count(), 1);
    expect(store.file.readAsLinesSync().last, rec(2).toCsvLine());
  });

  group('migração do formato antigo (sem balance_version)', () {
    // Linhas como o app as gravava antes da coluna existir: 14 campos.
    const oldRows = [
      '2026-09-29T15:01:00.000000Z,fire,1,1,item.seal.simple,0,0.080,0.000,5.50,success,5.00,0,0,',
      '2026-09-29T15:02:00.000000Z,water,17,15,item.seal.reinforced,1,0.110,0.810,20.00,fail,3.65,3,1,1',
      '2026-09-29T15:03:00.000000Z,plant,9,9,item.seal.fire,0,0.080,0.300,12.34,success,5.10,2,1,0',
    ];
    late File file;
    late SessionLogStore store;
    File tmp() => File('${file.path}.tmp');

    void writeLegacy(List<String> rows, {bool trailingNewline = true}) =>
        file.writeAsStringSync('${SessionRecord.legacyHeader}\n${rows.join('\n')}${trailingNewline ? '\n' : ''}');

    setUp(() {
      file = File('${dir.path}/sessions.csv');
      store = SessionLogStore(file);
    });

    test('cada linha antiga ganha pre-ajuste no fim e o cabeçalho ganha balance_version', () async {
      writeLegacy(oldRows);
      await store.migrate();
      final lines = file.readAsLinesSync();
      expect(lines.first, SessionRecord.header);
      expect(lines.skip(1).toList(), [for (final r in oldRows) '$r,pre-ajuste']);
      expect(await store.count(), 3);
    });

    test('nenhuma linha se perde: as 24 do celular, em ordem e sem mudar um caractere', () async {
      final many = [for (var i = 0; i < 24; i++) '2026-09-29T15:${i.toString().padLeft(2, '0')}:00.000000Z,fire,${i + 1},1,item.seal.simple,0,0.080,0.000,5.50,success,5.00,0,0,'];
      writeLegacy(many);
      await store.migrate();
      final lines = file.readAsLinesSync();
      expect(lines, hasLength(25));
      for (var i = 0; i < 24; i++) {
        expect(lines[i + 1], '${many[i]},pre-ajuste');
      }
      expect(await store.count(), 24);
    });

    test('guarda uma cópia idêntica do arquivo antigo antes de migrar', () async {
      writeLegacy(oldRows);
      final original = file.readAsBytesSync();
      await store.migrate();
      expect(store.backup.existsSync(), isTrue);
      expect(store.backup.readAsBytesSync(), original);
      expect(file.readAsBytesSync(), isNot(original));
    });

    test('não sobra arquivo temporário', () async {
      writeLegacy(oldRows);
      await store.migrate();
      expect(tmp().existsSync(), isFalse);
    });

    test('rodar de novo não muda nada, nem a cópia', () async {
      writeLegacy(oldRows);
      await store.migrate();
      final after = file.readAsBytesSync();
      final backup = store.backup.readAsBytesSync();
      await store.migrate();
      await SessionLogStore(file).migrate();
      expect(file.readAsBytesSync(), after);
      expect(store.backup.readAsBytesSync(), backup);
      expect(file.readAsStringSync().split('pre-ajuste').length - 1, 3, reason: 'pre-ajuste não se acumula');
    });

    test('uma cópia que já existia não é sobrescrita', () async {
      writeLegacy(oldRows);
      store.backup.writeAsStringSync('cópia anterior');
      await store.migrate();
      expect(store.backup.readAsStringSync(), 'cópia anterior');
      expect(file.readAsLinesSync().first, SessionRecord.header);
    });

    test('arquivo sem quebra de linha no fim também migra', () async {
      writeLegacy(oldRows, trailingNewline: false);
      await store.migrate();
      expect(file.readAsLinesSync().skip(1).toList(), [for (final r in oldRows) '$r,pre-ajuste']);
    });

    test('gravar num arquivo antigo migra primeiro: linhas antigas com pre-ajuste, a nova com a versão dela', () async {
      writeLegacy(oldRows);
      await store.append(rec(7));
      final lines = file.readAsLinesSync();
      expect(lines, hasLength(5));
      expect(lines.first, SessionRecord.header);
      expect(lines.sublist(1, 4), [for (final r in oldRows) '$r,pre-ajuste']);
      expect(lines.last, rec(7).toCsvLine());
      expect(lines.last.split(',').last, 'a1b2c3d4');
      expect(lines.where((l) => l == SessionRecord.header), hasLength(1));
    });

    test('migrar e gravar ao mesmo tempo não perde linha', () async {
      writeLegacy(oldRows);
      await Future.wait([store.migrate(), store.append(rec(1)), store.append(rec(2)), store.migrate()]);
      final lines = file.readAsLinesSync();
      expect(lines, hasLength(6));
      expect(lines.sublist(1, 4), [for (final r in oldRows) '$r,pre-ajuste']);
      expect(lines.sublist(4), [rec(1).toCsvLine(), rec(2).toCsvLine()]);
    });

    test('sem arquivo ou com arquivo vazio não faz nada', () async {
      await store.migrate();
      expect(file.existsSync(), isFalse);
      expect(store.backup.existsSync(), isFalse);
      file.writeAsStringSync('');
      await store.migrate();
      expect(file.readAsStringSync(), '');
      expect(store.backup.existsSync(), isFalse);
    });

    test('um arquivo já no formato atual fica como está, sem cópia', () async {
      await store.append(rec(1));
      final before = file.readAsBytesSync();
      await store.migrate();
      expect(file.readAsBytesSync(), before);
      expect(store.backup.existsSync(), isFalse);
    });

    test('um cabeçalho que não é o anterior não é tocado', () async {
      file.writeAsStringSync('outra,coisa\n1,2\n');
      final before = file.readAsBytesSync();
      await store.migrate();
      expect(file.readAsBytesSync(), before);
      expect(store.backup.existsSync(), isFalse);
    });

    test('se a escrita do arquivo novo falha, o arquivo original fica intacto', () async {
      writeLegacy(oldRows);
      final original = file.readAsBytesSync();
      Directory(tmp().path).createSync(); // o temporário não pode ser criado: há uma pasta no lugar
      await expectLater(store.migrate(), throwsA(isA<FileSystemException>()));
      expect(file.readAsBytesSync(), original);
      expect(await store.count(), 3);
      expect(store.backup.readAsBytesSync(), original);
    });

    test('depois de uma falha, as gravações seguintes ainda funcionam', () async {
      writeLegacy(oldRows);
      Directory(tmp().path).createSync();
      await expectLater(store.append(rec(1)), throwsA(isA<FileSystemException>()));
      Directory(tmp().path).deleteSync();
      await store.append(rec(2));
      final lines = file.readAsLinesSync();
      expect(lines.first, SessionRecord.header);
      expect(lines.sublist(1, 4), [for (final r in oldRows) '$r,pre-ajuste']);
      expect(lines.last, rec(2).toCsvLine());
    });
  });
}

class _Broken extends SessionRecord {
  _Broken()
      : super(
          timeUtc: DateTime.utc(2026),
          type: EcoType.fire,
          ecoLevel: 1,
          playerLevel: 1,
          sealId: 's',
          tonic: false,
          tolerance: 0,
          resistance: 0,
          durationS: 0,
          success: false,
          alignedTimeS: 0,
          alignmentLosses: 0,
          balanceVersion: 'a1b2c3d4',
        );

  @override
  String toCsvLine() => throw StateError('linha inválida');
}
