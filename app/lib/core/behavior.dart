/// Comportamento de um Eco (docs/GDD.md, "Início do encontro"): como a sintonia começa. Sorteado no fluxo `v2` da
/// célula, igual para todos do grupo.
library;

enum EcoBehavior {
  passive('passive', 'Passivo'),
  skittish('skittish', 'Arisco'),
  aggressive('aggressive', 'Agressivo'),
  hidden('hidden', 'Oculto');

  const EcoBehavior(this.id, this.label);

  /// A chave no JSON e no save.
  final String id;

  /// O nome na interface.
  final String label;

  static EcoBehavior parse(String? id) => values.firstWhere((b) => b.id == id, orElse: () => passive);
}
