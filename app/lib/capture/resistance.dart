/// Intensidade da resistência do Eco (docs/fase0-spec.md, seção 5).
library;

import 'tuning_balance.dart';

/// Intensidade em `[0, resistanceMax]`.
///
/// Pela faixa do nível do Conjurador (0 nos níveis 1 a 3, 0,3 nos 4 a 9, e daí em diante `base` +
/// `per_level` por nível a partir do nível 10, então o nível 10 já vale 0,37), mais 0,045 por nível
/// que o Eco tiver acima do Conjurador.
double resistanceIntensity({required int playerLevel, required int ecoLevel, required TuningBalance balance}) {
  var value = 0.0;
  for (final band in balance.resistanceBands) {
    if (playerLevel < band.from || playerLevel > band.to) continue;
    value = band.value ?? band.base! + band.perLevel! * (playerLevel - band.from + 1);
    break;
  }
  final above = (ecoLevel - playerLevel).clamp(0, 1 << 30);
  return (value + balance.resistancePerEcoLevelAbove * above).clamp(0.0, balance.resistanceMax);
}
