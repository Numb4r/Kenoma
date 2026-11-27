import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/sha_memo.dart';

/// 0.26.3: o SHA-256 de um pacote de região só é refeito depois de instalar ou atualizar o app, ou quando o arquivo muda.
void main() {
  final bytes = utf8.encode('pacote de teste');
  final good = sha256.convert(bytes).toString();
  tearDown(() => ShaMemo.current = null);

  test('o que bateu fica guardado para a mesma instalação; outra instalação confere tudo de novo', () {
    final memo = ShaMemo.current = ShaMemo('0.26.3+56@1');
    expect(shaMatches(bytes, good, name: 'campinas_e0_vis.bin'), isTrue);
    expect(memo.has(ShaMemo.keyOf('campinas_e0_vis.bin', bytes.length, good)), isTrue);
    final again = ShaMemo.fromJson(memo.toJson(), '0.26.3+56@1');
    expect(again.has(ShaMemo.keyOf('campinas_e0_vis.bin', bytes.length, good)), isTrue);
    final updated = ShaMemo.fromJson(memo.toJson(), '0.26.4+57@2');
    expect(updated.has(ShaMemo.keyOf('campinas_e0_vis.bin', bytes.length, good)), isFalse, reason: 'atualizou: confere de novo');
  });

  test('o que não bateu não fica guardado e continua falhando', () {
    final memo = ShaMemo.current = ShaMemo('x');
    final bad = '0' * 64;
    expect(shaMatches(bytes, bad, name: 'campinas_e0_vis.bin'), isFalse);
    expect(memo.has(ShaMemo.keyOf('campinas_e0_vis.bin', bytes.length, bad)), isFalse);
    expect(shaMatches(bytes, bad, name: 'campinas_e0_vis.bin'), isFalse);
  });

  test('sem memória (testes, outro isolate) confere sempre', () {
    expect(shaMatches(bytes, good, name: 'a.bin'), isTrue);
    expect(shaMatches(bytes, '0' * 64, name: 'a.bin'), isFalse);
  });

  test('o arquivo baixado muda de chave quando muda de tamanho ou data; grava e reabre', () async {
    final dir = Directory.systemTemp.createTempSync('kenoma_sha_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/sao_paulo_e5_vis.bin')..writeAsBytesSync(bytes);
    final k1 = ShaMemo.fileKey(f.path, good)!;
    f.writeAsBytesSync([...bytes, 1]);
    expect(ShaMemo.fileKey(f.path, good), isNot(k1), reason: 'outro tamanho');
    final store = File('${dir.path}/sha.json');
    final memo = await ShaMemo.open(store, 'i1');
    memo.add(k1);
    await memo.save();
    expect((await ShaMemo.open(store, 'i1')).has(k1), isTrue);
    expect((await ShaMemo.open(store, 'i2')).has(k1), isFalse);
    expect(ShaMemo.fileKey('${dir.path}/nao_existe.bin', good), isNull);
  });
}
