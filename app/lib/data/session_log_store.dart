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

  /// Cópia do arquivo no primeiro formato (14 colunas), feita antes de migrá-lo. Nunca é sobrescrita.
  File get backup => File('${file.path}.bak');

  /// Cópia do arquivo no segundo formato (15 colunas), feita antes de migrá-lo. Nunca é sobrescrita.
  File get backupV2 => File('${file.path}.v2.bak');

  /// Cópia do arquivo no terceiro formato (17 colunas), feita antes de migrá-lo. Nunca é sobrescrita.
  File get backupV3 => File('${file.path}.v3.bak');

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

  /// Sobe para o formato atual um registro num formato anterior, sem perder linha:
  /// - 14 colunas (sem `balance_version`): cada linha ganha `pre-ajuste`, e depois o que vem abaixo;
  /// - 15 colunas (sem `gap` e `overlevel`): cada linha ganha o `gap` calculado dos próprios níveis
  ///   (`eco_level − player_level`) e `overlevel` 0, porque o sobrenível ainda não existia;
  /// - 17 colunas (sem `app_build`): cada linha ganha `pre-visual`.
  ///
  /// Um formato antigo passa por todos os degraus de uma vez, com uma cópia só (a do formato de origem).
  ///
  /// Não faz nada se o arquivo não existe, está vazio, já está no formato atual ou tem um cabeçalho
  /// que não é de um formato conhecido (nesse caso não mexe nele).
  Future<void> migrate() => _enqueue(_migrate);

  Future<void> _migrate() async {
    if (!file.existsSync() || file.lengthSync() == 0) return;
    final lines = await file.readAsLines();
    if (lines.isEmpty) return;
    final File copy;
    final int from;
    if (lines.first == SessionRecord.legacyHeader) {
      copy = backup;
      from = SessionRecord.columnsV1;
    } else if (lines.first == SessionRecord.previousHeader) {
      copy = backupV2;
      from = SessionRecord.columnsV2;
    } else if (lines.first == SessionRecord.headerV3) {
      copy = backupV3;
      from = SessionRecord.columnsV3;
    } else {
      return;
    }

    // O arquivo é o registro de jogo do usuário: guarda uma cópia antes e troca o arquivo de uma vez.
    if (!copy.existsSync()) await file.copy(copy.path);
    final migrated = [
      SessionRecord.header,
      for (final line in lines.skip(1))
        if (line.isNotEmpty) _upgradeRow(line, from),
    ];
    final temp = File('${file.path}.tmp');
    await temp.writeAsString('${migrated.join('\n')}\n', flush: true);
    await temp.rename(file.path);
  }

  /// Sobe uma linha do formato com [from] colunas até o atual.
  String _upgradeRow(String row, int from) {
    var r = row;
    if (from < SessionRecord.columnsV2) r = '$r,${SessionRecord.legacyBalanceVersion}';
    if (from < SessionRecord.columnsV3) r = _addGap(r);
    return '$r,${SessionRecord.legacyAppBuild}';
  }

  /// Acrescenta `gap` dos níveis da própria linha (vazio se ilegíveis) e `overlevel` 0.
  String _addGap(String row) {
    final fields = row.split(',');
    final eco = fields.length > 3 ? int.tryParse(fields[2]) : null;
    final player = fields.length > 3 ? int.tryParse(fields[3]) : null;
    final gap = eco == null || player == null ? '' : '${eco - player}';
    return '$row,$gap,${SessionRecord.legacyOverlevel}';
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
