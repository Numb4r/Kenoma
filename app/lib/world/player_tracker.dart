/// Junta a fonte de posição e o filtro: recebe as leituras, recusa as ruins e entrega o estado do
/// jogador (posição suavizada e como está o sinal). Dart puro.
library;

import 'dart:async';

import 'geo_fix.dart';
import 'gps_filter.dart';
import 'position_source.dart';

enum TrackingStatus {
  /// Ainda sem nenhuma leitura boa.
  searching,

  /// Posição boa e atual.
  tracking,

  /// As leituras chegam, mas todas pioram de 50 m: sem precisão para o jogo.
  poorAccuracy,
}

class PlayerState {
  const PlayerState({required this.status, required this.sourceName, this.position, this.lastRaw, this.rejected = 0});

  final TrackingStatus status;
  final String sourceName;

  /// A posição suavizada. `null` até a primeira leitura aceita.
  final FilteredPosition? position;

  /// A última leitura crua, boa ou ruim.
  final GeoFix? lastRaw;

  /// Quantas leituras o filtro recusou por precisão ruim.
  final int rejected;
}

class PlayerTracker {
  PlayerTracker({required this.source, GpsFilter? filter}) : _filter = filter ?? GpsFilter();

  final PositionSource source;
  final GpsFilter _filter;
  StreamSubscription<GeoFix>? _sub;
  final StreamController<PlayerState> _out = StreamController<PlayerState>.broadcast();
  PlayerState _state = const PlayerState(status: TrackingStatus.searching, sourceName: '');
  TrackingStatus _status = TrackingStatus.searching;

  /// O estado de agora.
  PlayerState get state => _state;

  /// Cada mudança de estado.
  Stream<PlayerState> get states => _out.stream;

  /// Começa a ouvir a fonte e a liga.
  Future<void> start() async {
    _sub ??= source.fixes.listen(_onFix);
    await source.start();
  }

  /// Para (app em segundo plano). A posição e o filtro ficam.
  Future<void> stop() async {
    await source.stop();
  }

  /// Esquece a posição (trocou de fonte, por exemplo): a próxima leitura boa recomeça o filtro.
  void reset() {
    _filter.reset();
    _status = TrackingStatus.searching;
    _state = PlayerState(status: _status, sourceName: source.name);
    _out.add(_state);
  }

  void _onFix(GeoFix fix) {
    final before = _filter.rejected;
    final p = _filter.add(fix);
    if (p != null) {
      _status = TrackingStatus.tracking;
    } else if (_filter.rejected > before && _filter.position == null) {
      _status = TrackingStatus.poorAccuracy; // nada bom ainda, e o que chega é ruim
    }
    _state = PlayerState(
      status: _status,
      sourceName: source.name,
      position: _filter.position,
      lastRaw: fix,
      rejected: _filter.rejected,
    );
    _out.add(_state);
  }

  Future<void> dispose() async {
    final sub = _sub;
    _sub = null;
    final stopped = source.stop(); // para a fonte já, antes de qualquer espera
    unawaited(sub?.cancel());
    await stopped;
    await _out.close();
  }
}
