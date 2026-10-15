/// O arquivo de save e de backup (docs/fase0-spec.md, seção 10): o magic `KSV1` (4 bytes), o SHA-256 do payload
/// (32 bytes) e o payload, que é o JSON em UTF-8 comprimido com gzip. Dart puro.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

const List<int> ksvMagic = [0x4b, 0x53, 0x56, 0x31]; // "KSV1"
const int ksvHeaderLength = 4 + 32;

/// O arquivo não é um save válido: magic errado, truncado, checksum que não bate ou JSON ilegível.
class SaveCorrupt implements Exception {
  const SaveCorrupt(this.reason);

  final String reason;

  @override
  String toString() => 'SaveCorrupt: $reason';
}

Uint8List encodeKsv(Map<String, dynamic> json) {
  final payload = gzip.encode(utf8.encode(jsonEncode(json)));
  final out = BytesBuilder(copy: false)
    ..add(ksvMagic)
    ..add(sha256.convert(payload).bytes)
    ..add(payload);
  return out.toBytes();
}

/// Lê um arquivo KSV1. Lança [SaveCorrupt] se qualquer coisa estiver errada.
Map<String, dynamic> decodeKsv(List<int> bytes) {
  if (bytes.length <= ksvHeaderLength) throw const SaveCorrupt('arquivo curto demais');
  for (var i = 0; i < ksvMagic.length; i++) {
    if (bytes[i] != ksvMagic[i]) throw const SaveCorrupt('não é um arquivo KSV1');
  }
  final payload = bytes.sublist(ksvHeaderLength);
  final expected = bytes.sublist(4, ksvHeaderLength);
  final actual = sha256.convert(payload).bytes;
  for (var i = 0; i < 32; i++) {
    if (expected[i] != actual[i]) throw const SaveCorrupt('checksum não bate');
  }
  try {
    final json = jsonDecode(utf8.decode(gzip.decode(payload)));
    if (json is! Map<String, dynamic>) throw const SaveCorrupt('o JSON não é um objeto');
    return json;
  } on FormatException catch (e) {
    throw SaveCorrupt('JSON ilegível: ${e.message}');
  } on Exception catch (e) {
    if (e is SaveCorrupt) rethrow;
    throw SaveCorrupt('payload ilegível: $e');
  }
}
