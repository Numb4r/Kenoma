/// Regras de `biomes.json` e a consulta da Overpass do bloco. Dart puro, sem depender do Flutter.
library;

import 'dart:math' as math;

import 'block.dart';

/// Uma regra casada: o bioma, se vale para `area` ou `line`, e o buffer da linha em metros.
class OsmMatch {
  const OsmMatch(this.biomeId, {required this.isArea, required this.bufferM});

  final int biomeId;
  final bool isArea;
  final double bufferM;
}

/// Classe da rua (`HIGHWAY_CLASS` de `pipeline/build_visual.py`): o índice é `RoadClass`.
const Map<String, int> highwayClasses = {
  'motorway': 0, 'motorway_link': 0, 'trunk': 0, 'trunk_link': 0, 'primary': 0, 'primary_link': 0,
  'secondary': 1, 'secondary_link': 1, 'tertiary': 1, 'tertiary_link': 1,
  'residential': 2, 'unclassified': 2, 'living_street': 2, 'service': 2, 'road': 2,
  'footway': 3, 'pedestrian': 3, 'path': 3, 'steps': 3, 'cycleway': 3, 'track': 3, 'bridleway': 3,
};

class OsmRules {
  OsmRules._(this._byTag, this.keys, this.biomesByPriority, this.maxBufferM);

  factory OsmRules.fromJson(Map<String, dynamic> biomesJson) {
    final byTag = <String, Map<String, List<OsmMatch>>>{};
    final biomes = (biomesJson['biomes'] as List).cast<Map<String, dynamic>>();
    var maxBuffer = 0.0;
    for (final biome in biomes) {
      for (final rule in (biome['osm'] as List).cast<Map<String, dynamic>>()) {
        final buffer = ((rule['buffer_m'] ?? 0) as num).toDouble();
        maxBuffer = math.max(maxBuffer, buffer);
        final values = byTag.putIfAbsent(rule['tag'] as String, () => {});
        for (final value in (rule['values'] as List).cast<String>()) {
          values.putIfAbsent(value, () => []).add(OsmMatch(biome['id'] as int, isArea: rule['geometry'] == 'area', bufferM: buffer));
        }
      }
    }
    // Ordem estável, como `sorted` no Python.
    final ordered = [...biomes]..sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
    return OsmRules._(byTag, byTag.keys.toList()..sort(), [for (final b in ordered) b['id'] as int], maxBuffer);
  }

  final Map<String, Map<String, List<OsmMatch>>> _byTag;

  /// As tags das regras, em ordem alfabética: a ordem de `load_rules`.
  final List<String> keys;

  /// Biomas da menor para a maior prioridade: o posterior pinta por cima.
  final List<int> biomesByPriority;
  final double maxBufferM;

  /// Regras casadas por um objeto com [tags], na ordem do pipeline.
  List<OsmMatch> matches(Map<String, dynamic> tags, {required bool isArea}) => [
        for (final key in keys)
          ...?_byTag[key]![tags[key]]?.where((m) => m.isArea == isArea),
      ];

  /// (tag, valores) das regras de um tipo de geometria, em ordem estável.
  Map<String, List<String>> _valuesOf({required bool isArea}) {
    final out = <String, List<String>>{};
    for (final key in keys) {
      final values = [
        for (final e in _byTag[key]!.entries)
          if (e.value.any((m) => m.isArea == isArea)) e.key
      ]..sort();
      if (values.isNotEmpty) out[key] = values;
    }
    return out;
  }
}

/// Margem da caixa da consulta além do maior buffer.
const double _marginM = 30;

double _tileLon(int x) => x / (1 << blockZoom) * 360 - 180;

double _tileLat(int y) => math.atan(_sinh(math.pi * (1 - 2 * y / (1 << blockZoom)))) * 180 / math.pi;

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

/// A caixa da consulta do tile: (oeste, sul, leste, norte), com 7 casas como as coordenadas do OSM.
(String, String, String, String) _box(int tx, int ty, OsmRules rules) {
  final w = _tileLon(tx), e = _tileLon(tx + 1), n = _tileLat(ty), s = _tileLat(ty + 1);
  final d = rules.maxBufferM + _marginM;
  final dLat = d / 110540.0;
  final dLon = d / (111320.0 * math.cos(math.max(s.abs(), n.abs()) * math.pi / 180));
  String f(double v) => v.toStringAsFixed(7);
  return (f(w - dLon), f(s - dLat), f(e + dLon), f(n + dLat));
}

String _regex(List<String> values) => '^(${values.join('|')})\$';

/// A consulta do bloco, com a data da época fixa: dois aparelhos em dias diferentes recebem o mesmo dado.
String overpassQuery({required int tx, required int ty, required String dateIso, required OsmRules rules}) {
  final (w, s, e, n) = _box(tx, ty, rules);
  final box = '($s,$w,$n,$e)';
  final area = rules._valuesOf(isArea: true), line = rules._valuesOf(isArea: false);
  final ways = <String, Set<String>>{'highway': highwayClasses.keys.toSet()};
  for (final table in [line, area]) {
    table.forEach((tag, values) => (ways[tag] ??= {}).addAll(values));
  }
  final out = StringBuffer('[out:json][timeout:60][date:"$dateIso"];\n(\n');
  ways.forEach((tag, values) => out.writeln('  way["$tag"~"${_regex(values.toList()..sort())}"]$box;'));
  area.forEach((tag, values) => out.writeln('  rel["$tag"~"${_regex(values)}"]["type"~"^(multipolygon|boundary)\$"]$box;'));
  out.write(');\nout tags geom;\n');
  return out.toString();
}
