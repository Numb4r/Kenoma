/// Ferramentas de debug do menu (sempre acessível, CLAUDE.md): forçar o comportamento, a variante, o Brilhante e o
/// clima do próximo spawn. Só vale neste aparelho e nesta sessão: não entra no hash do mundo nem no save.
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/behavior.dart';
import 'climate_sim.dart';
import 'climate_world.dart' show ForcedPhase;
import 'debug_creatures.dart';

double _wallNowS() => DateTime.now().microsecondsSinceEpoch / 1e6;

class DebugForce extends ChangeNotifier {
  /// [wallS] é o relógio de parede em segundos (os testes trocam): o clima forçado forma com ele, não com o relógio do jogo.
  DebugForce({double Function()? wallS}) : _wall = wallS ?? _wallNowS {
    _clockT0 = _wall();
  }

  final double Function() _wall;
  /// Pedidos para o **próximo Eco novo** que aparecer à vista. Cada um é gasto quando o Eco aparece.
  EcoBehavior? nextBehavior;
  bool nextVariant = false;
  bool nextShiny = false;

  /// O próximo Eco novo vira o Espírito da família dele (ignora o nível mínimo do mapa).
  bool nextSpirit = false;

  /// O próximo Eco novo vira o Eco de ritual da família dele.
  bool nextRitual = false;

  /// Clima forçado (qualquer id do `clima.json`, inclusive os de evento): vale para o HUD, o desenho, as peças e os pesos
  /// de spawn enquanto estiver ligado. `null`: o de verdade. Com a simulação ligada, o dela.
  String? get weather {
    _syncSim();
    return _current;
  }

  String? _current;

  /// "Velocidade do clima" (1, 10 ou 60): quantos segundos de clima passam por segundo no clima forçado. Só a formação das
  /// marcas no chão deste aparelho; o mundo e o relógio do jogo não mudam.
  double get speed => _speed;
  double _speed = 1;
  double _clockAcc = 0;
  late double _clockT0;

  /// O relógio do clima forçado, em segundos de clima.
  double _clock() => _clockAcc + (_wall() - _clockT0) * _speed;

  void setSpeed(double v) {
    if (v == _speed || v <= 0) return;
    _clockAcc = _clock();
    _clockT0 = _wall();
    _speed = v;
    notifyListeners();
  }

  double _startC = 0, _prevFormedC = 0, _prevEndC = 0;
  String? _prevId;

  /// O clima forçado [id] começa do zero agora; o de antes passa a secar.
  void _begin(String? id) {
    final now = _clock();
    if (_current != null && id != null) {
      _prevId = _current;
      _prevFormedC = now - _startC;
      _prevEndC = now;
    } else {
      _prevId = null;
    }
    _current = id;
    _startC = now;
  }

  /// A fase do clima forçado agora (ver [ForcedPhase]).
  ForcedPhase phase() {
    _syncSim();
    final now = _clock();
    return (ageS: now - _startC, prevId: _prevId, prevFormedS: _prevFormedC, prevSinceEndS: now - _prevEndC);
  }

  /// A "Simulação de clima": passa por [ClimateSim.ids], um depois do outro. `null`: desligada.
  ClimateSim? get sim => _sim;
  ClimateSim? _sim;
  Object? _simKey;

  /// A simulação está ligada: nada do que se pega dá recompensa (como o GPS simulado sem recompensa).
  bool get simulating => _sim != null;

  /// Liga a simulação com os climas [ids], [stepS] segundos de parede por clima, em 60x.
  void startSim(List<String> ids, {double stepS = 120, double speed = 60}) {
    if (ids.isEmpty) return;
    _sim = ClimateSim(ids: ids, stepS: stepS, startS: _wall());
    _simKey = null;
    setSpeed(speed);
    _syncSim();
    notifyListeners();
  }

  void stopSim() {
    if (_sim == null) return;
    _sim = null;
    _simKey = null;
    _begin(null);
    notifyListeners();
  }

  /// Pula a simulação para o clima de índice [i] (começa do zero).
  void simJump(int i) {
    _sim?.jump(i, _wall());
    _syncSim();
    notifyListeners();
  }

  /// Repete o clima atual da simulação (do zero, sem passar para o próximo) ou volta à sequência.
  void simRepeat(bool on) {
    _sim?.setRepeat(on, _wall());
    _syncSim();
    notifyListeners();
  }

  void simStep(double stepS) {
    _sim?.setStep(stepS, _wall());
    _syncSim();
    notifyListeners();
  }

  /// O que a simulação mostra agora, ou `null`.
  SimState? simState() => _sim?.at(_wall());

  /// Troca o forçado quando a simulação muda de passo. Não avisa os ouvintes (é chamado no meio do desenho).
  void _syncSim() {
    final s = _sim;
    if (s == null) return;
    final st = s.at(_wall());
    final key = (st.index, st.round, st.fading);
    if (key == _simKey) return;
    _simKey = key;
    if (st.fading) {
      _begin(ClimateSim.fadeTo); // o clima acaba: o que ele deixou no chão seca
    } else {
      _current = null; // o passo novo começa do zero, sem herdar o de antes
      _begin(st.id);
    }
  }

  /// A peça (`lightning`, `hail`, `dust_devil`, `meteor`...) que o próximo toque no mapa dispara ali. `null`: nenhuma.
  String? tapEffect;

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
    if (weather != null || clearWeather) {
      _sim = null;
      _simKey = null;
      _begin(clearWeather ? null : weather); // começa do zero agora; o forçado de antes seca

    }
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
    _sim = null;
    _simKey = null;
    _begin(null);
    tapEffect = null;
    notifyListeners();
  }
}
