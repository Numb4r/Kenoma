/// A quest que ensina o crafting (0.24.1): a Garrafa de vidro é a porta de entrada dos coletores. Abre na primeira Sucata
/// (ou no presente do mentor); os passos são fazer a garrafa na Bancada, pôr no cinto, encher (na chuva, ou plantada) e
/// fazer uma receita com o que ela pegou. Os passos saem dos eventos do jogo, então valem mesmo feitos antes da quest; o
/// mentor comenta cada um (`craft_tut_*` em `mentor.json`). Dart puro.
library;

import '../player/game_state.dart';
import 'crafting_state.dart';

enum TutStep { bottle, belt, fill, use }

/// O evento que solta a mensagem do mentor depois de cada passo.
const _stepEvents = ['craft_tut_bottle', 'craft_tut_belt', 'craft_tut_fill', 'craft_tut_done'];

bool _anyVesselStack(GameState s) => s.inventory.keys.any((k) => k.startsWith('item.vessel.'));

bool stepDone(GameState s, TutStep st) => switch (st) {
      TutStep.bottle => s.story.count('vessel_made') > 0 || s.crafting.vessels.isNotEmpty || _anyVesselStack(s),
      TutStep.belt => s.story.count('vessel_placed') > 0 || s.crafting.vessels.any((v) => v.place != VesselPlace.bag),
      // Encheu, ou foi plantada (sem chuva, o mentor manda plantar e voltar depois).
      TutStep.fill => s.story.count('vessel_filled') > 0 || s.story.count('vessel_planted') > 0,
      TutStep.use => s.story.count('condition_used') > 0,
    };

/// O passo a fazer agora (o primeiro não feito), ou `null` sem quest ligada.
TutStep? currentStep(GameState s) => s.crafting.tutorial != CraftTutorial.on ? null : TutStep.values.where((st) => !stepDone(s, st)).firstOrNull;

/// Leva o mentor até onde o jogador chegou: cada passo feito, em ordem, solta o evento da mensagem dele, uma vez. Com os
/// quatro feitos, a quest acaba.
void syncTutorial(GameState s) {
  final c = s.crafting;
  if (c.tutorial != CraftTutorial.on) return;
  var done = 0;
  while (done < TutStep.values.length && stepDone(s, TutStep.values[done])) {
    done++;
  }
  var changed = false;
  while (c.tutorialSteps < done) {
    s.story.events[_stepEvents[c.tutorialSteps]] = 1;
    c.tutorialSteps++;
    changed = true;
  }
  if (done == TutStep.values.length) {
    c.tutorial = CraftTutorial.done;
    changed = true;
  }
  if (changed) s.changed();
}

/// O presente do mentor: abrir a aba Condições sem nenhum recipiente (nem vazio, nem no cinto, nem plantado) dá a primeira
/// Garrafa de vidro, uma vez, e liga a quest se ela ainda não começou. `false` se não era o caso ou se a bolsa não comporta.
bool giveFirstBottle(GameState s, int nowUtc) {
  final c = s.crafting;
  if (c.gift || c.vessels.isNotEmpty || _anyVesselStack(s)) return false;
  if (s.add('item.vessel.glass', 1) == 0) return false;
  c.gift = true;
  if (c.tutorial == CraftTutorial.off) c.tutorial = CraftTutorial.on;
  s.deliverMessage('craft_tut_gift', nowUtc);
  return true;
}
