/// Onde Fagulhas, materiais e Ecos nascem dentro da célula: sobre o que dá para andar. Só a interface; quem a implementa
/// (`world/walk_paths.dart`) lê a geometria do pacote visual e o das vias onde não se anda (rodovias e vias expressas),
/// que a época 2 em diante fixa pelo SHA-256.
library;

/// Onde um item cai: o ponto ([px], [py]), em fração `[0, 1)` da célula z20, e se ele chega a nascer.
class Snap {
  const Snap(this.px, this.py, {this.keep = true});

  final double px;
  final double py;

  /// `false`: não há caminho andável perto (só rodovia, ou longe demais), então o item não nasce.
  final bool keep;
}

abstract interface class PathSnapper {
  /// Leva o ponto ([px], [py]) da célula z20 `([cellX], [cellY])` para o caminho andável mais próximo DENTRO da célula. Com
  /// [maxOffM] maior que zero o ponto só anda o que passa de [maxOffM] metros do caminho (os Ecos podem ficar até lá fora).
  /// Se o caminho mais próximo está a mais de [maxDistM] metros, ou a célula só tem vias onde não se anda, o item não nasce.
  /// `null` se a célula não tem via nenhuma no mapa: o ponto fica onde o sorteio o pôs.
  Snap? snap(int cellX, int cellY, double px, double py, {double maxOffM = 0, double maxDistM = 35});

  /// Metros de caminho andável dentro da célula (a chance de nascer é proporcional a ele). `null` se a célula não tem via
  /// nenhuma no mapa; 0 se só tem vias onde não se anda.
  double? walkLengthM(int cellX, int cellY);
}
