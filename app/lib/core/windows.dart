/// Janelas de spawn de 20 minutos, com deslocamento próprio por célula (docs/fase0-spec.md, seção 3).
library;

import 'fnv.dart';

/// Duração da janela em segundos. Entra no hash do mundo, então é fixa.
const int windowSeconds = 1200;

/// `(FNV(seed_global, cell_x, cell_y, OFFS) >>> 32) % 1200`, com a célula z20.
int windowOffset(int seed, int cellX, int cellY) =>
    hashMod(fnv1a64([seed, cellX, cellY, saltOffs]), windowSeconds);

/// Índice da janela da célula no instante `tUtc` (segundos UTC desde a época Unix).
int windowIndex(int seed, int cellX, int cellY, int tUtc) =>
    (tUtc + windowOffset(seed, cellX, cellY)) ~/ windowSeconds;
