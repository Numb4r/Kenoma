/// Backup: o mesmo arquivo KSV1 do save, exportado pela folha de compartilhamento e importado por um seletor de
/// arquivo (docs/fase0-spec.md, seção 10). Importar mostra o que há no arquivo antes de substituir o jogo. Dart puro.
library;

import 'dart:typed_data';

import 'ksv1.dart';
import 'migrations.dart';
import 'save_store.dart';

/// O que o jogador vê antes de confirmar a importação.
class BackupPreview {
  const BackupPreview({required this.level, required this.creatures, required this.savedUtc, required this.groupCode, required this.appVersion});

  /// Nível real do Conjurador no backup.
  final int level;
  final int creatures;

  /// Quando o backup foi gravado, em segundos UTC.
  final int savedUtc;
  final String groupCode;
  final String appVersion;
}

/// Nome do arquivo de backup: `kenoma-backup-AAAAMMDD-HHMMSS.ksv`, em UTC.
String backupFileName(int utc) {
  final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  return 'kenoma-backup-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}.ksv';
}

/// Os bytes do backup: o save de agora em KSV1.
Uint8List exportBackup(Map<String, dynamic> saveJson) => encodeKsv(saveJson);

/// Lê e confere um arquivo de backup, já migrado para o schema atual. Lança [SaveCorrupt] se o arquivo não
/// é um KSV1 íntegro ou não é um save de Kenoma.
Map<String, dynamic> readBackup(List<int> bytes) {
  final json = migrateSave(decodeKsv(bytes));
  if (json['group_code'] is! String) throw const SaveCorrupt('o arquivo não tem um jogo de Kenoma');
  return json;
}

BackupPreview previewBackup(Map<String, dynamic> json) => BackupPreview(
      level: ((json['player'] as Map<String, dynamic>?)?['level'] as int?) ?? 1,
      creatures: ((json['collection'] as List<dynamic>?) ?? const []).length,
      savedUtc: (json['saved_utc'] as int?) ?? 0,
      groupCode: json['group_code'] as String,
      appVersion: (json['app_version'] as String?) ?? '',
    );

/// Substitui o jogo pelo conteúdo do backup. Quem chama já mostrou o [BackupPreview] e teve a confirmação.
Future<void> restoreBackup(SaveStore store, Map<String, dynamic> backup) => store.write(backup);
