/// Lê o texto das notificações de corrida com os padrões de `assets/data/ride_patterns.json`, um arquivo de dados que dá
/// para atualizar sem mexer no código. O texto entra, vira um [RideSignal] e é descartado: nada é guardado aqui. O que não
/// é reconhecido devolve [RideSignal.empty] e a corrida segue pelos botões. Dart puro.
library;

import 'ride.dart';

const Map<String, RideState> _stateKeys = {
  'searching': RideState.searching,
  'driver_coming': RideState.driverComing,
  'arrived': RideState.arrived,
  'in_trip': RideState.inTrip,
  'finished': RideState.finished,
};

RegExp? _regex(Object? source) {
  try {
    return RegExp(source as String, caseSensitive: false, unicode: true);
  } on FormatException {
    return null; // padrão quebrado no arquivo: fica de fora, e os botões cobrem
  }
}

List<RegExp> _regexes(Object? list) => [
      for (final s in (list as List<dynamic>?) ?? const [])
        if (_regex(s) != null) _regex(s)!,
    ];

/// Palavra inteira, com acento contando como letra (o `\\b` do Dart só conhece ASCII).
RegExp? _word(Object? source) => _regex('(?<![\\p{L}\\d])(?:$source)(?![\\p{L}\\d])');

int _hex(String s) => 0xFF000000 | int.parse(s.substring(1), radix: 16);

class _AppPatterns {
  _AppPatterns(Map<String, dynamic> j)
      : states = {
          // Do fim para o começo: "você chegou ao destino" não pode valer como "motorista a caminho".
          for (final k in _stateKeys.keys.toList().reversed)
            _stateKeys[k]!: _regexes((j['states'] as Map<String, dynamic>)[k]),
        },
        eta = _regexes(j['eta']);

  final Map<RideState, List<RegExp>> states;
  final List<RegExp> eta;
}

class RidePatterns {
  RidePatterns({required Map<String, dynamic> apps, required Map<String, dynamic> car})
      : _apps = {for (final e in apps.entries) e.key: _AppPatterns(e.value as Map<String, dynamic>)},
        _models = [
          for (final e in ((car['models'] as Map<String, dynamic>?) ?? const {}).entries)
            for (final m in e.value as List<dynamic>)
              if (_word(m) != null) (e.key, _word(m)!),
        ],
        _colors = [
          for (final c in (car['colors'] as List<dynamic>?) ?? const [])
            if (_word(c['pattern']) != null) (_word(c['pattern'])!, _hex(c['hex'] as String)),
        ],
        defaultType = (car['default_type'] as String?) ?? 'hatch',
        defaultColor = _hex((car['default_color'] as String?) ?? '#8A8FA3');

  factory RidePatterns.fromJson(Map<String, dynamic> j) => RidePatterns(apps: (j['apps'] as Map<String, dynamic>?) ?? const {}, car: (j['car'] as Map<String, dynamic>?) ?? const {});

  /// Sem padrões: toda corrida vai pelos botões.
  factory RidePatterns.none() => RidePatterns(apps: const {}, car: const {});

  final Map<String, _AppPatterns> _apps;
  final List<(String, RegExp)> _models;
  final List<(RegExp, int)> _colors;

  /// O carro quando a notificação não diz.
  final String defaultType;
  final int defaultColor;

  /// Interpreta o título e o texto de uma notificação de [package].
  RideSignal parse(String package, String title, String text) {
    final app = _apps[package];
    if (app == null) return RideSignal.empty;
    final all = '$title\n$text';
    RideState? state;
    for (final e in app.states.entries) {
      if (e.value.any((r) => r.hasMatch(all))) {
        state = e.key;
        break;
      }
    }
    int? eta;
    for (final r in app.eta) {
      final m = r.firstMatch(all);
      if (m != null && m.groupCount >= 1) {
        eta = int.tryParse(m.group(1) ?? '');
        if (eta != null) break;
      }
    }
    String? type;
    for (final (t, r) in _models) {
      if (r.hasMatch(all)) {
        type = t;
        break;
      }
    }
    int? color;
    for (final (r, c) in _colors) {
      if (r.hasMatch(all)) {
        color = c;
        break;
      }
    }
    return RideSignal(state: state, etaMin: eta, carType: type, carColor: color);
  }
}
