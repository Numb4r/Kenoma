import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Manda o arquivo do registro para fora do app. A tela conversa só com esta interface.
abstract class LogExporter {
  Future<void> export(File file);
}

/// Abre a folha de compartilhamento do sistema.
class ShareLogExporter implements LogExporter {
  @override
  Future<void> export(File file) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Kenoma: sessões de sintonia',
    ));
  }
}
