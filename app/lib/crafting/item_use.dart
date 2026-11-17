/// O efeito da qualidade nos itens de uso (docs/GDD.md, "Regras da fase 1"): selo bom e perfeito dão mais tolerância na
/// sintonia, e o que tem duração (o tônico) dura mais. Nenhuma receita exige qualidade: é recompensa. A sintonia usa a
/// melhor pilha que o jogador tem. Dart puro.
library;

import '../capture/seal.dart' show Tonic;
import '../player/game_state.dart';
import 'crafting_data.dart';
import 'loadout.dart';
import 'quality.dart';

/// O multiplicador de tolerância de um selo na qualidade [q], com o bônus do equipamento (`seal_tolerance`).
double sealToleranceMult(GameState s, CraftingBook book, Quality q, int utc) =>
    book.balance.sealTolerance[q.index] * (1 + loadoutEffects(s, book, utc)['seal_tolerance']!);

/// Os segundos a mais que o tônico [t] na qualidade [q] dá, com o bônus do equipamento (`tonic_time`).
double tonicSeconds(GameState s, CraftingBook book, Tonic t, Quality q, int utc) =>
    t.extraTimeS * book.balance.duration[q.index] * (1 + loadoutEffects(s, book, utc)['tonic_time']!);

/// O melhor tônico que o jogador tem (o que dá mais tempo, já com a qualidade), ou `null`.
({Tonic tonic, Quality q, double seconds})? bestTonic(GameState s, CraftingBook book, List<Tonic> tonics, int utc) {
  ({Tonic tonic, Quality q, double seconds})? best;
  for (final t in tonics) {
    final q = s.bestQuality(t.id);
    if (q == null) continue;
    final sec = tonicSeconds(s, book, t, q, utc);
    if (best == null || sec > best.seconds) best = (tonic: t, q: q, seconds: sec);
  }
  return best;
}
