import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/relief_pack.dart';

void main() {
  test('interpolação bilinear entre as quatro amostras, com vetores fixos', () {
    // Grade z20 de 3 x 2 com o canto em (10, 20): alturas em decímetros.
    final r = ReliefPack(20, 10, 20, 3, 2, Int16List.fromList([1000, 2000, 4000, 3000, 6000, 8000]));
    expect(r.heightAt(21, 41), 100.0, reason: 'o centro da primeira amostra');
    expect(r.heightAt(23, 41), 200.0);
    expect(r.heightAt(22, 41), 150.0);
    expect(r.heightAt(21, 42), 200.0);
    expect(r.heightAt(22, 42), 300.0, reason: 'a média das quatro');
    expect(r.heightAt(24.5, 42.5), closeTo(650.0, 1e-9));
    expect(r.heightAt(20.9, 41), isNull, reason: 'fora da grade');
    expect(r.heightAt(25, 41), isNull);
    expect(r.heightAt(21, 43), isNull);
  });

  test('formato: recusa magic e tamanho errados', () {
    expect(() => ReliefPack.parse(Uint8List(30)), throwsFormatException);
  });

  test('relevo de Campinas: o arquivo da época 9 não muda e bate com lugares conhecidos', () {
    final bytes = File('assets/regions/campinas_e9_relief.bin').readAsBytesSync();
    expect(sha256.convert(bytes).toString(), '1bb9c5acd6f6e09f49af449b7bd7f026cc30d237fa167bf4ac209278481e7d86');
    final r = ReliefPack.parse(bytes);
    expect((r.zoom, r.width, r.height), (20, 1169, 1206));
    double at(double lat, double lon) {
      final (x, y) = latLonToTileFraction(lat, lon, 21);
      return r.heightAt(x, y)!;
    }

    // Vetores fixos (decímetro): a lagoa do Taquaral fica mais baixa que o Centro, e o Castelo mais alto.
    expect(at(-22.8745, -47.0500), closeTo(655.2, 1.5));
    expect(at(-22.9056, -47.0608), closeTo(685.6, 1.5));
    expect(at(-22.8880, -47.0780), closeTo(732.0, 1.5));
    expect(at(-22.8745, -47.0500), lessThan(at(-22.9056, -47.0608)));
    expect(at(-22.9056, -47.0608), lessThan(at(-22.8880, -47.0780)));
    // Um vetor exato, para pegar qualquer mudança na conta.
    expect((at(-22.8745, -47.0500) * 1000).round(), 655200);
    final (x, y) = latLonToTileFraction(-22.0, -47.0, 21);
    expect(r.heightAt(x, y), isNull, reason: 'fora da região: terreno plano');
  });
}
