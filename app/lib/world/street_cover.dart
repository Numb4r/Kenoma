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

  /// Segundos até a cobertura ficar inteira, desde o começo do clima.
  final double growS;

  /// Neve: o tráfego abre duas trilhas nas avenidas. Gelo: os carros derrapam.
  final bool tracks;
  final bool skid;

  static double _u(List<int> fields) => (fnv1a64(fields) >>> 32) / 4294967296.0;

  /// Quanto a rua [key] (tile z15 e índice da linha) da classe [cls] está coberta, de 0 a 1, [sinceS] segundos depois do
  /// começo do clima, na janela de 3 h [window] (as dunas mudam a cada janela).
  double level(int seed, (int, int, int) key, RoadClass cls, int window, double sinceS) {
    final grow = growS <= 0 ? 1.0 : (sinceS / growS).clamp(0.0, 1.0);
    final (tx, ty, i) = key;
    switch (kind) {
      case StreetCoverKind.flood:
        return _u([seed, tx, ty, i, _saltLow]) < (share[cls.name] ?? 0) ? grow : 0;
      case StreetCoverKind.sand:
        return _u([seed, tx, ty, i, window, _saltDune]) < (share[cls.name] ?? 0) ? 1 : 0;
      case StreetCoverKind.soot:
        return (share[cls.name] ?? 0) > 0 ? grow : 0;
      case StreetCoverKind.ice:
        return grow;
      case StreetCoverKind.snow:
        // A neve fica primeiro onde ninguém passa: caminhos e ruas locais; as avenidas por último.
        final rate = switch (cls) { RoadClass.pedestrian => 1.4, RoadClass.local => 1.0, RoadClass.secondary => 0.55, RoadClass.principal => 0.3 };
        return growS <= 0 ? 1 : (sinceS / growS * rate).clamp(0.0, 1.0);
    }
  }

  /// O trecho da rua que a duna cobre, em fração do comprimento: um terço dela, em lugar sorteado.
  (double, double) duneSpan(int seed, (int, int, int) key, int window) {
    final (tx, ty, i) = key;
    final a = _u([seed, tx, ty, i, window, _saltDune, 1]) * 0.65;
    return (a, a + 0.35);
  }

  /// O estado da rua para o tráfego. Neve, gelo e fuligem não mudam a rota.
  StreetState stateOf(int seed, (int, int, int) key, RoadClass cls, int window, double sinceS) {
    if (kind != StreetCoverKind.flood && kind != StreetCoverKind.sand) return StreetState.normal;
    final l = level(seed, key, cls, window, sinceS);
    if (l <= 0) return StreetState.normal;
    if (kind == StreetCoverKind.sand) return StreetState.blocked;
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
