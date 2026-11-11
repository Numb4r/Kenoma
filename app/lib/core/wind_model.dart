/// O vento local canalizado pelas ruas (`epochs.json`, `wind`, da época 10 em diante): **é mundo**, a deriva das Fagulhas
/// usa. Dart puro.
library;

import 'dart:math' as math;

class WindModel {
  const WindModel({this.streetGain = 1.35, this.crossKeep = 0.15, this.shelter = 0.5});

  factory WindModel.fromJson(Map<String, dynamic> j) => WindModel(
        streetGain: (j['street_gain'] as num?)?.toDouble() ?? 1.35,
        crossKeep: (j['cross_keep'] as num?)?.toDouble() ?? 0.15,
        shelter: (j['shelter'] as num?)?.toDouble() ?? 0.5,
      );

  /// Na rua: o que sopra ao longo dela vezes [streetGain], mais [crossKeep] do vento original. Fora das ruas (atrás dos
  /// quarteirões): [shelter] do vento.
  final double streetGain, crossKeep, shelter;

  /// O vento no lugar em relação ao do clima (vetor; 1 = a força do clima), soprando para [headingRad] (a partir do norte,
  /// horário), com a rua do lugar em [street] (`null`: fora das ruas).
  (double, double) factor(double headingRad, (double, double)? street) {
    final bx = math.sin(headingRad), by = -math.cos(headingRad);
    if (street == null) return (bx * shelter, by * shelter);
    final along = bx * street.$1 + by * street.$2;
    return (street.$1 * along * streetGain + bx * crossKeep, street.$2 * along * streetGain + by * crossKeep);
  }
}
