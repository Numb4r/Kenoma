/// Regras de `biomes.json` e a consulta da Overpass do bloco. Dart puro, sem depender do Flutter.
library;

import 'dart:math' as math;

import '../../data/map_sources.dart' show kAccessBike, kAccessBridge, kAccessFoot, kAccessMotor;
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

/// `(bbox)` só acha borda: um bloco inteiro dentro de uma mata ou represa não veria o polígono. A borda de quem engole o
/// bloco cruza qualquer semirreta que sai dele, então a consulta pede também as áreas numa faixa fina para o norte.
/// ponytail: área com borda além da faixa fica invisível; em São Paulo o pior caso medido é 0,055 grau para o norte.
const double _rayDeg = 0.25;
const double _rayHalfWidthDeg = 0.00002;

/// Prédio não cobre 1 km, e a faixa atravessaria milhares deles na cidade.
const Set<String> _rayExcludedTags = {'building'};

double _tileLon(int x) => x / (1 << blockZoom) * 360 - 180;

double _tileLat(int y) => math.atan(_sinh(math.pi * (1 - 2 * y / (1 << blockZoom)))) * 180 / math.pi;

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

String _bbox(double w, double s, double e, double n) {
  String f(double v) => v.toStringAsFixed(7);
  return '(${f(s)},${f(w)},${f(n)},${f(e)})';
}

/// As caixas da consulta do tile, no formato da Overpass, com 7 casas como as coordenadas do OSM: o bloco e a faixa.
(String, String) _boxes(int tx, int ty, OsmRules rules) {
  final w = _tileLon(tx), e = _tileLon(tx + 1), n = _tileLat(ty), s = _tileLat(ty + 1);
  final d = rules.maxBufferM + _marginM;
  final dLat = d / 110540.0;
  final dLon = d / (111320.0 * math.cos(math.max(s.abs(), n.abs()) * math.pi / 180));
  final cx = (w + e) / 2;
  return (
    _bbox(w - dLon, s - dLat, e + dLon, n + dLat),
    _bbox(cx - _rayHalfWidthDeg, n + dLat, cx + _rayHalfWidthDeg, n + dLat + _rayDeg),
  );
}

String _regex(List<String> values) => '^(${values.join('|')})\$';

/// A consulta do bloco, com a data da época fixa: dois aparelhos em dias diferentes recebem o mesmo dado.
String overpassQuery({required int tx, required int ty, required String dateIso, required OsmRules rules}) {
  final (box, ray) = _boxes(tx, ty, rules);
  final area = rules._valuesOf(isArea: true), line = rules._valuesOf(isArea: false);
  final ways = <String, Set<String>>{'highway': highwayClasses.keys.toSet()};
  for (final table in [line, area]) {
    table.forEach((tag, values) => (ways[tag] ??= {}).addAll(values));
  }
  final out = StringBuffer('[out:json][timeout:120][date:"$dateIso"];\n(\n');
  ways.forEach((tag, values) => out.writeln('  way["$tag"~"${_regex(values.toList()..sort())}"]$box;'));
  area.forEach((tag, values) {
    if (!_rayExcludedTags.contains(tag)) out.writeln('  way["$tag"~"${_regex(values)}"]$ray;');
  });
  // `out tags` não traz os membros da relation; sem eles não há geometria. Na way, `tags` evita a lista de nós.
  out.write(');\nout tags geom;\n(\n');
  area.forEach((tag, values) {
    final rel = '  rel["$tag"~"${_regex(values)}"]["type"~"^(multipolygon|boundary)\$"]';
    out.writeln('$rel$box;');
    if (!_rayExcludedTags.contains(tag)) out.writeln('$rel$ray;');
  });
  out.write(');\nout body geom;\n');
  return out.toString();
}

const Set<String> _closedValues = {'no', 'private'};
const Set<String> _bikeOk = {'yes', 'designated', 'permissive'};

/// A chave mais específica que existe decide.
bool _modeClosed(Map<String, dynamic> tags, List<String> keys) {
  for (final k in keys) {
    final v = tags[k];
    if (v != null) return _closedValues.contains(v);
  }
  return false;
}

/// Os bits de rota de uma via (`kAccess*`), as regras de `access_mask` em `pipeline/build_noaccess.py`.
int accessMask(Map<String, dynamic> tags) {
  var m = 0;
  if (_modeClosed(tags, const ['foot', 'access'])) m |= kAccessFoot;
  if (_modeClosed(tags, const ['bicycle', 'vehicle', 'access']) ||
      (const {'steps', 'footway', 'pedestrian'}.contains(tags['highway']) && !_bikeOk.contains(tags['bicycle']))) {
    m |= kAccessBike;
  }
  if (_modeClosed(tags, const ['motor_vehicle', 'vehicle', 'access'])) m |= kAccessMotor;
  final bridge = tags['bridge'];
  if (bridge != null && bridge != 'no') m |= kAccessBridge;
  return m;
}
