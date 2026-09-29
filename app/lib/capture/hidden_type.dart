import '../core/pcg32.dart';
import 'eco_type.dart';

/// Tipo sorteado do modo de tipo oculto, com a mesma chance para cada um.
EcoType pickHiddenType(Pcg32 rng) => EcoType.values[rng.nextInt(EcoType.values.length)];
