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

  /// Cópia do arquivo no formato anterior, feita antes de migrá-lo. Nunca é sobrescrita.
  File get backup => File('${file.path}.bak');

  /// Fila das operações no arquivo: uma termina antes de a próxima começar. Sem isso, duas
  /// gravações sobrepostas decidem ao mesmo tempo se o arquivo é novo e uma perde a linha da outra.
  Future<void> _queue = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() job) {
    final done = _queue.then((_) => job());
    _queue = done.then<void>((_) {}, onError: (Object _) {}); // a falha de uma não trava as seguintes
    return done;
  }

  /// Acrescenta uma linha. Antes, sobe o arquivo para o formato atual se ele ainda estiver no anterior.
  Future<void> append(SessionRecord record) => _enqueue(() async {
        await _migrate();
        await _write(record);
      });

  /// Sobe para o formato atual um registro no formato anterior (sem `balance_version`): cada linha
  /// que já existia ganha a versão `pre-ajuste`. Não faz nada se o arquivo não existe, está vazio, já
  /// está no formato atual ou tem um cabeçalho que não é o anterior (nesse caso não mexe nele).
  Future<void> migrate() => _enqueue(_migrate);

  Future<void> _migrate() async {
    if (!file.existsSync() || file.lengthSync() == 0) return;
    final lines = await file.readAsLines();
    if (lines.isEmpty || lines.first != SessionRecord.legacyHeader) return;

    // O arquivo é o registro de jogo do usuário: guarda uma cópia antes e troca o arquivo de uma vez.
    if (!backup.existsSync()) await file.copy(backup.path);
    final migrated = [
      SessionRecord.header,
      for (final line in lines.skip(1))
        if (line.isNotEmpty) '$line,${SessionRecord.legacyBalanceVersion}',
    ];
    final temp = File('${file.path}.tmp');
    await temp.writeAsString('${migrated.join('\n')}\n', flush: true);
    await temp.rename(file.path);
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
