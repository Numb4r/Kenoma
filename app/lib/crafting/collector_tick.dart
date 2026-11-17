/// Um passo dos coletores, igual no mapa e na Patrulha: o cinto enche com a condição em volta do jogador, os plantados
/// seguem a conta do lugar deles e os guardados na bolsa estragam no mesmo ritmo. Conta `vessel_filled` (o mentor entrega
/// a página da lua na primeira). Dart puro.
library;

import '../player/game_state.dart';
import 'collectors.dart';
import 'conditions.dart';
import 'crafting_data.dart';
import 'crafting_state.dart';

/// O que encheu neste passo: no cinto e plantado (este só uma vez por enchida, para a Patrulha avisar uma vez).
typedef CollectorNews = ({List<Vessel> belt, List<Vessel> planted});

CollectorNews tickCollectors(GameState s, CraftingBook book, {required Here Function(double lat, double lon, int t) hereAt, required double lat, required double lon, required int now, required double dtS}) {
  final belt = s.crafting.at(VesselPlace.belt).isEmpty ? const <Vessel>[] : tickBelt(s, hereAt(lat, lon, now), dtS, book);
  final planted = <Vessel>[];
  for (final v in s.crafting.at(VesselPlace.planted).toList()) {
    final st = updatePlanted(v, now, (t) => hereAt(v.lat, v.lon, t), book);
    if (st == PlantedState.full && !v.notified) {
      v.notified = true;
      planted.add(v);
    }
  }
  // Os guardados na bolsa estragam no mesmo ritmo: o que estraga sem virar nada volta a ser recipiente vazio (pilha).
  for (final v in s.crafting.at(VesselPlace.bag).toList()) {
    if (settle(v, now, book) && v.empty) {
      s.crafting.vessels.remove(v);
      s.add(v.kind, 1);
    }
  }
  for (final v in [...belt, ...planted]) {
    s.recordEvent('vessel_filled', v.content ?? '', 1);
  }
  if (s.crafting.vessels.isNotEmpty) s.changed();
  return (belt: belt, planted: planted);
}
