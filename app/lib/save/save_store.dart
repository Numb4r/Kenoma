/// Onde o save mora. O de verdade é o [KsvSaveStore] (KSV1, escrita atômica, rodízio de 3 cópias).
library;

import 'dart:convert';

abstract class SaveStore {
  /// O save salvo, ou `null` se não há (ou se está ilegível).
  Future<Map<String, dynamic>?> read();

  /// O que aconteceu na última leitura que o jogador precisa saber (cópia corrompida, save antigo migrado), ou
  /// `null`. Só o [KsvSaveStore] tem o que dizer.
  String? get loadNote;

  Future<void> write(Map<String, dynamic> json);
}

/// Sem disco: para testes e para quando o app não acha a pasta de documentos.
class MemorySaveStore implements SaveStore {
  Map<String, dynamic>? json;

  @override
  String? get loadNote => null;

  @override
  Future<Map<String, dynamic>?> read() async => json;

  @override
  Future<void> write(Map<String, dynamic> json) async => this.json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}
