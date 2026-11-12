import '../capture/eco_type.dart';

/// Nome do tipo na interface.
String typeLabel(EcoType t) => switch (t) {
      EcoType.fire => 'Fogo',
      EcoType.water => 'Água',
      EcoType.plant => 'Planta',
      EcoType.earth => 'Terra',
      EcoType.electric => 'Elétrico',
      EcoType.metal => 'Metal',
      EcoType.light => 'Luz',
      EcoType.shadow => 'Sombra',
      EcoType.spectral => 'Espectral',
      EcoType.digital => 'Digital',
      EcoType.fae => 'Feérico',
      EcoType.draconic => 'Dracônico',
    };
