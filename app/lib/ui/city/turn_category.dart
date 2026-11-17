/// 0.22.2: a categoria de giro de cada tipo de objeto do mapa (`docs/art/estilo-mapa.md`, "O que gira e o que fica de pé"):
/// o que é chão gira com o mapa; o que tem altura ou é sprite fica de pé na tela e só muda de posição; o que segue o rumo
/// (veículos vistos de cima) gira com a direção em que anda. O modo de debug "Giro dos objetos" escreve isto sobre cada um.
library;

enum Turn {
  /// Gira com o chão (contorno, textura e tudo).
  ground,

  /// Fica de pé na tela; só a posição acompanha o mapa.
  upright,

  /// Gira com o rumo do próprio objeto (o carro aponta para onde anda). Exceção à regra, à espera da decisão do dono.
  heading,
}

/// O tipo de objeto e a categoria. Os nomes são os que o modo de debug escreve.
const Map<String, Turn> objectTurn = {
  'rua': Turn.ground, // e o desenho do asfalto: remendo, óleo, rachadura
  'calçada': Turn.ground,
  'faixa de pedestre': Turn.ground,
  'lote e quintal': Turn.ground,
  'sombra': Turn.ground,
  'marca do clima': Turn.ground,
  'telhado': Turn.ground, // o contorno e a textura, presa à aresta mais longa
  'parede': Turn.upright, // sai do centro da tela para fora
  'janela': Turn.upright,
  'caixa d\'água / ar / antena': Turn.upright,
  'letreiro': Turn.upright,
  'árvore': Turn.upright,
  'ipê': Turn.upright,
  'poste': Turn.upright,
  'ponto de ônibus': Turn.upright,
  'banca': Turn.upright,
  'Eco': Turn.upright,
  'Fagulha': Turn.upright,
  'material': Turn.upright,
  'Conjurador': Turn.upright,
  'passante': Turn.upright,
  'ciclista': Turn.heading,
  'carro': Turn.heading,
  'ônibus': Turn.heading,
  'barco': Turn.heading,
  'nome de rua': Turn.heading, // acompanha a direção da rua
};

String turnLabel(String kind) => switch (objectTurn[kind] ?? Turn.upright) {
      Turn.ground => '$kind · gira com o chão',
      Turn.upright => '$kind · de pé',
      Turn.heading => '$kind · gira com o rumo',
    };

/// O tipo de um prop da cena (`CityProp.kind`) no nome do modo de debug.
String propKindName(String kind) => switch (kind) {
      'lamp' => 'poste',
      'bus_stop' => 'ponto de ônibus',
      'newsstand' => 'banca',
      'crosswalk' => 'faixa de pedestre',
      _ when kind.startsWith('ipe') => 'ipê',
      _ => 'árvore',
    };
