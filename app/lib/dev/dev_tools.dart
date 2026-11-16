/// Ferramentas de dev reunidas: a fonte de posição trocável (GPS real ou simulador) e o relógio com
/// override. Mora no menu de debug, que fica em todas as builds de teste (CLAUDE.md).
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../net/feed_config.dart';
import '../world/debug_force.dart';
import '../world/places.dart';
import '../world/position_source.dart';
import 'emulator.dart';
import 'game_clock.dart';
import 'gps_simulator.dart';

class DevTools extends ChangeNotifier {
  DevTools({required PositionSource realSource, SimulatedPositionSource? simulator, GameClock? clock})
      : simulator = simulator ?? SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2),
        clock = clock ?? GameClock(),
        _real = realSource {
    source = SwitchablePositionSource(realSource);
  }

  final PositionSource _real;

  /// O simulador. Sempre existe: usá-lo ou não é o [useSimulator].
  final SimulatedPositionSource simulator;
  final GameClock clock;

  /// O que o menu de debug força no próximo spawn (comportamento, variante, Brilhante) e o clima forçado.
  final DebugForce force = DebugForce();

  /// A fonte que o jogo ouve. Troca entre o GPS real e o simulador sem o jogo perceber.
  late final SwitchablePositionSource source;

  bool _useSimulator = false;

  bool _showBiomeGrid = false;
  bool _showGrid20 = false;
  bool _showRadii = false;

  /// Sobreposição de debug no mapa do jogo: a grade de biomas (a camada lógica) e a grade das células de spawn.
  bool get showBiomeGrid => _showBiomeGrid;
  bool get showGrid20 => _showGrid20;

  /// Desenha o raio lógico da Aura e o alcance de 30 m por cima do mapa.
  bool get showRadii => _showRadii;

  bool _showRelief = false;

  /// Desenha o relevo como mapa de calor por cima do mapa do jogo, com a altura de cada célula.
  bool get showRelief => _showRelief;

  void setRelief(bool v) {
    _showRelief = v;
    notifyListeners();
  }

  bool _showTraffic = false;
  double? _trafficDensity;

  /// Tráfego simulado: desenha a área, as entradas e a fase dos semáforos; e força a densidade (`null`: hora e clima).
  bool get showTraffic => _showTraffic;
  double? get trafficDensity => _trafficDensity;

  void setTraffic({bool? show, double? density, bool clearDensity = false}) {
    _showTraffic = show ?? _showTraffic;
    _trafficDensity = clearDensity ? null : density ?? _trafficDensity;
    notifyListeners();
  }

  bool _showPuddles = false;

  /// Marca as poças no mapa do jogo: as da camada pessoal (Rill) numa cor e as do mundo (água do relevo) em outra.
  bool get showPuddles => _showPuddles;

  void setShowPuddles(bool v) {
    _showPuddles = v;
    notifyListeners();
  }

  /// A poça mais próxima do jogador a até 1 km (lat, lon), ou `null` (quem monta o mapa do jogo preenche).
  (double, double)? Function()? nearestPuddle;

  /// Vai até a poça mais próxima com o GPS simulado e sem recompensa (a regra do debug). Devolve o aviso para a tela.
  Future<String> goToNearestPuddle() async {
    final p = nearestPuddle?.call();
    if (p == null) return nearestPuddle == null ? 'Abra o mapa do jogo antes' : 'Nenhuma poça a até 1 km (está chovendo?)';
    setSimRewards(false);
    await setUseSimulator(true);
    simulator.teleport(p.$1, p.$2);
    return 'Na poça mais próxima (GPS simulado, sem recompensa)';
  }

  bool _hidePersonal = false;

  /// Esconde a camada pessoal de spawn (o que o Círculo acrescenta só para este jogador), para conferir o mundo base.
  bool get hidePersonal => _hidePersonal;

  void setHidePersonal(bool v) {
    _hidePersonal = v;
    notifyListeners();
  }

  List<String>? _testCircle;

  /// Círculo de teste, só nesta sessão e só no mapa (as habilidades de mapa; o save não muda): as espécies, no nível 10.
  /// `null`: o Círculo de verdade. Vazio: Círculo vazio.
  List<String>? get testCircle => _testCircle;

  void setTestCircle(List<String>? ids) {
    _testCircle = ids == null ? null : [...ids.take(3)];
    notifyListeners();
  }

  /// A célula z20 e a janela de agora, com os resumos das camadas base e pessoal (quem monta o mapa do jogo preenche).
  String Function()? layerHashes;

  /// O que a camada pessoal acrescentou nesta sessão (quem monta o mapa do jogo preenche).
  String Function()? personalStats;

  /// O que a simulação do tráfego diz de si (quem desenha o mapa do jogo preenche): agentes e custo do passo.
  String Function()? trafficStats;

  /// 0.22.0: a câmera do mapa segue a peça do clima que anda (funil do tornado, Procissão, olhar da Vigília, prédio da
  /// Maré) em vez do Conjurador. Só para fotos e vídeos do workbench.
  bool _followPiece = false;
  bool get followPiece => _followPiece;
  void setFollowPiece(bool on) {
    _followPiece = on;
    notifyListeners();
  }

  void setOverlays({bool? biomes, bool? grid20, bool? radii}) {
    _showRadii = radii ?? _showRadii;
    _showBiomeGrid = biomes ?? _showBiomeGrid;
    _showGrid20 = grid20 ?? _showGrid20;
    notifyListeners();
  }

  bool get useSimulator => _useSimulator;

  bool _simRewards = false;

  /// "GPS simulado dá recompensa". Desligado (o padrão), nada que se ganha com o simulador conta para XP, estatísticas ou
  /// bestiário nem entra na Bolsa, no mapa e na Patrulha simulada, e as capturas entram marcadas como debug.
  bool get simRewards => _simRewards;

  void setSimRewards(bool value) {
    if (value == _simRewards) return;
    _simRewards = value;
    notifyListeners();
  }

  bool _emulator = false;

  /// O app roda num emulador: a localização dele conta como GPS simulado (GDD, Salvaguardas).
  bool get emulator => _emulator;

  /// Descobre se é um emulador (uma vez, ao abrir o app).
  Future<void> detect() async => setEmulator(await detectEmulator());

  void setEmulator(bool v) {
    if (v == _emulator) return;
    _emulator = v;
    notifyListeners();
  }

  /// O simulador está ligado ou é um emulador, sem o interruptor de recompensa; ou a Simulação de clima está ligada (ela
  /// nunca dá recompensa).
  bool get sandboxed => sandboxFor(simulator: _useSimulator, emulator: _emulator, rewards: _simRewards, climateSim: force.simulating);

  String? _feedUrl;

  /// A base do feed de regiões, terminada em `/`: a publicada ou a que o debug pôs, para testar com servidor local via `adb
  /// reverse`. Vale até fechar o app. A assinatura continua obrigatória.
  String get feedBaseUrl => _feedUrl ?? kFeedBaseUrl;

  void setFeedBaseUrl(String? url) {
    final u = url?.trim() ?? '';
    _feedUrl = u.isEmpty ? null : (u.endsWith('/') ? u : '$u/');
    notifyListeners();
  }

  int _levelOverride = 0;

  /// Nível do Conjurador forçado no save (1 a 15); 0 é o nível real. O menu carrega do save e mantém em dia.
  int get levelOverride => _levelOverride;

  void setLevelOverride(int level) {
    if (level == _levelOverride) return;
    _levelOverride = level;
    notifyListeners();
  }

  /// Algo forçado está ativo: simulador, relógio, nível, pedidos de spawn, clima ou sobreposições. Liga a etiqueta DEBUG.
  bool get anyForcing =>
      _useSimulator || _feedUrl != null || clock.overridden || _levelOverride != 0 || force.pendingEco || force.weather != null || force.events.isNotEmpty || _hidePersonal || _showPuddles || _testCircle != null || _showBiomeGrid || _showGrid20 || _showRadii || _followPiece || _showRelief || _showTraffic || _trafficDensity != null;

  Future<void> setUseSimulator(bool value) async {
    if (value == _useSimulator) return;
    _useSimulator = value;
    await source.switchTo(value ? simulator : _real);
    notifyListeners();
  }
}
