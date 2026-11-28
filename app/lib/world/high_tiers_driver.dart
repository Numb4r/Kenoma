/// O que o mapa do jogo usa das etapas altas (0.27.0): as Entidades soltas da região do jogador (guardadas por mês), o rumor
/// delas no fórum, o Arquétipo no auge do evento e os pedidos do debug. Dart puro: o mapa passa a condição do ritual, a
/// região e os eventos; o sorteio está em `high_tiers.dart`.
library;

import '../core/fnv.dart';
import '../core/high_tiers_model.dart';
import 'high_tiers.dart';
import 'npc_data.dart' show fillGaps;
import 'spawn_field.dart' show WorldSpawn;

/// Um post de rumor no fórum: quem escreve, o texto pronto e a Entidade de que ele fala.
typedef ForumRumor = ({String user, String text, MajorSighting sighting});

/// Os textos do rumor (`forum.json`, `rumors`): os posts com lacunas e a pista de cada família.
class RumorTexts {
  const RumorTexts({this.posts = const [], this.signals = const {}});

  factory RumorTexts.fromJson(Map<String, dynamic>? j) => j == null
      ? const RumorTexts()
      : RumorTexts(
          posts: [for (final p in (j['posts'] as List<dynamic>? ?? const [])) (user: (p as Map<String, dynamic>)['user'] as String, text: p['text'] as String)],
          signals: {for (final e in ((j['signals'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
        );

  final List<({String user, String text})> posts;
  final Map<String, String> signals;
}

class HighTiersDriver {
  HighTiersDriver({
    required this.seed,
    required this.epochId,
    required this.model,
    required this.families,
    required this.holds,
    required this.regionAt,
    required this.eventsAt,
    this.bairroAt,
    this.rumors = const RumorTexts(),
    this.sliced = false,
    this.pause,
    this.sliceUs = 4000,
  });

  /// O tempo de cada fatia da busca aos poucos: passou disso, espera a próxima [pause] (o próximo quadro, no mapa).
  final int sliceUs;

  /// O que esperar entre duas fatias (o mapa: o fim do quadro). Sem ele, uma volta do laço de eventos.
  final Future<void> Function()? pause;

  /// O mapa: a busca do mês corre aos poucos, em fatias de até [sliceUs]; até acabar, vale o que já achou.
  final bool sliced;
  final _partial = <(String, int), List<MajorSighting>>{};

  final int seed;
  final int epochId;
  final HighTiersModel model;
  final List<String> families;
  final FamilyConditionAt holds;

  /// A região da célula z20 e o retângulo dela, ou `null` fora de todas.
  final ({String id, int x0, int y0, int w, int h})? Function(int cx20, int cy20) regionAt;

  /// Os eventos (e o clima da janela) que valem na célula z20 em [t]: id, começo e fim da ocorrência.
  final List<({String id, int start, int end})> Function(int cx20, int cy20, int t) eventsAt;

  /// O nome do bairro do ponto (células z21 fracionárias) na região, para o rumor.
  final String? Function(String region, double x21, double y21)? bairroAt;
  final RumorTexts rumors;

  final _months = <(String, int), List<MajorSighting>>{};

  /// As do debug: valem por cima do sorteio.
  final forced = <MajorSighting>[];
  final forcedArchetypes = <ArchetypeSighting>[];

  /// O Arquétipo à vista: quando cada um se mostrou pela primeira vez (o relógio dele começa quando é visto).
  final _shownAt = <int, int>{};

  /// As Entidades da região de ([cx20], [cy20]) neste mês e no próximo (o rumor do começo do mês seguinte sai antes).
  List<MajorSighting> sightingsAround(int cx20, int cy20, int t) {
    final r = regionAt(cx20, cy20);
    final out = <MajorSighting>[for (final s in forced) s];
    if (r == null) return out;
    final area = (x0: r.x0, y0: r.y0, w: r.w, h: r.h);
    for (final month in [monthBounds(t).$1, monthBounds(t).$2]) {
      final key = (r.id, month);
      final done = _months[key];
      if (done != null) {
        out.addAll(done);
      } else if (!sliced) {
        out.addAll(_months[key] = majorSightings(seed: seed, epochId: epochId, m: model, region: r.id, area: area, families: families, tUtc: month, holds: holds));
      } else {
        out.addAll(_partial[key] ?? _fill(key, majorSightingSteps(seed: seed, epochId: epochId, m: model, region: r.id, area: area, families: families, tUtc: month, holds: holds)));
      }
    }
    return out;
  }

  /// Começa a busca aos poucos e devolve a lista que ela vai enchendo.
  List<MajorSighting> _fill((String, int) key, Iterable<MajorSighting?> steps) {
    final partial = _partial[key] = <MajorSighting>[];
    () async {
      final sw = Stopwatch()..start();
      for (final s in steps) {
        if (s != null) partial.add(s);
        if (sw.elapsedMicroseconds < sliceUs) continue;
        await (pause?.call() ?? Future<void>.delayed(Duration.zero));
        sw.reset();
      }
      _months[key] = [...partial]..sort((a, b) => a.startUtc - b.startUtc);
      _partial.remove(key);
    }();
    return partial;
  }

  /// As Entidades soltas agora, como spawn do mapa.
  List<MajorSighting> activeMajors(int cx20, int cy20, int t) => [for (final s in sightingsAround(cx20, cy20, t)) if (s.activeAt(t)) s];

  /// Os rumores no ar agora, um por Entidade, do mais novo para o mais velho. O post e o usuário saem do hash da Entidade.
  List<ForumRumor> rumorsAt(int cx20, int cy20, int t, {Duration? offset}) {
    if (rumors.posts.isEmpty) return const [];
    final live = [for (final s in sightingsAround(cx20, cy20, t)) if (s.rumorAt(t)) s]..sort((a, b) => b.rumorUtc - a.rumorUtc);
    return [
      for (final s in live)
        () {
          final p = rumors.posts[hashMod(fnv1a64([s.uid, 7]), rumors.posts.length)];
          final text = fillGaps(p.text, {
            'bairro': bairroAt?.call(s.region, s.x21, s.y21) ?? 'um bairro daqui',
            'hora': hourBand(s.startUtc, offset: offset),
            'sinal': rumors.signals[s.family] ?? 'coisa estranha',
          });
          return (user: p.user, text: text, sighting: s);
        }(),
    ];
  }

  /// Os Arquétipos que o jogador vê agora: no auge de um evento da família, na célula z17 dele ou numa vizinha, e só por
  /// [HighTiersModel.archetypeStayS] depois de aparecer à vista ([visible]). [gone] recebe cada um que acabou de sumir.
  List<ArchetypeSighting> archetypesAt(int cx20, int cy20, int t, {required bool Function(ArchetypeSighting a) visible, void Function(ArchetypeSighting a)? gone}) {
    final cx17 = cx20 >>> 3, cy17 = cy20 >>> 3;
    final candidates = <ArchetypeSighting>[
      for (final a in forcedArchetypes) a,
      for (final e in eventsAt(cx20, cy20, t))
        for (var dy = -1; dy <= 1; dy++)
          for (var dx = -1; dx <= 1; dx++)
            ?archetypeIn(seed: seed, epochId: epochId, m: model, eventId: e.id, eventStart: e.start, eventEnd: e.end, cx17: cx17 + dx, cy17: cy17 + dy),
    ];
    final out = <ArchetypeSighting>[];
    for (final a in candidates) {
      if (!a.inPeak(t)) continue;
      final first = _shownAt[a.uid];
      if (first == null) {
        if (!visible(a)) continue;
        _shownAt[a.uid] = t;
        out.add(a);
      } else if (t - first < model.archetypeStayS) {
        out.add(a);
      } else if (_shownAt[a.uid] != -1) {
        _shownAt[a.uid] = -1; // já sumiu: não volta nesta sessão
        gone?.call(a);
      }
    }
    return out;
  }

  /// Já se mostrou e sumiu (ou foi tocado): não volta.
  void dismiss(int uid) => _shownAt[uid] = -1;

  /// Debug: a Entidade da [family] solta agora em ([x21], [y21]), pela janela inteira; o rumor dela já está no ar.
  MajorSighting forceMajor(String family, String region, double x21, double y21, int t) {
    final s = MajorSighting(
        family: family, region: region, cx20: x21.floor() >>> 1, cy20: y21.floor() >>> 1, x21: x21, y21: y21, startUtc: t, endUtc: t + model.majorWindowS, rumorUtc: t - model.majorRumorLeadS, uid: fnv1a64([t, x21.round(), y21.round(), 0x4d4a44]) | 1);
    forced.add(s);
    return s;
  }

  /// Debug: o rumor de uma Entidade da [family] que vai aparecer em ([x21], [y21]) daqui a [HighTiersModel.majorRumorLeadS].
  MajorSighting forceRumor(String family, String region, double x21, double y21, int t) {
    final start = t + model.majorRumorLeadS;
    final s = MajorSighting(
        family: family, region: region, cx20: x21.floor() >>> 1, cy20: y21.floor() >>> 1, x21: x21, y21: y21, startUtc: start, endUtc: start + model.majorWindowS, rumorUtc: t, uid: fnv1a64([t, x21.round(), y21.round(), 0x4d4a52]) | 1);
    forced.add(s);
    return s;
  }

  /// Debug: o Arquétipo da [family] em ([x21], [y21]) agora, como se fosse o auge.
  ArchetypeSighting forceArchetype(String family, double x21, double y21, int t) {
    final a = ArchetypeSighting(
        family: family, eventId: model.archetypeEvents[family] ?? 'debug', cx17: x21.floor() >>> 4, cy17: y21.floor() >>> 4, x21: x21, y21: y21, peakFrom: t, peakTo: t + 600, uid: fnv1a64([t, x21.round(), y21.round(), 0x415243]) | 1);
    forcedArchetypes.add(a);
    return a;
  }

  /// Os spawns de agora: as Entidades na janela e os Arquétipos à vista.
  /// [majors] falso: só as forçadas pelo debug (o mapa espera uns segundos depois de abrir para começar a busca do mês).
  List<WorldSpawn> spawnsAt(int cx20, int cy20, int t, {required bool Function(ArchetypeSighting a) visible, void Function(ArchetypeSighting a)? gone, bool majors = true}) => [
        for (final s in majors ? activeMajors(cx20, cy20, t) : [for (final f in forced) if (f.activeAt(t)) f]) s.spawn(model.majorLevel),
        for (final a in archetypesAt(cx20, cy20, t, visible: visible, gone: gone)) a.spawn(),
      ];
}
