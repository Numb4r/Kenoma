/// Como o backup sai do aparelho e volta: a folha de compartilhamento do sistema (que leva ao Google Drive) e o
/// seletor de arquivos. A tela conversa só com esta interface, então os testes não precisam do sistema.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract class BackupIo {
  /// Manda [bytes] para fora, num arquivo chamado [name].
  Future<void> share(Uint8List bytes, String name);

  /// Deixa o jogador escolher um arquivo. `null` se cancelou.
  Future<Uint8List?> pick();
}

class DeviceBackupIo implements BackupIo {
  const DeviceBackupIo();

  @override
  Future<void> share(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/octet-stream')], subject: 'Kenoma: backup'));
  }

  @override
  Future<Uint8List?> pick() async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Escolha o arquivo de backup do Kenoma');
    return picked?.xFile.readAsBytes();
  }
}
