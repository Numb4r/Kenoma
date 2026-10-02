/// De onde vêm as posições do jogador. O app só conhece esta interface: o GPS real e o simulador de
/// debug são fontes intercambiáveis, e trocar de uma para a outra não muda mais nada no código.
library;

import 'dart:async';

import 'geo_fix.dart';

abstract class PositionSource {
  /// Nome para a tela de debug (`GPS`, `Simulador`).
  String get name;

  /// As leituras. Fluxo múltiplo: várias telas podem ouvir. Só emite com a fonte iniciada.
  Stream<GeoFix> get fixes;

  /// Começa a emitir. Chamar de novo não faz nada.
  Future<void> start();

  /// Para de emitir (o app foi para segundo plano). Pode voltar com [start].
  Future<void> stop();
}

/// Uma fonte que encaminha a que estiver escolhida e deixa trocar a qualquer momento, inclusive com
/// o jogo rodando. Quem ouve [fixes] não percebe a troca.
class SwitchablePositionSource implements PositionSource {
  SwitchablePositionSource(PositionSource initial) : _current = initial;

  PositionSource _current;
  StreamSubscription<GeoFix>? _sub;
  bool _started = false;
  final StreamController<GeoFix> _out = StreamController<GeoFix>.broadcast();

  PositionSource get current => _current;

  @override
  String get name => _current.name;

  @override
  Stream<GeoFix> get fixes => _out.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = _current.fixes.listen(_out.add);
    await _current.start();
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _sub?.cancel();
    _sub = null;
    await _current.stop();
  }

  /// Passa a usar [next]. Se a fonte estava ligada, desliga a antiga e liga a nova.
  Future<void> switchTo(PositionSource next) async {
    if (identical(next, _current)) return;
    final wasStarted = _started;
    if (wasStarted) await stop();
    _current = next;
    if (wasStarted) await start();
  }
}
