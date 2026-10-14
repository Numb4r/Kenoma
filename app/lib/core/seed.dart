/// Seed do grupo (docs/fase0-spec.md, seção 3).
library;

import 'dart:convert';

import 'fnv.dart';

/// Tira espaços e hífens e passa para maiúsculas.
String normalizeSeedCode(String code) => code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// `seed_global` = FNV-1a 64 sobre os bytes UTF-8 do código normalizado.
int seedGlobal(String code) => fnv1a64Bytes(utf8.encode(normalizeSeedCode(code)));

/// Alfabeto base32 de Crockford: sem I, L, O nem U.
const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Código novo do grupo, `XXXXX-XXXXX`, na primeira abertura. [nextInt] devolve um inteiro em
/// `[0, n)`; quem chama passa um `Random.secure` (não é lógica de mundo, então `dart:math` serve).
String generateGroupCode(int Function(int n) nextInt) {
  final chars = [for (var i = 0; i < 10; i++) _crockford[nextInt(_crockford.length)]];
  return '${chars.sublist(0, 5).join()}-${chars.sublist(5).join()}';
}
