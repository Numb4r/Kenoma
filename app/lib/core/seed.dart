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
/// `[0, n)`; quem chama passa um `Pcg32`, porque o código é sorteado uma vez e depois só é lido.
String generateGroupCode(int Function(int n) nextInt) {
  final chars = [for (var i = 0; i < 10; i++) _crockford[nextInt(_crockford.length)]];
  return '${chars.sublist(0, 5).join()}-${chars.sublist(5).join()}';
}

/// Um código de grupo digitado ou lido de um QR: letras e números, de 6 a 20 caracteres depois de normalizar.
bool isValidGroupCode(String code) => RegExp(r'^[0-9A-Z]{6,20}$').hasMatch(normalizeSeedCode(code));

/// O código como se mostra: `XXXXX-XXXXX` quando tem 10 caracteres, senão normalizado. A seed é a mesma dos dois jeitos.
String formatGroupCode(String code) {
  final n = normalizeSeedCode(code);
  return n.length == 10 ? '${n.substring(0, 5)}-${n.substring(5)}' : n;
}

const String _qrPrefix = 'kenoma:group:';

/// O texto que o QR do grupo carrega.
String groupQrPayload(String code) => '$_qrPrefix${normalizeSeedCode(code)}';

/// O código de grupo de um texto lido de QR (com ou sem o prefixo do Kenoma), ou `null` se não serve.
String? parseGroupQr(String text) {
  final t = text.trim();
  final raw = t.toLowerCase().startsWith(_qrPrefix) ? t.substring(_qrPrefix.length) : t;
  return isValidGroupCode(raw) ? formatGroupCode(raw) : null;
}
