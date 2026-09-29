/// Tipos dos Ecos. Fogo vence Planta, Planta vence Água, Água vence Fogo.
enum EcoType {
  fire,
  water,
  plant;

  static EcoType parse(String id) =>
      values.firstWhere((t) => t.name == id, orElse: () => throw ArgumentError('Tipo desconhecido: $id'));
}
