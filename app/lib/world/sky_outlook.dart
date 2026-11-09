/// O que o app Céu mostra do clima: a janela de agora e as próximas, cada uma com o clima da célula do jogador e, se um
/// evento ou o debug forçou o clima, o motivo. Dart puro.
///
/// MERGE-A: o agente A cria a API pura do clima com os eventos e os motivos (`ClimateOutlook` ou similar). No merge, troque
/// [cellSkyOutlook] por ela; a tela do Céu só conhece o tipo [SkyOutlook].
library;

import '../core/tiles.dart';
import '../core/windows.dart';
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

/// O Céu a partir do [ClimateWorld] de hoje, na célula z20 de ([lat], [lon]).
// MERGE-A: os motivos aqui são só "forçado no debug" e "evento do calendário"; A sabe o nome de cada evento.
SkyOutlook cellSkyOutlook(ClimateWorld world, {required double Function() lat, required double Function() lon}) => (now, count) {
      final (cx, cy) = latLonToTile(lat(), lon(), 20);
      final windowS = world.modelAt(now)?.$2.windowS ?? windowSeconds;
      final out = <SkyWindow>[];
      for (var i = 0; i < count; i++) {
        final start = (now ~/ windowS + i) * windowS, mid = start + windowS ~/ 2;
        String? reason;
        if (world.forced() != null) {
          reason = 'Forçado no menu de debug';
        } else if (world.events.any((e) => mid >= e.startsUtc && mid < e.endsUtc)) {
          reason = 'Evento do calendário';
        }
        out.add(SkyWindow(startUtc: start, endUtc: start + windowS, climateId: world.idAt(cx, cy, mid), reason: reason));
      }
      return out;
    };
