/// Onde o save mínimo mora: um JSON local. A escrita é atômica (grava num temporário e renomeia). O
/// formato completo, com checksum, rodízio e migrações, é o M10.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class SaveStore {
  /// O save salvo, ou `null` se não há (ou se está ilegível).
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> json);
}

class FileSaveStore implements SaveStore {
  FileSaveStore(this.file);

  static Future<FileSaveStore> inDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    return FileSaveStore(File('${dir.path}/save.json'));
  }

  final File file;

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      await file.rename('${file.path}.bad'); // não apaga: o jogo recomeça, mas o arquivo fica para olhar
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> json) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(file.path);
  }
}

/// Sem disco: para testes e para quando o app não acha a pasta de documentos.
class MemorySaveStore implements SaveStore {
  Map<String, dynamic>? json;

  @override
  Future<Map<String, dynamic>?> read() async => json;

  @override
  Future<void> write(Map<String, dynamic> json) async => this.json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}
