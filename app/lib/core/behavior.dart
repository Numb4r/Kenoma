/// Comportamento de um Eco (docs/GDD.md, "Início do encontro"): como a sintonia começa. Sorteado no fluxo `v2` da
/// célula, igual para todos do grupo.
library;

enum EcoBehavior {
  passive('passive', 'Passivo'),
  hidden('hidden', 'Oculto');

  const EcoBehavior(this.id, this.label);

  /// A chave no JSON e no save.
  final String id;

  /// O nome na interface.
  final String label;

  /// Os comportamentos do sorteio das épocas 3 a 10, na ordem dos pesos. Arisco e Agressivo saíram do jogo na 0.20.0: o
  /// sorteio dessas épocas continua igual (os mesmos Ecos, o mesmo Oculto), e quem saía Arisco ou Agressivo é Passivo.
  static const List<String> drawOrder = ['passive', 'skittish', 'aggressive', 'hidden'];

  /// O comportamento da chave [id]; as que não existem mais (`skittish`, `aggressive`) e as desconhecidas viram Passivo.
  static EcoBehavior parse(String? id) => values.firstWhere((b) => b.id == id, orElse: () => passive);
}
