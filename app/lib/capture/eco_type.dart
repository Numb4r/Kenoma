/// Os 12 tipos e a tabela de vantagens (docs/GDD.md, "Vantagens e desvantagens"). A tabela define a contenção: no ritual,
/// uma criatura do Círculo forte contra o tipo do alvo conta mais; na sintonia, ter no Círculo um tipo forte contra o alvo
/// amplia a tolerância do dial. A ordem dos três primeiros (Fogo, Água, Planta) é a do MVP e não muda: sorteios antigos
/// dependem dela.
enum EcoType {
  fire,
  water,
  plant,
  earth,
  electric,
  metal,
  light,
  shadow,
  spectral,
  digital,
  fae,
  draconic;

  /// Os tipos do MVP (fase 0), na ordem dos sorteios de antes da 0.20.0.
  static const List<EcoType> mvp = [fire, water, plant];

  /// Contra quem este tipo é forte.
  Set<EcoType> get strongAgainst => switch (this) {
        fire => const {plant, metal},
        water => const {fire, earth, digital},
        plant => const {water, earth},
        earth => const {fire, electric, metal},
        electric => const {water, metal, digital},
        metal => const {fae, light},
        light => const {shadow, spectral},
        shadow => const {light, fae},
        spectral => const {shadow, spectral},
        draconic => const {draconic},
        fae => const {draconic, spectral},
        digital => const {spectral, metal},
      };

  /// Contra quem este tipo é fraco.
  Set<EcoType> get weakAgainst => switch (this) {
        fire => const {water, earth},
        water => const {plant, electric},
        plant => const {fire},
        earth => const {water, plant},
        electric => const {earth},
        metal => const {fire, earth, electric, digital},
        light => const {metal, shadow},
        shadow => const {light, spectral},
        spectral => const {light, spectral, fae, digital},
        draconic => const {draconic, fae},
        fae => const {metal, shadow},
        digital => const {electric, water},
      };

  /// Este tipo é forte contra [other].
  bool beats(EcoType other) => strongAgainst.contains(other);

  /// O fator da contenção no ritual deste tipo contra [other]: 1,5 forte, 0,66 resistido, 1 no resto. Resistem: o próprio
  /// tipo (menos Espectral e Dracônico, que são fortes contra si mesmos) e, no Dracônico, Fogo, Água, Planta e Elétrico.
  double factorAgainst(EcoType other) {
    if (beats(other)) return 1.5;
    if (other == this && this != spectral && this != draconic) return 0.66;
    if (other == draconic && const {fire, water, plant, electric}.contains(this)) return 0.66;
    return 1;
  }

  static EcoType parse(String id) =>
      values.firstWhere((t) => t.name == id, orElse: () => throw ArgumentError('Tipo desconhecido: $id'));
}
