/// 0.26.3: os SHA-256 de pacotes de região que já bateram nesta instalação. A conta (uns 130 ms a cada abertura no g54, só
/// com Campinas) só é refeita depois de instalar ou atualizar o app (o [ShaMemo.stamp] muda) ou, nos arquivos baixados,
/// quando o arquivo muda de tamanho ou data. Fica num JSON pequeno nos dados do app; sem ele (testes, outro isolate), tudo é
/// conferido sempre, como antes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class ShaMemo {
  ShaMemo(this.stamp, [Iterable<String> ok = const []]) : _ok = {...ok};

  /// O da instalação aberta agora (`ShaMemo.open`); `null` sem disco.
  static ShaMemo? current;

  /// A instalação: muda a cada instalação ou atualização do APK.
  final String stamp;
  final Set<String> _ok;
  bool _changed = false;
  File? _file;

  /// A chave de um conteúdo conferido: o nome, o tamanho, a data (arquivos baixados) e o SHA que a época espera.
  static String keyOf(String name, int length, String expected, [String fileStamp = '']) => '$name|$length|$fileStamp|${expected.toLowerCase()}';

  bool has(String key) => _ok.contains(key);

  void add(String key) {
    if (_ok.add(key)) _changed = true;
  }

  /// A chave do arquivo [path] no disco agora (tamanho e data), ou `null` se ele não existe.
  static String? fileKey(String path, String expected) {
    try {
      final st = File(path).statSync();
      if (st.type != FileSystemEntityType.file) return null;
      return keyOf(path, st.size, expected, '${st.modified.millisecondsSinceEpoch}');
    } on FileSystemException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {'stamp': stamp, 'ok': _ok.toList()..sort()};

  /// O guardado em [json], se é da mesma instalação; senão, vazio (depois de instalar ou atualizar, tudo se confere de novo).
  factory ShaMemo.fromJson(Map<String, dynamic>? json, String stamp) =>
      json != null && json['stamp'] == stamp ? ShaMemo(stamp, (json['ok'] as List<dynamic>).cast<String>()) : ShaMemo(stamp);

  /// Abre o guardado em [file] para a instalação [stamp] e o deixa em [current].
  static Future<ShaMemo> open(File file, String stamp) async {
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      json = null; // primeira abertura, ou arquivo estragado: confere tudo
    }
    return current = ShaMemo.fromJson(json, stamp).._file = file;
  }

  /// Grava, se algo novo bateu.
  Future<void> save() async {
    final f = _file;
    if (f == null || !_changed) return;
    _changed = false;
    try {
      await f.writeAsString(jsonEncode(toJson()));
    } catch (_) {
      // sem disco: na próxima abertura confere de novo
    }
  }
}

/// [bytes] tem o SHA-256 [expected]? Com o [ShaMemo.current], a conta é feita uma vez por instalação para cada conteúdo
/// ([name] e o tamanho); as aberturas seguintes confiam no resultado guardado.
bool shaMatches(List<int> bytes, String expected, {required String name}) {
  final memo = ShaMemo.current, key = ShaMemo.keyOf(name, bytes.length, expected);
  if (memo != null && memo.has(key)) return true;
  final ok = sha256.convert(bytes).toString() == expected.toLowerCase();
  if (ok) memo?.add(key);
  return ok;
}
