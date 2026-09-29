/// Sobrenível: criaturas muito acima do nível do Conjurador (docs/fase0-spec.md, seção 5).
///
/// A diferença de nível (`gap` = nível do Eco − nível do Conjurador) tem dois eixos. Até
/// `overlevel_free` níveis ela só soma à intensidade da resistência (ver `resistanceIntensity`).
/// Passando disso, `g = gap − overlevel_free` aplica o sobrenível, sem depender do teto de 1,0 da
/// intensidade: tolerância menor, progresso que cai mais rápido e mais chance de fuga na falha.
library;

import 'dart:math' as math;

import 'tuning_balance.dart';

/// Diferença de nível: Eco menos Conjurador. Negativa se o Eco está abaixo.
int levelGap({required int playerLevel, required int ecoLevel}) => ecoLevel - playerLevel;

/// Sobrenível `g`: níveis acima de `overlevel_free`. 0 se o Eco não passa disso.
int overlevelOf({required int playerLevel, required int ecoLevel, required TuningBalance balance}) =>
    math.max(0, levelGap(playerLevel: playerLevel, ecoLevel: ecoLevel) - balance.overlevelFree);

/// Multiplicador da tolerância: `overlevel_tol_factor^g`, com piso `overlevel_tol_floor`. Vale por
/// cima do fator da Planta, que já tem o piso dele.
double overlevelToleranceFactor(int g, TuningBalance b) =>
    g <= 0 ? 1.0 : math.max(b.overlevelTolFloor, math.pow(b.overlevelTolFactor, g).toDouble());

/// Multiplicador da velocidade com que o progresso cai: `1 + overlevel_down_per_level × g`.
double overlevelProgressDownFactor(int g, TuningBalance b) => 1 + b.overlevelDownPerLevel * math.max(0, g);

/// Chance de a criatura fugir depois de uma falha: a base mais `overlevel_flee_per_level × g`, com
/// teto em `overlevel_flee_max`.
double fleeChanceOnFail(int g, TuningBalance b) =>
    math.min(b.overlevelFleeMax, b.fleeChanceOnFail + b.overlevelFleePerLevel * math.max(0, g));
