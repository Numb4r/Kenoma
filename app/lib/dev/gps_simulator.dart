/// Simulador de GPS do menu de debug: uma [PositionSource] que anda sob o comando de um joystick, com
/// velocidade ajustável, teleporte e, se quiser, ruído de GPS para exercitar o filtro. É uma fonte como
/// outra qualquer: o jogo não sabe que é falsa. Dart puro e determinístico: quem dirige o tempo é
/// [advance], e o relógio de verdade só entra no [start].
library;

import 'dart:async';
import 'dart:math' as math;

import '../core/pcg32.dart';
import '../world/geo_fix.dart';
import '../world/position_source.dart';

/// Velocidades prontas do joystick, em metros por segundo.
enum SimSpeed {
  walking('Andando', 1.4),
  running('Correndo', 3.0),
  cycling('Bicicleta', 6.0);

  const SimSpeed(this.label, this.mps);

  final String label;
  final double mps;
}

class SimulatedPositionSource implements PositionSource {
  SimulatedPositionSource({
    required this.lat,
    required this.lon,
    int startTimeMs = 0,
    this.fixInterval = const Duration(seconds: 1),
    this.accuracyM = 5,
    this.noiseM = 0,
    int noiseSeed = 1,
  })  : _timeMs = startTimeMs,
        _rng = Pcg32(noiseSeed, 0x73696d);

  double lat;
  double lon;

  /// Velocidade com o joystick no máximo, em m/s.
  double speedMps = SimSpeed.walking.mps;

  /// Precisão que cada leitura informa, em metros.
  double accuracyM;

  /// Desvio do ruído gaussiano somado a cada leitura, em metros. 0 desliga.
  double noiseM;

  /// Intervalo entre leituras.
  final Duration fixInterval;

  final Pcg32 _rng;
  double _jx = 0, _jy = 0;
  int _timeMs;
  int _sinceFixMs = 0;
  bool _started = false;
  Timer? _timer;
  Stopwatch? _watch;
  int _lastTickMs = 0;
  int _lastEmitMs = -1;
  final StreamController<GeoFix> _out = StreamController<GeoFix>.broadcast();

  static const double _mPerDegLat = 111132.92;
  static const double _mPerDegLon = 111319.49;

  @override
  String get name => 'Simulador';

  @override
  Stream<GeoFix> get fixes => _out.stream;

  /// Direção do joystick: [x] para leste e [y] para norte, de -1 a 1. Passar de 1 de comprimento
  /// satura: o joystick nunca dá mais que a velocidade ajustada.
  void setJoystick(double x, double y) {
    final len = math.sqrt(x * x + y * y);
    final k = len > 1 ? 1 / len : 1.0;
    _jx = x * k;
    _jy = y * k;
  }

  double get joystickX => _jx;
  double get joystickY => _jy;

  /// Leva o jogador para uma coordenada e emite uma leitura na hora.
  void teleport(double newLat, double newLon) {
    lat = newLat;
    lon = newLon;
    _emit();
  }

  /// Avança o tempo de [dt]: anda segundo o joystick e emite uma leitura a cada [fixInterval].
  void advance(Duration dt) {
    final ms = dt.inMilliseconds;
    if (ms <= 0) return;
    var left = ms;
    // Em passos de no máximo uma leitura, para o intervalo e o movimento não dependerem do tamanho de dt.
    while (left > 0) {
      final step = math.min(left, fixInterval.inMilliseconds - _sinceFixMs);
      final s = step / 1000.0;
      final east = _jx * speedMps * s, north = _jy * speedMps * s;
      lat += north / _mPerDegLat;
      lon += east / (_mPerDegLon * math.cos(lat * math.pi / 180));
      _timeMs += step;
      _sinceFixMs += step;
      left -= step;
      if (_sinceFixMs >= fixInterval.inMilliseconds) {
        _sinceFixMs = 0;
        _emit();
      }
    }
  }

  double _gauss(double sigma) {
    final u1 = 1 - _rng.nextFloat(), u2 = _rng.nextFloat();
    return sigma * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  void _emit() {
    if (!_started) return;
    var la = lat, lo = lon;
    if (noiseM > 0) {
      la += _gauss(noiseM) / _mPerDegLat;
      lo += _gauss(noiseM) / (_mPerDegLon * math.cos(lat * math.pi / 180));
    }
    // O tempo das leituras só cresce: um teleporte logo depois de uma leitura não pode repetir o instante.
    final t = math.max(_timeMs, _lastEmitMs + 1);
    _lastEmitMs = t;
    _out.add(GeoFix(lat: la, lon: lo, accuracyM: accuracyM, timeMs: t));
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _watch = Stopwatch()..start();
    _lastTickMs = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = _watch!.elapsedMilliseconds;
      advance(Duration(milliseconds: now - _lastTickMs));
      _lastTickMs = now;
    });
    _emit(); // a primeira leitura sai logo, como um GPS que já tem posição
  }

  @override
  Future<void> stop() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _watch = null;
  }
}
