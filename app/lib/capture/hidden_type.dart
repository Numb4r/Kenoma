import '../core/pcg32.dart';
import 'eco_type.dart';

/// Tipo sorteado do modo de tipo oculto, com a mesma chance para cada um.
EcoType pickHiddenType(Pcg32 rng) => EcoType.values[rng.nextInt(EcoType.values.length)];

/// Escolhe, entre [pool], o item do tipo sorteado. Sorteia o tipo uma vez só: cada item de [pool]
/// tem um tipo diferente, e todos os tipos precisam estar presentes.
T pickHidden<T>(List<T> pool, EcoType Function(T item) typeOf, Pcg32 rng) {
  final type = pickHiddenType(rng);
  return pool.firstWhere((item) => typeOf(item) == type);
}
