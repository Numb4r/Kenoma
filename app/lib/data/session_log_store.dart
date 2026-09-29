/// Arquivo CSV com uma linha por sintonia. O cabeçalho entra na primeira gravação.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../capture/session_record.dart';

class SessionLogStore {
  SessionLogStore(this.file);

  /// No diretório de documentos do app: `sessions.csv`.
  static Future<SessionLogStore> inDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    return SessionLogStore(File('${dir.path}/sessions.csv'));
  }

  final File file;

  Future<void> append(SessionRecord record) async {
    final fresh = !file.existsSync() || file.lengthSync() == 0;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${fresh ? '${SessionRecord.header}\n' : ''}${record.toCsvLine()}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Sessões gravadas, sem contar o cabeçalho.
  Future<int> count() async {
    if (!file.existsSync()) return 0;
    final lines = (await file.readAsLines()).where((l) => l.isNotEmpty).length;
    return lines == 0 ? 0 : lines - 1;
  }
}
