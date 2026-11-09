/// "Reduzir clarões" (Ajustes): para quem é sensível a luz piscando. Vale para todo clarão do jogo: o raio vira um
/// escurecimento leve, o brilho da coleta e a costura acesa da sintonia ficam fracos e o glitch da Estática pisca devagar.
/// O mapa copia o ajuste do save para cá, e as telas que não veem o save (sintonia) leem daqui.
library;

import 'package:flutter/foundation.dart' show ValueNotifier;

/// A chave do ajuste no save (um interruptor do aparelho, como os outros).
const String kReduceFlashesSetting = 'reduce_flashes';

final ValueNotifier<bool> reduceFlashes = ValueNotifier<bool>(false);
