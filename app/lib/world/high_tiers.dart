/// As etapas altas no mundo (0.27.0; GDD, "Etapas altas antes dos grimórios e das Incursões"). Dart puro e determinístico:
/// tudo sai de `hash(seed, época, ...)`, igual para todos os amigos do grupo.
///
/// - **Entidade Maior solta:** por região, família e mês, o sorteio escolhe uma célula e procura, a partir de uma hora
///   sorteada, a primeira em que a condição do ritual da família vale ali ([MajorSighting]). Ela fica uma janela curta e o
///   rumor sai no fórum horas antes, com o bairro e a faixa de hora.
/// - **Arquétipo:** numa ocorrência do evento grande da família, cada célula z17 tem uma chance de ter o Arquétipo no auge
///   (o terço do meio do evento). Ele se mostra uma vez, por alguns segundos, para quem estiver ali ([ArchetypeSighting]).
library;

import 'dart:math' as math;

import '../core/fnv.dart';
import '../core/high_tiers_model.dart';
import '../core/climate.dart' show climateOfStack;
import 'climate_world.dart' show ClimateWorld;
import 'spawn_field.dart' show WorldSpawn;

/// A condição do ritual da [family] vale na célula z20 em [tUtc]?
typedef FamilyConditionAt = bool Function(String family, int cx20, int cy20, int tUtc);

/// Uma área em células z20 (o retângulo de uma região).
typedef CellArea = ({int x0, int y0, int w, int h});

int _str(String s) => fnv1a64([for (final c in s.codeUnits) c]);
double _unit(int h) => (h >>> 11) / (1 << 53);

const int _saltMajor = 0x524f4a414d; // MAJOR
const int _saltArche = 0x4548435241; // ARCHE

/// O começo (UTC) do mês de [tUtc] e do seguinte.
(int, int) monthBounds(int tUtc) {
  final d = DateTime.fromMillisecondsSinceEpoch(tUtc * 1000, isUtc: true);
  return (DateTime.utc(d.year, d.month).millisecondsSinceEpoch ~/ 1000, DateTime.utc(d.year, d.month + 1).millisecondsSinceEpoch ~/ 1000);
}

class MajorSighting {
  const MajorSighting({required this.family, required this.region, required this.cx20, required this.cy20, required this.x21, required this.y21, required this.startUtc, required this.endUtc, required this.rumorUtc, required this.uid});

  final String family;
  final String region;
  final int cx20, cy20;

  /// A posição no mapa, em células z21 fracionárias.
  final double x21, y21;
  final int startUtc, endUtc;

  /// Quando o rumor aparece no fórum.
  final int rumorUtc;
  final int uid;

  String get speciesId => '$family.major';
  bool activeAt(int t) => t >= startUtc && t < endUtc;
  bool rumorAt(int t) => t >= rumorUtc && t < endUtc;

  WorldSpawn spawn(int level) => WorldSpawn(uid: uid, kind: 'eco', entryId: speciesId, quantity: 1, x: x21, y: y21, cellX: cx20, cellY: cy20, window: startUtc, level: level);
}

/// As Entidades soltas da [region] no mês de [tUtc], em ordem de começo. Para cada família, até [HighTiersModel.majorTries]
/// pontos: cada um sorteia uma célula da [area] e uma hora de partida, e anda o mês em passos de
/// [HighTiersModel.majorScanStepS] (no máximo [HighTiersModel.majorScanMaxSteps] passos) até a condição do ritual valer
/// ali ([holds]); a primeira que cabe no mês vale. Até
/// [HighTiersModel.majorPerMonth] por família.
List<MajorSighting> majorSightings({
  required int seed,
  required int epochId,
  required HighTiersModel m,
  required String region,
  required CellArea area,
  required List<String> families,
  required int tUtc,
  required FamilyConditionAt holds,
}) =>
    [for (final s in majorSightingSteps(seed: seed, epochId: epochId, m: m, region: region, area: area, families: families, tUtc: tUtc, holds: holds)) ?s]
      ..sort((a, b) => a.startUtc - b.startUtc);

/// O mesmo sorteio de [majorSightings], aos poucos: um `null` a cada hora de busca e no fim de cada ponto que não achou
/// nada. O mapa anda uma fatia por quadro, para a busca do mês não segurar a tela.
Iterable<MajorSighting?> majorSightingSteps({
  required int seed,
  required int epochId,
  required HighTiersModel m,
  required String region,
  required CellArea area,
  required List<String> families,
  required int tUtc,
  required FamilyConditionAt holds,
}) sync* {
  final (from, to) = monthBounds(tUtc);
  final steps = (to - from) ~/ m.majorScanStepS;
  for (final family in families) {
    var found = 0;
    for (var i = 0; i < m.majorTries && found < m.majorPerMonth; i++) {
      final h = fnv1a64([seed, epochId, _str(region), _str(family), from, i, _saltMajor]);
      final cx = area.x0 + hashMod(h, area.w), cy = area.y0 + hashMod(fnv1a64([h, 1]), area.h);
      final start0 = hashMod(fnv1a64([h, 2]), steps);
      MajorSighting? hit;
      for (var k = 0; k < math.min(steps, m.majorScanMaxSteps); k++) {
        if (k > 0) yield null; // um ponto por vez: quem corre aos poucos decide quando parar (o mapa, pelo tempo)
        final t = from + ((start0 + k) % steps) * m.majorScanStepS;
        if (t + m.majorWindowS > to || !holds(family, cx, cy, t)) continue;
        final p = fnv1a64([h, 3]);
        hit = MajorSighting(
          family: family,
          region: region,
          cx20: cx,
          cy20: cy,
          x21: cx * 2 + 0.5 + _unit(p),
          y21: cy * 2 + 0.5 + _unit(fnv1a64([p, 1])),
          startUtc: t,
          endUtc: t + m.majorWindowS,
          rumorUtc: t - m.majorRumorLeadS,
          uid: fnv1a64([h, t, 4]) | 1, // nunca 0
        );
        break;
      }
      if (hit != null) found++;
      yield hit;
    }
  }
}

/// O bairro mais perto de ([lat], [lon]) na lista da região (`mapa.json`, `bairros`), ou `null` sem lista.
String? nearestBairro(List<(String, double, double)> bairros, double lat, double lon) {
  String? best;
  var bd = double.infinity;
  for (final (name, la, lo) in bairros) {
    final d = math.pow(la - lat, 2) + math.pow((lo - lon) * math.cos(lat * math.pi / 180), 2);
    if (d < bd) (best, bd) = (name, d.toDouble());
  }
  return best;
}

/// "entre 19h e 20h": a faixa de uma hora local em que a janela começa.
String hourBand(int startUtc, {Duration? offset}) {
  final t = DateTime.fromMillisecondsSinceEpoch(startUtc * 1000, isUtc: true);
  final h = (offset != null ? t.add(offset) : t.toLocal()).hour;
  return 'entre ${h}h e ${(h + 1) % 24}h';
}

class ArchetypeSighting {
  const ArchetypeSighting({required this.family, required this.eventId, required this.cx17, required this.cy17, required this.x21, required this.y21, required this.peakFrom, required this.peakTo, required this.uid});

  final String family;
  final String eventId;
  final int cx17, cy17;
  final double x21, y21;

  /// O auge: o pedaço do meio da ocorrência do evento em que ele pode estar ali.
  final int peakFrom, peakTo;
  final int uid;

  String get speciesId => '$family.archetype';
  bool inPeak(int t) => t >= peakFrom && t < peakTo;

  WorldSpawn spawn() => WorldSpawn(uid: uid, kind: 'eco', entryId: speciesId, quantity: 1, x: x21, y: y21, cellX: cx17 << 3, cellY: cy17 << 3, window: peakFrom, level: 1);
}

/// As ocorrências em que um Arquétipo pode surgir na célula z20 em [t]: os eventos que valem ali e o clima da janela (o
/// Granizo do Clod), que vale do começo ao fim da janela do clima.
List<({String id, int start, int end})> archetypeOccurrencesAt(ClimateWorld c, int cx20, int cy20, int t) {
  final m = c.modelAt(t)?.$2;
  final w = m?.windowOf(t);
  return [
    for (final e in c.eventsBetween(cx20, cy20, t, t + 1)) (id: e.id, start: e.startUtc, end: e.endUtc),
    if (m != null && w != null) (id: climateOfStack(c.idAt(cx20, cy20, t)), start: w * m.windowS, end: (w + 1) * m.windowS),
  ];
}

/// O Arquétipo da célula z17 ([cx17], [cy17]) na ocorrência do evento [eventId] que vai de [eventStart] a [eventEnd], ou
/// `null`: nenhuma família tem esse evento, ou o sorteio da célula não deu.
ArchetypeSighting? archetypeIn({
  required int seed,
  required int epochId,
  required HighTiersModel m,
  required String eventId,
  required int eventStart,
  required int eventEnd,
  required int cx17,
  required int cy17,
}) {
  final families = [for (final e in m.archetypeEvents.entries) if (e.value == eventId) e.key]..sort();
  if (families.isEmpty || eventEnd <= eventStart) return null;
  final h = fnv1a64([seed, epochId, _str(eventId), eventStart, cx17, cy17, _saltArche]);
  if (_unit(h) >= m.archetypeChance) return null;
  final family = families[hashMod(fnv1a64([h, 1]), families.length)];
  final mid = (eventStart + eventEnd) ~/ 2, half = ((eventEnd - eventStart) * m.archetypePeakShare / 2).round();
  final p = fnv1a64([h, 2]);
  return ArchetypeSighting(
    family: family,
    eventId: eventId,
    cx17: cx17,
    cy17: cy17,
    x21: cx17 * 16 + 2 + 12 * _unit(p),
    y21: cy17 * 16 + 2 + 12 * _unit(fnv1a64([p, 1])),
    peakFrom: mid - half,
    peakTo: mid + half,
    uid: fnv1a64([h, 3]) | 1,
  );
}
