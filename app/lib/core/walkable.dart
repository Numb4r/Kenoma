/// Onde Fagulhas, materiais e Ecos nascem dentro da célula: sobre o que dá para andar. Só a interface; quem a implementa
/// (`world/walk_paths.dart`) lê a geometria do pacote visual, que a época 2 em diante fixa pelo SHA-256.
library;

abstract interface class PathSnapper {
  /// Leva o ponto ([px], [py]), em fração `[0, 1)` da célula z20 `([cellX], [cellY])`, para o caminho andável mais
  /// próximo DENTRO da célula. Com [maxOffM] maior que zero o ponto só anda o que passa de [maxOffM] metros do caminho
  /// (os Ecos podem ficar até lá fora). `null` se a célula não tem nada andável: o ponto fica onde o sorteio o pôs.
  (double, double)? snap(int cellX, int cellY, double px, double py, {double maxOffM = 0});
}
