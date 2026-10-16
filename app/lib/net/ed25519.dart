/// Verificação de assinatura Ed25519 (RFC 8032, seção 5.1.7) em Dart puro com BigInt. Só verifica: o app nunca assina.
/// Não é tempo constante, o que não importa aqui (só entram dados públicos).
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;

final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
final BigInt _l = (BigInt.one << 252) + BigInt.parse('27742317777372353535851937790883648493');
final BigInt _d = (BigInt.from(-121665) * BigInt.from(121666).modInverse(_p)) % _p;
final BigInt _d2 = (_d * BigInt.two) % _p;
final BigInt _sqrtM1 = BigInt.two.modPow((_p - BigInt.one) ~/ BigInt.from(4), _p);

typedef _Pt = (BigInt, BigInt, BigInt, BigInt); // X, Y, Z, T (coordenadas estendidas)

final _Pt _zero = (BigInt.zero, BigInt.one, BigInt.one, BigInt.zero);
final _Pt _base = _fromXY(
  BigInt.parse('15112221349535400772501151409588531511454012693041857206046113283949847762202'),
  BigInt.parse('46316835694926478169428394003475163141307993866256225615783033603165251855960'),
);

_Pt _fromXY(BigInt x, BigInt y) => (x, y, BigInt.one, (x * y) % _p);

_Pt _add(_Pt a, _Pt b) {
  final aa = ((a.$2 - a.$1) * (b.$2 - b.$1)) % _p;
  final bb = ((a.$2 + a.$1) * (b.$2 + b.$1)) % _p;
  final cc = (a.$4 * _d2 * b.$4) % _p;
  final dd = (a.$3 * BigInt.two * b.$3) % _p;
  final e = bb - aa, f = dd - cc, g = dd + cc, h = bb + aa;
  return ((e * f) % _p, (g * h) % _p, (f * g) % _p, (e * h) % _p);
}

_Pt _mul(BigInt k, _Pt pt) {
  var r = _zero, q = pt;
  while (k > BigInt.zero) {
    if (k.isOdd) r = _add(r, q);
    q = _add(q, q);
    k >>= 1; // BigInt não tem o problema de sinal dos u64 do mundo
  }
  return r;
}

bool _equal(_Pt a, _Pt b) =>
    (a.$1 * b.$3 - b.$1 * a.$3) % _p == BigInt.zero && (a.$2 * b.$3 - b.$2 * a.$3) % _p == BigInt.zero;

BigInt _leInt(List<int> b) {
  var n = BigInt.zero;
  for (var i = b.length - 1; i >= 0; i--) {
    n = (n << 8) | BigInt.from(b[i]);
  }
  return n;
}

_Pt? _decode(List<int> s) {
  if (s.length != 32) return null;
  final raw = _leInt(s);
  final sign = (raw >> 255).toInt();
  final y = raw & ((BigInt.one << 255) - BigInt.one);
  if (y >= _p) return null;
  final y2 = (y * y) % _p;
  final u = (y2 - BigInt.one) % _p, v = (_d * y2 + BigInt.one) % _p;
  final x2 = (u * v.modInverse(_p)) % _p;
  var x = x2.modPow((_p + BigInt.from(3)) ~/ BigInt.from(8), _p);
  if ((x * x - x2) % _p != BigInt.zero) x = (x * _sqrtM1) % _p;
  if ((x * x - x2) % _p != BigInt.zero) return null;
  if (x == BigInt.zero && sign == 1) return null;
  if (x.isOdd != (sign == 1)) x = _p - x;
  return _fromXY(x, y);
}

/// `true` se [signature] (64 bytes) é uma assinatura Ed25519 válida de [message] pela chave pública [publicKey] (32 bytes).
bool ed25519Verify({required List<int> publicKey, required List<int> message, required List<int> signature}) {
  try {
    if (signature.length != 64 || publicKey.length != 32) return false;
    final a = _decode(publicKey);
    final r = _decode(signature.sublist(0, 32));
    final s = _leInt(signature.sublist(32));
    if (a == null || r == null || s >= _l) return false;
    final h = _leInt(sha512.convert([...signature.sublist(0, 32), ...publicKey, ...message]).bytes) % _l;
    return _equal(_mul(s, _base), _add(r, _mul(h, a)));
  } catch (_) {
    return false;
  }
}

/// Hex (sem espaços) para bytes. `null` se não for hex de tamanho par.
Uint8List? hexToBytes(String hex) {
  final h = hex.trim();
  if (h.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(h)) return null;
  return Uint8List.fromList([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);
}
