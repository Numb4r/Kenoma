/// Seed do grupo (docs/fase0-spec.md, seção 3).
library;

import 'dart:convert';

import 'fnv.dart';

/// Tira espaços e hífens e passa para maiúsculas.
String normalizeSeedCode(String code) => code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// `seed_global` = FNV-1a 64 sobre os bytes UTF-8 do código normalizado.
int seedGlobal(String code) => fnv1a64Bytes(utf8.encode(normalizeSeedCode(code)));
