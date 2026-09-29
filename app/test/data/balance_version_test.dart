import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/balance_version.dart';
import 'package:kenoma/data/tuning_data.dart';

void main() {
  test('são os 8 primeiros caracteres do SHA-256: vetores conhecidos', () {
    expect(balanceVersionOf(const []), 'e3b0c442'); // SHA-256 de ""
    expect(balanceVersionOf('abc'.codeUnits), 'ba7816bf'); // SHA-256 de "abc"
  });

  test('8 caracteres hexadecimais minúsculos, sempre', () {
    for (final s in ['', 'a', '{"tuning": {}}', 'x' * 1000]) {
      expect(balanceVersionOf(s.codeUnits), matches(RegExp(r'^[0-9a-f]{8}$')));
    }
  });

  test('qualquer mudança no arquivo muda a versão, até um espaço; o mesmo conteúdo dá a mesma', () {
    final bytes = File('assets/data/balance.json').readAsBytesSync();
    final base = balanceVersionOf(bytes);
    expect(balanceVersionOf(List.of(bytes)), base);
    expect(balanceVersionOf([...bytes, 0x20]), isNot(base));
    expect(balanceVersionOf(File('assets/data/balance.json').readAsStringSync().replaceFirst('0.045', '0.046').codeUnits), isNot(base));
  });

  testWidgets('o balance.json carregado pelo app tem a versão do arquivo em disco', (tester) async {
    for (final name in ['balance', 'creatures', 'items']) {
      rootBundle.evict('assets/data/$name.json');
    }
    final data = (await tester.runAsync(TuningData.load))!;
    expect(data.balanceVersion, balanceVersionOf(File('assets/data/balance.json').readAsBytesSync()));
    expect(data.balanceVersion, hasLength(8));
  });
}
