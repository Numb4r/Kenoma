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

  /// Fila das gravações: uma termina antes de a próxima começar. Sem isso, duas gravações
  /// sobrepostas decidem ao mesmo tempo se o arquivo é novo e uma perde a linha da outra.
  Future<void> _queue = Future<void>.value();

  Future<void> append(SessionRecord record) {
    final done = _queue.then((_) => _write(record));
    _queue = done.catchError((Object _) {}); // a falha de uma gravação não trava as seguintes
    return done;
  }

  Future<void> _write(SessionRecord record) async {
    final line = record.toCsvLine();
    await file.parent.create(recursive: true);
    final fresh = !file.existsSync() || file.lengthSync() == 0;
    await file.writeAsString(
      '${fresh ? '${SessionRecord.header}\n' : ''}$line\n',
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
