/// Números da "Rua viva" (Fase 1, fatia 2) lidos de `balance.json`: o que cada comportamento faz, o Radar e o
/// Familiar. É o que não muda o mundo; o que muda (pesos, chances, clima) fica na época. Nenhum número vive no código.
library;

class StreetLifeBalance {
  StreetLifeBalance(Map<String, dynamic> balance)
      : this._(
          balance['behavior'] as Map<String, dynamic>,
          balance['radar'] as Map<String, dynamic>,
          balance['familiar'] as Map<String, dynamic>,
          balance['weather'] as Map<String, dynamic>,
        );

  StreetLifeBalance._(Map<String, dynamic> b, Map<String, dynamic> r, Map<String, dynamic> fam, Map<String, dynamic> w)
      : skittishFleeSpeedMps = _d((b['skittish'] as Map<String, dynamic>)['flee_speed_mps']),
        skittishSpeedWindowS = _d((b['skittish'] as Map<String, dynamic>)['speed_window_s']),
        skittishWanderScale = _d((b['skittish'] as Map<String, dynamic>)['wander_scale']),
        aggressiveIntensityAdd = _d((b['aggressive'] as Map<String, dynamic>)['intensity_add']),
        hiddenWanderScale = _d((b['hidden'] as Map<String, dynamic>)['wander_scale']),
        radarCooldownS = _d(r['cooldown_s']),
        radarRadiusM = _d(r['radius_m']),
        traceRangeM = _d(r['trace_range_m']),
        traceErrorDeg = _d(r['trace_error_deg']),
        traceHideWithinM = _d(r['trace_hide_within_m']),
        radarLevel2PlayerLevel = (r['level2_player_level'] as num).toInt(),
        hiddenRevealS = _d(r['hidden_reveal_s']),
        arcNearDeg = _d(r['arc_near_deg']),
        arcFarDeg = _d(r['arc_far_deg']),
        hiddenResolveM = _d(r['hidden_resolve_m']),
        pulseSpeedMps = _d(r['pulse_speed_mps']),
        traceShowS = (r['trace_show_s'] as num).toInt(),
        edgeMarksS = (r['edge_marks_s'] as num?)?.toDouble() ?? 120,
        familiarPickupBonusM = _d(fam['pickup_bonus_m']),
        familiarFollowOffsetM = _d(fam['follow_offset_m']),
        rainParticles = (w['rain_particles'] as num).toInt();

  static double _d(Object? v) => (v as num).toDouble();

  /// Arisco: foge se o jogador entra na Aura acima desta velocidade (m/s), medida na média dos últimos
  /// [skittishSpeedWindowS] segundos. A deriva do sinal dele é [skittishWanderScale] vezes a normal.
  final double skittishFleeSpeedMps;
  final double skittishSpeedWindowS;
  final double skittishWanderScale;

  /// Agressivo: a resistência sobe este tanto de intensidade (um degrau).
  final double aggressiveIntensityAdd;

  /// Oculto: sinal mais estável.
  final double hiddenWanderScale;

  /// Radar: recarga, raio da varredura, até onde os raros deixam rastro, erro máximo do rastro, a que distância o
  /// rastro some (o Eco já está à vista), o nível do Conjurador que libera o nível 2 do scanner e por quanto tempo um
  /// Oculto revelado continua à vista.
  final double radarCooldownS;
  final double radarRadiusM;
  final double traceRangeM;
  final double traceErrorDeg;
  final double traceHideWithinM;
  final int radarLevel2PlayerLevel;
  final double hiddenRevealS;

  /// Sonar: a largura do arco do rastro perto (no [traceHideWithinM]) e longe (no [traceRangeM]), em graus; a que distância
  /// (m) o jogador precisa chegar da distorção para o Oculto virar Eco; a velocidade da onda do pulso (m/s); e por quanto
  /// tempo (s) os rastros ficam no chão.
  final double arcNearDeg;
  final double arcFarDeg;
  final double hiddenResolveM;
  final double pulseSpeedMps;
  final int traceShowS;

  /// Depois de um pulso, por quanto tempo (s) as marcas finas na borda da tela apontam o que ele achou.
  final double edgeMarksS;

  /// Familiar: bônus de coleta (m) e a distância ao lado do Conjurador (m).
  final double familiarPickupBonusM;
  final double familiarFollowOffsetM;

  /// Quantas gotas de chuva no máximo na tela.
  final int rainParticles;
}
