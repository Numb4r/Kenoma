import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/plural.dart';

/// 0.25.0: a única função de quantidade com substantivo, e a varredura dos textos de dados com 0, 1 e 2 (três versões
/// seguidas com "1 dias" ou "3 Folha seca").
void main() {
  test('regras do plural e a quantidade', () {
    expect(countText(1, 'dia'), '1 dia');
    expect(countText(0, 'dia'), '0 dias');
    expect(countText(2, 'dia'), '2 dias');
    expect(countText(3, 'Folha seca'), '3 Folhas secas');
    expect(countText(2, 'Caco de vidro'), '2 Cacos de vidro');
    expect(countText(2, 'Pó de Essência de Fogo'), '2 Pós de Essência de Fogo');
    expect(countText(2, 'Água lustral'), '2 Águas lustrais');
    expect(countText(2, 'marcação'), '2 marcações');
    expect(countText(2, 'Giz'), '2 Gizes');
    expect(countText(2, 'item'), '2 itens');
    expect(countText(2, 'selo simples'), '2 selos simples');
    expect(countText(2, 'Cal viva', plural: 'Cales vivas'), '2 Cales vivas');
    expect(fillText('{dias?Falta|Faltam} {dias:dia} para {evento}', {'dias': 1, 'evento': 'X'}), 'Falta 1 dia para X');
    expect(fillText('{dias?Falta|Faltam} {dias:dia} para {evento}', {'dias': 4, 'evento': 'X'}), 'Faltam 4 dias para X');
    expect(fillText('faça {n:selo simples|selos simples}', {'n': 1}), 'faça 1 selo simples');
    expect(fillText('em {min} min', {'min': 1}), 'em 1 min');
  });

  // Todo texto dos dados.
  final texts = <(String, String)>[];
  void walk(Object? o, String file) {
    if (o is String) texts.add((file, o));
    if (o is List) o.forEach((x) => walk(x, file));
    if (o is Map) o.values.forEach((x) => walk(x, file));
  }

  for (final f in Directory('assets/data').listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    walk(jsonDecode(f.readAsStringSync()), f.uri.pathSegments.last);
  }

  // Unidades e ligações que podem vir depois de um número sem concordar.
  const invariant = {'m', 'min', 's', 'km', 'h', 'de', 'do', 'da', 'x', '×', '%'};

  test('nenhum texto de dados junta lacuna de número com substantivo fora da função (`{n} dias`)', () {
    final raw = RegExp(r'\{(n|dias|qtd|vezes)\}\s+([A-Za-zÀ-ú]+)');
    final bad = [
      for (final (f, t) in texts)
        for (final m in raw.allMatches(t))
          if (!invariant.contains(m.group(2)!.toLowerCase())) '$f: ${m.group(0)}',
    ];
    expect(bad, isEmpty, reason: 'use {n:singular} ou {n:singular|plural}');
  });

  test('com 0, 1 e 2, nenhum texto sai com "1 dias", "2 dia" ou substantivo sem plural', () {
    final countGap = RegExp(r'\{(\w+)[:?]([^}|]+)(?:\|([^}]+))?\}');
    final keys = {for (final (_, t) in texts) for (final m in countGap.allMatches(t)) m.group(1)!};
    expect(keys, isNotEmpty);
    for (final (f, t) in texts) {
      if (!countGap.hasMatch(t)) continue;
      for (final n in [0, 1, 2]) {
        final out = fillText(t, {for (final k in keys) k: n, 'evento': 'Lua Carmim', 'familia': 'Sootling', 'tipo': 'Fogo', 'item': 'Giz'});
        expect(out, isNot(contains('{')), reason: '$f: $t');
        expect(RegExp(r'\b1 dias\b|\b[02] dia\b').hasMatch(out), isFalse, reason: '$f: $out');
      }
      for (final m in countGap.allMatches(t)) {
        final sing = m.group(2)!, plural = m.group(3) ?? pluralPt(sing);
        if (!sing.trim().endsWith('s')) expect(plural, isNot(sing), reason: '$f: "$sing" sem plural');
      }
    }
  });

  test('todo item tem plural (pela regra ou pelo campo `plural`)', () {
    final items = (jsonDecode(File('assets/data/items.json').readAsStringSync())['items'] as List).cast<Map<String, dynamic>>();
    for (final i in items) {
      final name = i['name'] as String, plural = (i['plural'] as String?) ?? pluralPt(name);
      if (!name.split(' ').first.endsWith('s')) expect(plural, isNot(name), reason: name);
      expect(countText(1, name, plural: i['plural'] as String?), '1 $name');
    }
  });
}
