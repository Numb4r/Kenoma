/// A qualidade dos materiais e itens (docs/GDD.md, "Regras da fase 1"): comum, bom e perfeito, guardada por pilha. A pilha
/// comum usa o id puro (`item.chalk`), as outras levam o sufixo (`item.chalk@good`), então um save antigo já é todo comum.
/// Dart puro.
library;

enum Quality {
  common('comum'),
  good('boa'),
  perfect('perfeita');

  const Quality(this.label);

  /// O rótulo depois de "qualidade" ("qualidade boa"): concorda sempre, qualquer que seja o item.
  final String label;

  /// Quantos pontos a célula da bolsa desenha (1 a 3): a contagem diferencia, não só a cor.
  int get dots => index + 1;

  /// "qualidade boa".
  String get phrase => 'qualidade $label';

  Quality up([int n = 1]) => Quality.values[(index + n).clamp(0, Quality.values.length - 1)];

  static Quality worst(Iterable<Quality> qs) => qs.fold(Quality.perfect, (a, b) => b.index < a.index ? b : a);

  static Quality byName(String? s) => Quality.values.firstWhere((q) => q.name == s, orElse: () => Quality.common);
}

/// A chave da pilha de [id] na qualidade [q].
String stackKey(String id, Quality q) => q == Quality.common ? id : '$id@${q.name}';

/// O id e a qualidade de uma chave de pilha.
({String id, Quality q}) parseStack(String key) {
  final at = key.indexOf('@');
  return at < 0 ? (id: key, q: Quality.common) : (id: key.substring(0, at), q: Quality.byName(key.substring(at + 1)));
}

/// As chaves das pilhas de [id], da pior para a melhor.
List<String> stackKeys(String id) => [for (final q in Quality.values) stackKey(id, q)];
