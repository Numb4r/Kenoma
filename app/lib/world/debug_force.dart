/// Ferramentas de debug do menu (sempre acessível, CLAUDE.md): forçar o comportamento, a variante, o Brilhante e o
/// clima do próximo spawn. Só vale neste aparelho e nesta sessão: não entra no hash do mundo nem no save.
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/behavior.dart';
import '../core/weather.dart';

class DebugForce extends ChangeNotifier {
  /// Pedidos para o **próximo Eco novo** que aparecer à vista. Cada um é gasto quando o Eco aparece.
  EcoBehavior? nextBehavior;
  bool nextVariant = false;
  bool nextShiny = false;

  /// O próximo Eco novo vira o Espírito da família dele (ignora o nível mínimo do mapa).
  bool nextSpirit = false;

  /// Clima forçado: vale para o HUD, a chuva e os pesos de spawn enquanto estiver ligado. `null`: o de verdade.
  Weather? weather;

  bool get pendingEco => nextBehavior != null || nextVariant || nextShiny || nextSpirit;

  void set({EcoBehavior? behavior, bool? variant, bool? shiny, bool? spirit, Weather? weather, bool clearWeather = false}) {
    if (behavior != null) nextBehavior = behavior;
    if (variant != null) nextVariant = variant;
    if (shiny != null) nextShiny = shiny;
    if (spirit != null) nextSpirit = spirit;
    if (weather != null) this.weather = weather;
    if (clearWeather) this.weather = null;
    notifyListeners();
  }

  /// Gasta os pedidos pendentes: devolve o que forçar no Eco que acabou de aparecer.
  ({EcoBehavior behavior, bool variant, bool shiny, bool spirit}) take() {
    final out = (behavior: nextBehavior ?? EcoBehavior.passive, variant: nextVariant, shiny: nextShiny, spirit: nextSpirit);
    nextBehavior = null;
    nextVariant = false;
    nextShiny = false;
    nextSpirit = false;
    notifyListeners();
    return out;
  }

  void clearAll() {
    nextBehavior = null;
    nextVariant = false;
    nextShiny = false;
    nextSpirit = false;
    weather = null;
    notifyListeners();
  }
}
