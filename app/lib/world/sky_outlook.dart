/// O que o app Céu mostra do clima: a janela de agora e as próximas, cada uma com o clima da célula do jogador e, se um
/// evento ou o debug forçou o clima, o motivo. Dart puro. A tela do Céu só conhece o tipo [SkyOutlook]; quem calcula é
/// `climate_outlook.dart` (calendário, astronomia, feed assinado e debug, com a frase de cada evento do `clima.json`).
library;

import '../core/climate.dart' show ClimateSource;
import '../data/climate_catalog.dart';
import 'climate_outlook.dart';
import 'climate_world.dart';

/// Uma janela de clima: de quando a quando, o id do clima e o motivo, se não foi o sorteio da estação.
class SkyWindow {
  const SkyWindow({required this.startUtc, required this.endUtc, required this.climateId, this.reason});

  final int startUtc;
  final int endUtc;
  final String climateId;
  final String? reason;
}

/// As [count] janelas a partir da que contém `nowUtc`, no lugar do jogador.
typedef SkyOutlook = List<SkyWindow> Function(int nowUtc, int count);

/// O Céu a partir do [ClimateWorld] de hoje, na célula de ([lat], [lon]). [catalog] dá a frase de cada evento; sem ele,
/// as frases padrão de `climate_outlook.dart`.
SkyOutlook cellSkyOutlook(ClimateWorld world, {required double Function() lat, required double Function() lon, ClimateCatalog catalog = const ClimateCatalog()}) => (now, count) {
      if (count <= 0) return const [];
      final o = climateOutlook(world: world, catalog: catalog, lat: lat(), lon: lon(), nowUtc: now, windows: count - 1);
      return [
        for (final w in [o.now, ...o.next])
          SkyWindow(startUtc: w.startUtc, endUtc: w.endUtc, climateId: w.climate, reason: w.source == ClimateSource.season ? null : w.reason),
      ];
    };
