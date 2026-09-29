import '../capture/eco_type.dart';

/// Nome do tipo na interface.
String typeLabel(EcoType t) => switch (t) {
      EcoType.fire => 'Fogo',
      EcoType.water => 'Água',
      EcoType.plant => 'Planta',
    };
