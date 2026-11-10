/// A Procissão na névoa pelas ruas: uma fila de figuras encapuzadas, uma atrás da outra, numa rota sobre o grafo de ruas
/// costurado (o mesmo das rotas, `stitch`), do ponto onde a zona da Procissão nasce até onde nasce o Eco do fim. A fila anda
/// a [ProcessionPlan.speedMps] e chega ao fim no instante em que o Eco aparece; onde ela passa ficam velas acesas no chão.
/// Tudo sai da zona do mundo (ponto, direção, horário: seed, época, célula e janela) e do pacote visual: dois aparelhos
/// veem a mesma fila no mesmo lugar. Só desenho: o Eco continua onde o mundo da época o põe. Dart puro.
library;

import 'dart:math' as math;

import '../core/climate.dart';
import '../core/fnv.dart';
import '../travel/travel_path.dart';
import 'traffic_graph.dart';

/// Os números da fila (o bloco `procession` do `clima.json`): só desenho.
class ProcessionLook {
  const ProcessionLook({this.minFigures = 12, this.maxFigures = 20, this.spacingM = 1.6, this.speedMps = 0.8, this.candleEveryM = 6, this.candleS = 1800, this.visibleM = 120, this.snapM = 80});

  final int minFigures, maxFigures;
  final double spacingM, speedMps, candleEveryM, candleS, visibleM, snapM;
}

/// Uma figura da fila agora: posição (células z21), direção (rad, do leste no sentido horário) e quanto ela aparece.
typedef ProcessionFigure = ({double x, double y, double heading, double alpha});

/// Uma vela no chão: onde e desde quando acesa.
typedef ProcessionCandle = ({double x, double y, double litUtc});

class ProcessionPlan {
  ProcessionPlan({required this.route, required this.arriveUtc, required this.startUtc, required this.endUtc, required this.figures, required this.look, required this.ecoX, required this.ecoY, required this.mpc});

  /// O caminho pelas ruas, do começo ao fim (o ponto de rua mais perto do Eco).
  final TravelPath route;

  /// Quando a frente da fila chega ao fim (o instante em que o Eco aparece) e a janela da zona.
  final double arriveUtc;
  final int startUtc, endUtc;
  final int figures;
  final ProcessionLook look;

  /// Onde o mundo põe o Eco do fim (a trilha de velas vai do fim da rota até ele).
  final double ecoX, ecoY;
  final double mpc;

  double get speedMps => look.speedMps;

  /// Metros da rota onde está a frente da fila em [t]: chega ao fim em [arriveUtc] e fica lá.
  double headAt(double t) => route.lengthM - speedMps * (arriveUtc - t);

  /// As figuras em [t]: aparecem na névoa no começo da zona e somem 30 s depois do fim.
  List<ProcessionFigure> figuresAt(double t) {
    if (t < startUtc || t > endUtc + 30) return const [];
    final fade = math.min(((t - startUtc) / 20).clamp(0.0, 1.0), (1 - (t - endUtc) / 30).clamp(0.0, 1.0));
    final head = headAt(t);
    final out = <ProcessionFigure>[];
    for (var i = 0; i < figures; i++) {
      final s = math.min(route.lengthM, head - i * look.spacingM);
      if (s < 0) break;
      final p = route.at(s);
      out.add((x: p.x, y: p.y, heading: p.heading, alpha: fade));
    }
    return out;
  }

  /// As velas acesas em [t]: uma a cada [ProcessionLook.candleEveryM] por onde a frente passou, acesas por
  /// [ProcessionLook.candleS], e a trilha do fim da rota até o Eco.
  List<ProcessionCandle> candlesAt(double t) {
    final out = <ProcessionCandle>[];
    final walkedFrom = math.max(0.0, route.lengthM - speedMps * (arriveUtc - startUtc));
    final every = look.candleEveryM;
    for (var s = (walkedFrom / every).ceil() * every; s <= route.lengthM; s += every) {
      final lit = arriveUtc - (route.lengthM - s) / speedMps;
      if (t < lit || t >= lit + look.candleS) continue;
      final p = route.at(s);
      out.add((x: p.x, y: p.y, litUtc: lit));
    }
    if (t >= arriveUtc && t < arriveUtc + look.candleS) {
      final e = route.at(route.lengthM);
      final d = math.sqrt((ecoX - e.x) * (ecoX - e.x) + (ecoY - e.y) * (ecoY - e.y)) * mpc;
      for (var m = every / 2; m < d; m += every / 2) {
        out.add((x: e.x + (ecoX - e.x) * m / d, y: e.y + (ecoY - e.y) * m / d, litUtc: arriveUtc));
      }
    }
    return out;
  }
}

/// Quantas figuras a fila da zona [uidBase] tem: de [ProcessionLook.minFigures] a [ProcessionLook.maxFigures], pela seed.
int processionSize(int uidBase, ProcessionLook look) => look.minFigures + (fnv1a64([uidBase, 0x9C0]) >>> 33) % (look.maxFigures - look.minFigures + 1);

/// A rota da Procissão da zona [z]: do ponto de rua mais perto de onde ela nasce até o mais perto de onde nasce o Eco do fim
/// (`slot_at` do percurso da zona), a pé, pelo grafo costurado. `null`: sem rua perto ou sem caminho.
ProcessionPlan? planProcession(TrafficGraph graph, ClimateZone z, {required double mpc, ProcessionLook look = const ProcessionLook(), int maxNodes = 40000}) {
  final p = z.piece;
  final arrive = z.startUtc + (p.slotAt ?? 0.95) * p.durationS;
  final (ex, ey) = z.centerAt(arrive, mpc);
  final route = _onStreets(findRoute(graph, fromX: z.x0, fromY: z.y0, toX: ex, toY: ey, rules: const RouteRules(RouteProfile.foot), mpc: mpc, snapM: look.snapM, maxNodes: maxNodes), mpc);
  if (route == null || route.lengthM < look.spacingM) return null;
  return ProcessionPlan(route: route, arriveUtc: arrive, startUtc: z.startUtc, endUtc: z.endUtc, figures: processionSize(z.uidBase, look), look: look, ecoX: ex, ecoY: ey, mpc: mpc);
}

/// A rota sem as duas pontas fora da rua (a busca começa no ponto pedido e termina no destino): só o que está sobre as ruas.
TravelPath? _onStreets(TravelPath? r, double mpc) {
  if (r == null || r.offData || r.pointCount < 4) return null;
  return TravelPath(r.xy.sublist(2, r.xy.length - 2), mpc);
}

/// A mesma rota de [planProcession] em fatias, devolvendo o controle entre elas (o mapa não trava).
Future<ProcessionPlan?> planProcessionAsync(TrafficGraph graph, ClimateZone z, {required double mpc, ProcessionLook look = const ProcessionLook(), int maxNodes = 40000}) async {
  final p = z.piece;
  final arrive = z.startUtc + (p.slotAt ?? 0.95) * p.durationS;
  final (ex, ey) = z.centerAt(arrive, mpc);
  final route = _onStreets(await findRouteAsync(graph, fromX: z.x0, fromY: z.y0, toX: ex, toY: ey, rules: const RouteRules(RouteProfile.foot), mpc: mpc, snapM: look.snapM, maxNodes: maxNodes, sliceNodes: 600), mpc);
  if (route == null || route.lengthM < look.spacingM) return null;
  return ProcessionPlan(route: route, arriveUtc: arrive, startUtc: z.startUtc, endUtc: z.endUtc, figures: processionSize(z.uidBase, look), look: look, ecoX: ex, ecoY: ey, mpc: mpc);
}

/// O bloco `procession` do `clima.json`.
ProcessionLook processionLookOf(Map<String, dynamic> j) {
  double d(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
  return ProcessionLook(
    minFigures: (j['min_figures'] as num?)?.toInt() ?? 12,
    maxFigures: (j['max_figures'] as num?)?.toInt() ?? 20,
    spacingM: d('spacing_m', 1.6),
    speedMps: d('speed_mps', 0.8),
    candleEveryM: d('candle_every_m', 6),
    candleS: d('candle_s', 1800),
    visibleM: d('visible_m', 120),
    snapM: d('snap_m', 80),
  );
}
