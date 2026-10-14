import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/save/save_store.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kenoma_save'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('grava, lê e não deixa temporário', () async {
    final store = FileSaveStore(File('${dir.path}/save.json'));
    expect(await store.read(), isNull);
    await store.write({'a': 1});
    expect(await store.read(), {'a': 1});
    expect(File('${dir.path}/save.json.tmp').existsSync(), isFalse);
  });

  test('arquivo ilegível vira .bad e o jogo recomeça sem apagar nada', () async {
    final f = File('${dir.path}/save.json')..writeAsStringSync('{quebrado');
    expect(await FileSaveStore(f).read(), isNull);
    expect(File('${dir.path}/save.json.bad').readAsStringSync(), '{quebrado');
  });
}
