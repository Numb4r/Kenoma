/// O que as telas do crafting (Bolsa, Bancada, Loadout) leem do mapa: a condição de agora e aqui, o relógio do jogo, a
/// velocidade (plantar só a pé) e a condição num ponto qualquer (os plantados). Sem o mapa (testes, celular aberto de
/// fora), vale um céu limpo de dia, sem água nem bioma.
library;

import '../../crafting/conditions.dart';

class CraftContext {
  const CraftContext({
    required this.nowUtc,
    required this.here,
    required this.hereAt,
    this.speedMps,
    this.walkMaxMps = 2.2,
    this.touchM = 30,
    this.climateName,
  });

  /// Sem o mapa: céu limpo de dia em Campinas.
  factory CraftContext.offline(int Function() nowUtc) {
    Here at(double lat, double lon, int t) => Here(utc: t, lat: lat, lon: lon, sunAltDeg: 45, climate: 'clear');
    return CraftContext(nowUtc: nowUtc, here: () => at(-22.9, -47.06, nowUtc()), hereAt: at);
  }

  final int Function() nowUtc;

  /// A condição em volta do jogador agora, com a água procurada.
  final Here Function() here;

  /// A condição num ponto e instante (sem procurar água): a conta dos plantados.
  final Here Function(double lat, double lon, int t) hereAt;

  /// A velocidade do jogador; `null` sem GPS (plantar fica recusado).
  final double Function()? speedMps;
  final double walkMaxMps;

  /// O alcance de toque: colher um plantado.
  final double touchM;

  /// O nome do clima para a faixa "Agora, aqui" (`rain` → "Chuva").
  final String Function(String id)? climateName;
}
