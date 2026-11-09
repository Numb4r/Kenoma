/// Lugares prontos para o mapa e para o teleporte do simulador.
library;

/// A Unicamp (Barão Geraldo): o centro inicial padrão do mapa.
const (double, double) kUnicamp = (-22.8174, -47.0697);

/// A Lagoa do Taquaral: o maior espelho de água e parque da cidade, bom para ver água e verde no mapa.
const (double, double) kTaquaral = (-22.8660, -47.0535);

/// O centro de Campinas, a célula do vetor de teste da spec.
const (double, double) kCentroCampinas = (-22.9056, -47.0608);

/// Lugares fora de Campinas, para conferir as camadas do mapa pelo debug: a Av. Paulista (dentro do pacote baixável de São
/// Paulo), um ponto da Rodovia dos Bandeirantes no Traviú (fora de qualquer pacote) e o centro de Jundiaí (sem pacote).
const (double, double) kPaulista = (-23.5614, -46.6559);
const (double, double) kBandeirantes = (-23.1287, -46.9819);
const (double, double) kJundiai = (-23.1864, -46.8842);

