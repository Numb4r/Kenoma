/// A fusão da Entidade Maior (GDD, "Etapas altas antes dos grimórios e das Incursões", 0.27.0): enquanto não existe item de
/// grimório, 3 Espíritos da família mais a criatura de ritual dela como oferenda, e a Essência do tipo, viram a Entidade
/// Maior da família. As quatro criaturas são consumidas. Como na fusão de Ecos para Espírito: o nível é a média dos
/// Espíritos (a oferenda não conta), limitado ao teto da Entidade; os traços vêm de todas as peças, o Brilhante primeiro e
/// depois cada variante distinta, até o teto de traços da Entidade. Dart puro.
library;

import '../data/game_data.dart';
import '../player/game_state.dart';
import 'fusion.dart' show essenceOfFamily, spiritIdOf;

String majorIdOf(String family) => '$family.major';
String ritualIdOf(String family) => '$family.ritual';

/// Por que a fusão da Entidade não pode acontecer agora. `needsCircleConfirm` não é erro: pede a confirmação do jogador.
enum MajorBlocker { locked, unknownFamily, wrongCount, invalidPiece, missingEssence, needsCircleConfirm }

/// O que a fusão da Entidade vai fazer, calculado sem gastar nada.
class MajorPlan {
  const MajorPlan({required this.family, required this.majorId, required this.essenceId, required this.essenceCost, required this.spirits, required this.offering, required this.level, required this.traits, required this.circleUids});

  final String family;
  final String majorId;
  final String essenceId;
  final int essenceCost;
  final List<CreatureInstance> spirits;

  /// A criatura de ritual da família, consumida como oferenda. `null` enquanto não foi escolhida.
  final CreatureInstance? offering;
  final int level;
  final List<String> traits;
  final List<String> circleUids;

  List<CreatureInstance> get pieces => [...spirits, ?offering];
}

/// Um espaço da receita na tela: a espécie que vai ali e se o jogador já a descobriu (viu no Bestiário). O que não foi
/// descoberto aparece como ???, como no ritual.
typedef MajorSlot = ({String speciesId, int count, bool known});

/// A receita da Entidade da [family]: os Espíritos, a oferenda e a própria Entidade (o resultado), cada um revelado
/// quando a espécie já foi vista.
List<MajorSlot> majorRecipe(GameState s, String family) {
  bool seen(String id) => s.bestiary[id]?.seen ?? false;
  return [
    (speciesId: spiritIdOf(family), count: s.cb.majorSpiritCount, known: seen(spiritIdOf(family))),
    (speciesId: ritualIdOf(family), count: 1, known: seen(ritualIdOf(family))),
    (speciesId: majorIdOf(family), count: 1, known: seen(majorIdOf(family))),
  ];
}

/// Os Espíritos e as criaturas de ritual da coleção que podem entrar na fusão da [family].
List<CreatureInstance> majorSpirits(GameState s, String family) => [for (final c in s.collection) if (c.speciesId == spiritIdOf(family)) c];
List<CreatureInstance> majorOfferings(GameState s, String family) => [for (final c in s.collection) if (c.speciesId == ritualIdOf(family)) c];

/// Os traços da Entidade: o Brilhante primeiro (de qualquer peça), depois cada variante ou traço distinto, na ordem das
/// peças, até [max].
List<String> majorTraits(List<CreatureInstance> pieces, int max) {
  final out = <String>[if (pieces.any((c) => c.shiny || c.traits.contains('shiny'))) 'shiny'];
  for (final c in pieces) {
    for (final t in [?c.variant, ...c.traits]) {
      if (t != 'shiny' && !out.contains(t)) out.add(t);
    }
  }
  return out.take(max).toList();
}

/// O plano com os Espíritos [spiritUids] e a oferenda [offeringUid] (pode faltar). `null` se uma peça não serve: repetida,
/// de outra família ou de outra camada, ou fora da coleção.
MajorPlan? majorPlan(GameState s, GameData data, String family, List<String> spiritUids, String? offeringUid) {
  final essence = essenceOfFamily(data, family);
  if (essence == null || data.species(majorIdOf(family)) == null) return null;
  if (spiritUids.toSet().length != spiritUids.length || spiritUids.contains(offeringUid)) return null;
  final spirits = <CreatureInstance>[];
  for (final u in spiritUids) {
    final c = s.creature(u);
    if (c == null || c.speciesId != spiritIdOf(family)) return null;
    spirits.add(c);
  }
  final offering = offeringUid == null ? null : s.creature(offeringUid);
  if (offeringUid != null && offering?.speciesId != ritualIdOf(family)) return null;
  final cb = s.cb;
  final avg = spirits.isEmpty ? 0 : (spirits.fold<int>(0, (sum, c) => sum + c.level) / spirits.length).round();
  final pieces = [...spirits, ?offering];
  return MajorPlan(
    family: family,
    majorId: majorIdOf(family),
    essenceId: essence,
    essenceCost: cb.majorEssenceCost,
    spirits: spirits,
    offering: offering,
    level: avg.clamp(1, cb.majorLevelCap),
    traits: majorTraits(pieces, cb.majorTraitsMax),
    circleUids: [for (final c in pieces) if (s.inCircle(c.uid)) c.uid],
  );
}

/// O que impede a fusão da Entidade, ou `null` se pode.
MajorBlocker? majorBlocker(GameState s, GameData data, String family, List<String> spiritUids, String? offeringUid, {bool confirmCircle = false}) {
  if (s.playerLevel < s.cb.majorFusionLevel) return MajorBlocker.locked;
  if (essenceOfFamily(data, family) == null || data.species(majorIdOf(family)) == null) return MajorBlocker.unknownFamily;
  if (spiritUids.length != s.cb.majorSpiritCount || offeringUid == null) return MajorBlocker.wrongCount;
  final plan = majorPlan(s, data, family, spiritUids, offeringUid);
  if (plan == null) return MajorBlocker.invalidPiece;
  if (s.count(plan.essenceId) < plan.essenceCost) return MajorBlocker.missingEssence;
  if (plan.circleUids.isNotEmpty && !confirmCircle) return MajorBlocker.needsCircleConfirm;
  return null;
}

/// Executa de uma vez: ou tudo acontece ou nada é gasto. Os três Espíritos e a oferenda saem da coleção (e do Círculo), a
/// Essência é gasta, o evento `fusion_major` conta, a Entidade entra na coleção e no Bestiário como capturada.
CreatureInstance? fuseMajor(GameState s, GameData data, String family, List<String> spiritUids, String offeringUid, {required int nowUtc, bool confirmCircle = false}) {
  if (majorBlocker(s, data, family, spiritUids, offeringUid, confirmCircle: confirmCircle) != null) return null;
  final plan = majorPlan(s, data, family, spiritUids, offeringUid)!;
  for (var i = 0; i < plan.essenceCost; i++) {
    s.take(plan.essenceId);
  }
  for (final c in plan.pieces) {
    s.circle.remove(c.uid);
    s.removeCreature(c.uid);
  }
  final debug = plan.pieces.any((c) => c.debug);
  final major = CreatureInstance(
      uid: 'major-$nowUtc-${s.conjurer.fusions}${debug ? '-debug-${plan.pieces.first.uid}' : ''}', speciesId: plan.majorId, level: plan.level, capturedUtc: nowUtc, traits: plan.traits, debug: debug);
  if (!debug) s.conjurer.fusions++;
  s.addCreature(major);
  if (!debug) {
    s.recordEvent('fusion_major', family, 1);
    s.recordEvent('major_seen_$family', '', 1);
  }
  return major;
}
