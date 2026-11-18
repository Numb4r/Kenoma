/// Quantidade com substantivo (0.25.0): a única função do jogo que monta "1 dia", "2 dias", "3 Folhas secas". Depois de três
/// versões com "1 dias" e "3 Folha seca", todo texto que junta número e palavra passa por aqui, e um teste percorre os
/// textos de dados com 0, 1 e 2. Dart puro.
library;

/// Palavras que ligam o núcleo ao complemento ("Pó **de** Essência"): só o que vem antes delas vai para o plural.
const _links = {'de', 'do', 'da', 'dos', 'das', 'com', 'em', 'no', 'na', 'sem', 'para'};

/// O plural de uma palavra pelas regras regulares do português. Palavra que já termina em `s` (Ervas, simples) fica igual.
String pluralWord(String w) {
  if (w.isEmpty) return w;
  final lower = w.toLowerCase();
  String keep(String suffix, int drop) => w.substring(0, w.length - drop) + (w == w.toUpperCase() && w.length > 1 ? suffix.toUpperCase() : suffix);
  if (lower.endsWith('s') || lower.endsWith('x')) return w;
  if (lower.endsWith('ão')) return keep('ões', 2);
  if (lower.endsWith('al')) return keep('ais', 2);
  if (lower.endsWith('el')) return keep('éis', 2);
  if (lower.endsWith('ol')) return keep('óis', 2);
  if (lower.endsWith('ul')) return keep('uis', 2);
  if (lower.endsWith('il')) return keep('is', 1);
  if (lower.endsWith('m')) return keep('ns', 1);
  if (lower.endsWith('r') || lower.endsWith('z')) return keep('es', 0);
  return keep('s', 0);
}

/// O plural de um nome: o núcleo e os adjetivos dele vão para o plural, o complemento não ("Caco de vidro" → "Cacos de
/// vidro", "Folha seca" → "Folhas secas", "Pó de Essência de Fogo" → "Pós de Essência de Fogo").
String pluralPt(String phrase) {
  final words = phrase.split(' ');
  final out = <String>[];
  var inHead = true;
  for (final w in words) {
    if (_links.contains(w.toLowerCase())) inHead = false;
    out.add(inHead ? pluralWord(w) : w);
  }
  return out.join(' ');
}

/// "1 dia", "2 dias", "0 dias": singular só com 1. [plural]: a forma irregular, quando a regra não serve.
String countText(int n, String singular, {String? plural}) => '$n ${n == 1 || n == -1 ? singular : plural ?? pluralPt(singular)}';

final _gap = RegExp(r'\{(\w+)(?:([:?])([^}|]+)(?:\|([^}]+))?)?\}');

/// Preenche as lacunas de [text] com [values]. `{chave}` vira o valor; `{chave:singular}` ou `{chave:singular|plural}`, com
/// um número em [values], vira a quantidade com o substantivo concordando ("{dias:dia}" → "1 dia", "3 dias");
/// `{chave?singular|plural}` vira só a palavra que concorda ("{dias?Falta|Faltam}"). Lacuna sem valor fica como está.
String fillText(String text, Map<String, Object> values) => text.replaceAllMapped(_gap, (m) {
      final v = values[m.group(1)];
      if (v == null) return m.group(0)!;
      final sing = m.group(3);
      if (sing == null) return '$v';
      final n = v is num ? v.round() : int.tryParse('$v');
      // `{chave?Falta|Faltam}`: só a palavra que concorda com o número, sem ele.
      if (m.group(2) == '?') return n == 1 || n == -1 ? sing : (m.group(4) ?? pluralPt(sing));
      return n == null ? '$v $sing' : countText(n, sing, plural: m.group(4));
    });
