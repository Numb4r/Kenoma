/// FNV-1a 64 (docs/fase0-spec.md, seção 3).
///
/// Todo hash é um u64 guardado num `int` de 64 bits. A multiplicação dá a volta em 2^64 sozinha,
/// então o valor pode aparecer negativo: nunca compare com `<` nem desloque com o operador
/// aritmético. Use sempre o deslocamento lógico e faça módulo sobre os 32 bits de cima.
library;

const int fnvOffset = 0xcbf29ce484222325;
const int fnvPrime = 0x100000001b3;

/// Salts do spec: string ASCII de até 8 caracteres, completada com zeros à direita, lida como u64 little-endian.
const int saltSpwn = 0x4E575053; // SPWN
const int saltOffs = 0x5346464F; // OFFS
const int saltUid = 0x5F444955; // UID_
const int saltKenoma = 0x414D4F4E454B; // KENOMA, sequência do PCG32

/// Calcula o salt de uma string ASCII de até 8 caracteres.
int salt(String name) {
  assert(name.length <= 8, 'salt tem no máximo 8 caracteres');
  var value = 0;
  for (var i = 0; i < name.length; i++) {
    value |= name.codeUnitAt(i) << (8 * i);
  }
  return value;
}

/// FNV-1a 64 sobre bytes crus.
int fnv1a64Bytes(List<int> bytes) {
  var h = fnvOffset;
  for (final b in bytes) {
    h = (h ^ (b & 0xff)) * fnvPrime;
  }
  return h;
}

/// FNV-1a 64 sobre uma lista de campos, cada um serializado como 8 bytes little-endian
/// em complemento de dois, na ordem dada.
int fnv1a64(List<int> fields) {
  var h = fnvOffset;
  for (final field in fields) {
    for (var i = 0; i < 8; i++) {
      h = (h ^ ((field >>> (8 * i)) & 0xff)) * fnvPrime;
    }
  }
  return h;
}

/// Módulo de um hash: sempre sobre os 32 bits de cima, para nunca operar sobre número negativo.
int hashMod(int hash, int n) => (hash >>> 32) % n;

/// Hash como 16 dígitos hexadecimais, tratando o valor como sem sinal.
String hex64(int hash) {
  final high = (hash >>> 32).toRadixString(16).padLeft(8, '0');
  final low = (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '0x$high$low';
}
