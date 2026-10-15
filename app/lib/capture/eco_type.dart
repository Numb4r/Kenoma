/// Tipos dos Ecos. Fogo vence Planta, Planta vence Água, Água vence Fogo.
enum EcoType {
  fire,
  water,
  plant;

  /// Fogo vence Planta, Planta vence Água, Água vence Fogo.
  bool beats(EcoType other) => switch (this) {
        EcoType.fire => other == EcoType.plant,
        EcoType.plant => other == EcoType.water,
        EcoType.water => other == EcoType.fire,
      };

  static EcoType parse(String id) =>
      values.firstWhere((t) => t.name == id, orElse: () => throw ArgumentError('Tipo desconhecido: $id'));
}
