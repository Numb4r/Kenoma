/// O save em disco no formato final: KSV1, escrita atômica e rodízio de 3 cópias (docs/fase0-spec.md, seção 10).
///
/// Arquivos na pasta: `save.ksv` (a mais recente), `save.ksv.1` e `save.ksv.2` (as duas anteriores). Cada
/// gravação escreve um temporário inteiro, confere que ele lê de volta e só então gira as cópias com `rename`,
/// que é atômico: um corte de energia deixa sempre ao menos uma cópia válida. Se a mais recente não passar no
/// checksum, carrega a anterior e deixa um aviso em [loadNote]. O `save.json` do formato antigo é lido uma vez,
/// migrado para KSV1 e guardado como `save.json.migrated`: nada é apagado.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ksv1.dart';
import 'save_store.dart';

class KsvSaveStore implements SaveStore {
  KsvSaveStore(this.dir);

  static Future<KsvSaveStore> inDocuments() async => KsvSaveStore(await getApplicationDocumentsDirectory());

  final Directory dir;
  String? _note;

  File _file(String name) => File('${dir.path}/$name');
  File get current => _file('save.ksv');
  File get previous => _file('save.ksv.1');
  File get oldest => _file('save.ksv.2');
  File get legacy => _file('save.json');

  /// As cópias da mais nova para a mais velha.
  List<File> get copies => [current, previous, oldest];

  @override
  String? get loadNote => _note;

  @override
  Future<Map<String, dynamic>?> read() async {
    _note = null;
    final bad = <String>[];
    for (final f in copies) {
      if (!await f.exists()) continue;
      try {
        final json = decodeKsv(await f.readAsBytes());
        if (bad.isNotEmpty) {
          _note = 'A cópia mais recente do save estava corrompida (${bad.join(', ')}). Carreguei a anterior (${f.uri.pathSegments.last}).';
        }
        return json;
      } on SaveCorrupt {
        bad.add(f.uri.pathSegments.last);
      }
    }
    if (bad.isNotEmpty) {
      _note = 'Todas as cópias do save estão corrompidas (${bad.join(', ')}). O jogo recomeça; os arquivos ficaram na pasta.';
      return null;
    }
    return _readLegacy();
  }

  /// O `save.json` do formato antigo, se existir. A primeira gravação KSV1 o aposenta.
  Future<Map<String, dynamic>?> _readLegacy() async {
    if (!await legacy.exists()) return null;
    try {
      final json = jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
      _note = 'Save antigo migrado para o formato novo.';
      return json;
    } on FormatException {
      await legacy.rename('${legacy.path}.bad'); // não apaga: o jogo recomeça, mas o arquivo fica para olhar
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> json) async {
    final bytes = encodeKsv(json);
    final tmp = _file('save.ksv.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    decodeKsv(await tmp.readAsBytes()); // só gira as cópias se o que foi escrito lê de volta
    // Gira as cópias só com a atual válida: uma corrompida não empurra uma cópia boa para fora.
    if (await current.exists() && await _valid(current)) {
      if (await previous.exists() && await _valid(previous)) await previous.rename(oldest.path);
      await current.rename(previous.path);
    } else if (await current.exists()) {
      await current.rename('${current.path}.bad');
    }
    await tmp.rename(current.path);
    if (await legacy.exists()) await legacy.rename('${legacy.path}.migrated');
  }

  Future<bool> _valid(File f) async {
    try {
      decodeKsv(await f.readAsBytes());
      return true;
    } on SaveCorrupt {
      return false;
    }
  }
}
