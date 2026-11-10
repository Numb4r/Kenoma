/// Ferramentas de debug do menu (sempre acessível, CLAUDE.md): forçar o comportamento, a variante, o Brilhante e o
/// clima do próximo spawn. Só vale neste aparelho e nesta sessão: não entra no hash do mundo nem no save.
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/behavior.dart';
import 'debug_creatures.dart';

class DebugForce extends ChangeNotifier {
  /// Pedidos para o **próximo Eco novo** que aparecer à vista. Cada um é gasto quando o Eco aparece.
  EcoBehavior? nextBehavior;
  bool nextVariant = false;
  bool nextShiny = false;

  /// O próximo Eco novo vira o Espírito da família dele (ignora o nível mínimo do mapa).
  bool nextSpirit = false;

  /// O próximo Eco novo vira o Eco de ritual da família dele.
  bool nextRitual = false;

  /// Clima forçado (qualquer id do `clima.json`, inclusive os de evento): vale para o HUD, o desenho, as peças e os pesos
  /// de spawn enquanto estiver ligado. `null`: o de verdade.
  String? weather;

  /// A peça (`lightning`, `hail`, `dust_devil`, `meteor`...) que o próximo toque no mapa dispara ali. `null`: nenhuma.
  String? tapEffect;

  /// O pé do arco-íris ativo mais perto do Conjurador (latitude, longitude), posto pelo mapa do jogo enquanto ele está
  /// aberto: "Ir até o pé do arco-íris" teleporta o GPS simulado até lá. `null`: sem mapa ou sem arco.
  (double, double)? Function()? rainbowFoot;

  /// Gasta o pedido de efeito no toque.
  String? takeTapEffect() {
    final e = tapEffect;
    if (e != null) {
      tapEffect = null;
      notifyListeners();
    }
    return e;
  }

  /// As criaturas do "Criar criatura": nascem na Aura fora do mundo determinístico (`debug_creatures.dart`).
  final DebugCreatures creatures = DebugCreatures();

  bool get pendingEco => nextBehavior != null || nextVariant || nextShiny || nextSpirit || nextRitual;

  void set({EcoBehavior? behavior, bool? variant, bool? shiny, bool? spirit, bool? ritual, String? weather, bool clearWeather = false, String? tapEffect}) {
    if (tapEffect != null) this.tapEffect = tapEffect;
    if (ritual != null) nextRitual = ritual;
    if (behavior != null) nextBehavior = behavior;
    if (variant != null) nextVariant = variant;
    if (shiny != null) nextShiny = shiny;
    if (spirit != null) nextSpirit = spirit;
    if (weather != null) this.weather = weather;
    if (clearWeather) this.weather = null;
    notifyListeners();
  }

  /// Gasta os pedidos pendentes: devolve o que forçar no Eco que acabou de aparecer.
  ({EcoBehavior behavior, bool variant, bool shiny, bool spirit, bool ritual}) take() {
    final out = (behavior: nextBehavior ?? EcoBehavior.passive, variant: nextVariant, shiny: nextShiny, spirit: nextSpirit, ritual: nextRitual);
    nextRitual = false;
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
    nextRitual = false;
    weather = null;
    tapEffect = null;
    notifyListeners();
  }
}
