/// O que o clima põe por cima das ruas (docs/clima-auditoria.md): água nas ruas baixas no Dilúvio, neve acumulando, dunas,
/// gelo e fuligem. Só desenho e o Tráfego do Véu (que também é só desenho), então os números moram no `clima.json`. Mesmo
/// assim, quais ruas sai do hash da seed e da rua (tile z15 e índice da linha no pacote visual): amigos juntos veem as mesmas
/// ruas alagadas. Dart puro.
///
/// Ruas baixas: não há relevo no projeto. Uma rua é baixa se o hash dela cai abaixo da fração da classe (`share`); o
/// caminho de pedestre fica com 0 (as calçadas altas). Fixas pela seed: as mesmas ruas alagam em todo Dilúvio.
library;

import '../core/fnv.dart';
import '../data/climate_catalog.dart';
import '../data/visual_pack.dart';
import 'climate_form.dart';

final int _saltLow = salt('LOWST');
final int _saltDune = salt('DUNE');

enum StreetCoverKind { flood, snow, sand, ice, soot }

/// Para o Tráfego do Véu: a rua alagada vira rio (carro vira barco, passante não entra) e a rua com duna fecha.
enum StreetState { normal, flooded, blocked }

class StreetCover {
  const StreetCover({required this.kind, this.share = const {}, this.growS = 0, this.tracks = false, this.skid = false});

  factory StreetCover.fromLayer(ClimateLayer l) => StreetCover(
        kind: StreetCoverKind.values.byName(l.str('cover') ?? 'flood'),
        share: {for (final e in ((l.raw['share'] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as num).toDouble()},
        growS: l.val('grow_s'),
        tracks: l.flag('tracks'),
        skid: l.flag('skid'),
      );

  final StreetCoverKind kind;

  /// Fração das ruas de cada classe que a cobertura pega (alagamento, dunas, fuligem). Sem a classe: nenhuma.
  final Map<String, double> share;

  /// Segundos até a cobertura ficar inteira, desde o começo do clima (a neve: até as avenidas).
  final double growS;

  /// Neve: o tráfego abre duas trilhas nas avenidas. Gelo: os carros derrapam.
  final bool tracks;
  final bool skid;

  static double _u(List<int> fields) => (fnv1a64(fields) >>> 32) / 4294967296.0;

  /// Quanto da cobertura se formou [sinceS] segundos depois do começo do clima (0 a 1; ver `climate_form.dart`).
  double amountAt(double sinceS) => formAmount(sinceStartS: sinceS, growS: growS, fadeS: 0);

  /// Quanto a rua [key] (tile z15 e índice da linha) da classe [cls] está coberta, de 0 a 1, com [amount] da cobertura
  /// formada ([amountAt]), na janela de 3 h [window] (as dunas mudam a cada janela).
  double level(int seed, (int, int, int) key, RoadClass cls, int window, double amount) {
    final (tx, ty, i) = key;
    switch (kind) {
      case StreetCoverKind.flood:
        return _u([seed, tx, ty, i, _saltLow]) < (share[cls.name] ?? 0) ? amount : 0;
      case StreetCoverKind.sand:
        return _u([seed, tx, ty, i, window, _saltDune]) < (share[cls.name] ?? 0) ? amount : 0;
      case StreetCoverKind.soot:
        return (share[cls.name] ?? 0) > 0 ? amount : 0;
      case StreetCoverKind.ice:
        return amount;
      case StreetCoverKind.snow:
        // A neve fica primeiro no chão e nos telhados; nas ruas, primeiro onde ninguém passa e por último nas avenidas.
        return snowStages(amount).street(roadRank(cls));
    }
  }

  /// 0: caminho de pedestre, 1: local, 2: secundária, 3: principal (a ordem em que a neve chega).
  static int roadRank(RoadClass cls) => switch (cls) { RoadClass.pedestrian => 0, RoadClass.local => 1, RoadClass.secondary => 2, RoadClass.principal => 3 };

  /// O trecho da rua que a duna cobre, em fração do comprimento: até um terço dela, em lugar sorteado, crescendo do meio
  /// com [level].
  (double, double) duneSpan(int seed, (int, int, int) key, int window, [double level = 1]) {
    final (tx, ty, i) = key;
    final a = _u([seed, tx, ty, i, window, _saltDune, 1]) * 0.65, half = 0.175 * level.clamp(0.0, 1.0);
    return (a + 0.175 - half, a + 0.175 + half);
  }

  /// O estado da rua para o tráfego, [sinceS] segundos depois do começo do clima. Gelo e fuligem não mudam a rota.
  StreetState stateOf(int seed, (int, int, int) key, RoadClass cls, int window, double sinceS) {
    if (kind == StreetCoverKind.snow) {
      // Neve funda: no fim da nevasca, uma parte das ruas (`share`, pela seed e pela rua) fecha para os carros.
      final (tx, ty, i) = key;
      return amountAt(sinceS) >= 0.9 && _u([seed, tx, ty, i, _saltLow]) < (share[cls.name] ?? 0) ? StreetState.blocked : StreetState.normal;
    }
    if (kind != StreetCoverKind.flood && kind != StreetCoverKind.sand) return StreetState.normal;
    final l = level(seed, key, cls, window, amountAt(sinceS));
    if (l <= 0) return StreetState.normal;
    if (kind == StreetCoverKind.sand) return l >= 0.3 ? StreetState.blocked : StreetState.normal; // a duna fecha quando já subiu
    return l >= 0.5 ? StreetState.flooded : StreetState.normal; // a água sobe antes de os carros virarem barcos
  }
}

/// A cobertura das ruas do clima [info] (a primeira camada `streets` do chão), ou `null`.
StreetCover? streetCoverOf(ClimateInfo info) {
  for (final l in info.ground) {
    if (l.kind == 'streets') return StreetCover.fromLayer(l);
  }
  return null;
}
