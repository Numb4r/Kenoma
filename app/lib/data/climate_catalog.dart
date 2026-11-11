/// O lado visual do clima (`assets/data/clima.json`): nome, linha do HUD, ícone, camadas de desenho e o visual de cada
/// peça. Não muda o mundo (o que muda está no bloco `climate` da época), então pode ser ajustado sem época nova. Dart puro.
library;

import '../core/weather.dart';
import '../world/creature_wind.dart' show CreatureWindBalance;

int _color(Object? hex, [int fallback = 0xFFE8E4F4]) {
  if (hex is! String || !hex.startsWith('#')) return fallback;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}

/// Uma camada de desenho. O código conhece os tipos ([kind]); os números vêm do dado, com padrão para o que faltar.
class ClimateLayer {
  const ClimateLayer(this.kind, this.raw);

  final String kind;
  final Map<String, dynamic> raw;

  double val(String key, [double fallback = 0]) => (raw[key] as num?)?.toDouble() ?? fallback;
  int count(String key, [int fallback = 0]) => (raw[key] as num?)?.toInt() ?? fallback;
  bool flag(String key) => raw[key] == true;
  String? str(String key) => raw[key] as String?;
  int color([String key = 'color']) => _color(raw[key]);
  List<int> get colors => [for (final c in (raw['colors'] as List<dynamic>?) ?? const []) _color(c)];

  /// Faixa `[a, b]` do dado (velocidade das partículas, por exemplo).
  (double, double) range(String key, (double, double) fallback) {
    final l = raw[key];
    if (l is List && l.length == 2) return ((l[0] as num).toDouble(), (l[1] as num).toDouble());
    if (l is num) return (l.toDouble(), l.toDouble());
    return fallback;
  }

  /// A camada só aparece nestas horas locais (`[início, fim)`), se o dado pedir.
  bool showsAtHour(int hour) {
    final h = raw['local_hours'];
    if (h is! List || h.length != 2) return true;
    final a = (h[0] as num).toInt(), b = (h[1] as num).toInt();
    return a <= b ? hour >= a && hour < b : hour >= a || hour < b;
  }
}

class ClimateInfo {
  const ClimateInfo({required this.id, required this.name, required this.base, required this.hud, this.icon = const [], this.layers = const [], this.ground = const [], this.notice, this.outfit, this.windForce = 0});

  factory ClimateInfo.fromJson(String id, Map<String, dynamic> j) => ClimateInfo(
        id: id,
        name: j['name'] as String,
        base: Weather.parse(j['base'] as String?),
        hud: j['hud'] as String? ?? j['name'] as String,
        icon: (j['icon'] as List<dynamic>?)?.cast<String>() ?? const [],
        layers: [for (final l in (j['layers'] as List<dynamic>?) ?? const []) ClimateLayer((l as Map<String, dynamic>)['layer'] as String, l)],
        ground: [for (final l in (j['ground'] as List<dynamic>?) ?? const []) ClimateLayer((l as Map<String, dynamic>)['kind'] as String, l)],
        notice: j['notice'] as String?,
        outfit: j['outfit'] as String?,
        windForce: (j['wind_force'] as num?)?.toDouble() ?? 0,
      );

  /// Sem o `clima.json` (testes antigos): os quatro estados do modelo antigo.
  factory ClimateInfo.legacy(Weather w) => ClimateInfo(id: w.id, name: w.label, base: w, hud: w.label, icon: switch (w) {
        Weather.clear => const ['sun'],
        Weather.cloudy => const ['cloud'],
        Weather.rain => const ['cloud_dark', 'drops'],
        Weather.storm => const ['cloud_dark', 'bolt'],
      });

  final String id;
  final String name;

  /// O estado do modelo de quatro estados mais parecido (rituais, épocas até a 5).
  final Weather base;

  /// A linha que o toque no ícone mostra ("Tempestade: Elétricos mais comuns").
  final String hud;
  final List<String> icon;

  /// A camada da tela: só o que cai do céu ou cobre a vista (partículas, tom, véu, clarão).
  final List<ClimateLayer> layers;

  /// A camada do mapa que é só desenho (`climate_ground.dart`): cobertura das ruas, decoração presa ao chão, faixas, pares de
  /// sombra. Gira, move e dá zoom com o mapa, em posições do hash da seed e do lugar.
  final List<ClimateLayer> ground;

  /// Aviso que aparece uma vez quando o clima começa a ser visto (o Familiar avisa que não é neve).
  final String? notice;

  /// Quanto o que este clima deixa no chão leva para se formar e para sumir depois que ele acaba (o maior `grow_s` e
  /// `fade_s` das camadas do mapa; sem eles, 30 min e 1 h). Só desenho e a fase que o debug mostra.
  double get formS => _most('grow_s', 1800);
  double get fadeS => _most('fade_s', 3600);

  double _most(String key, double fallback) {
    final m = ground.fold(0.0, (a, l) => l.val(key) > a ? l.val(key) : a);
    return m > 0 ? m : fallback;
  }

  /// O que os passantes fantasmas vestem (`rain`, `cold`, `heat`, `mask`: `veil_traffic.dart`, `ghostOutfit`). Só desenho.
  final String? outfit;

  /// A força do vento nas criaturas do mapa, de 0 a 1 (Vento, Vendaval, Tornado, Furacão): inclinam, balançam e os leves são
  /// empurrados (`world/creature_wind.dart`). Só desenho.
  final double windForce;

  /// Quantas partículas este clima desenha no máximo (soma das camadas): o limite fixo por estado.
  int get maxParticles => layers.where((l) => l.kind == 'particles').fold(0, (a, l) => a + l.count('count'));
}

/// O visual de uma peça (raio, poça, redemoinho...): o estilo que o código conhece e as cores.
class PieceVisual {
  const PieceVisual({
    required this.style,
    required this.color,
    required this.glow,
    required this.alpha,
    required this.flash,
    this.mark,
    this.markS = 0,
    this.glowS = 0,
    this.shake = false,
    this.reflect = false,
    this.prism = false,
    this.trail = false,
    this.growS = 20,
    this.fadeS = 20,
  });

  factory PieceVisual.fromJson(Map<String, dynamic> j) => PieceVisual(
        style: j['style'] as String,
        color: _color(j['color']),
        glow: _color(j['glow'], _color(j['color'])),
        alpha: (j['alpha'] as num?)?.toDouble() ?? 0.4,
        flash: j['flash'] as bool? ?? false,
        mark: j['mark'] as String?,
        markS: (j['mark_s'] as num?)?.toDouble() ?? 0,
        glowS: (j['glow_s'] as num?)?.toDouble() ?? 0,
        shake: j['shake'] as bool? ?? false,
        reflect: j['reflect'] as bool? ?? false,
        prism: j['prism'] as bool? ?? false,
        trail: j['trail'] as bool? ?? false,
        growS: (j['grow_s'] as num?)?.toDouble() ?? 20,
        fadeS: (j['fade_s'] as num?)?.toDouble() ?? 20,
      );

  final String style;
  final int color;
  final int glow;
  final double alpha;
  final bool flash;

  /// A marca que o impacto deixa no chão (`burn`, `burn_violet`, `crater`, `ember`), por quanto tempo e quanto dela brilha.
  final String? mark;
  final double markS;
  final double glowS;

  /// O impacto treme a tela de leve (o meteoro).
  final bool shake;

  /// A poça reflete o céu (e, com [prism], em cores).
  final bool reflect;
  final bool prism;

  /// A zona que anda deixa um rastro no chão por onde passou (funil, Procissão, redemoinho).
  final bool trail;

  /// A zona se forma em [growS] segundos desde o começo e some nos [fadeS] antes do fim (só desenho).
  final double growS, fadeS;

  static const fallback = PieceVisual(style: 'zone', color: 0xFF9B7BFF, glow: 0xFF9B7BFF, alpha: 0.25, flash: false);
}

/// A marca de quem nasce de uma peça (`charged`): o nome e a paleta. Sem aviso: o Eco só aparece no mapa.
class ClimateTag {
  const ClimateTag({required this.name, required this.tint});

  final String name;
  final int tint;
}

class ClimateCatalog {
  const ClimateCatalog({this.climates = const {}, this.pieces = const {}, this.tags = const {}, this.events = const {}, this.reasons = const {}, this.rainbowArc = const {}, this.procession = const {}, this.calendarPending = const []});

  factory ClimateCatalog.fromJson(Map<String, dynamic>? j) => j == null
      ? const ClimateCatalog()
      : ClimateCatalog(
          climates: {for (final e in (j['climates'] as Map<String, dynamic>).entries) e.key: ClimateInfo.fromJson(e.key, e.value as Map<String, dynamic>)},
          pieces: {for (final e in ((j['pieces'] as Map<String, dynamic>?) ?? const {}).entries) e.key: PieceVisual.fromJson(e.value as Map<String, dynamic>)},
          tags: {
            for (final e in ((j['tags'] as Map<String, dynamic>?) ?? const {}).entries)
              e.key: ClimateTag(name: (e.value as Map<String, dynamic>)['name'] as String, tint: _color(e.value['tint'])),
          },
          events: {
            for (final e in ((j['events'] as Map<String, dynamic>?) ?? const {}).entries)
              e.key: (name: (e.value as Map<String, dynamic>)['name'] as String, reason: e.value['reason'] as String),
          },
          reasons: {for (final e in ((j['reasons'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
          rainbowArc: (j['rainbow_arc'] as Map<String, dynamic>?) ?? const {},
          procession: (j['procession'] as Map<String, dynamic>?) ?? const {},
          calendarPending: [
            for (final e in ((j['calendar_pending'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>())
              (id: e['id'] as String, name: e['name'] as String, climates: (e['climates'] as List<dynamic>).cast<String>(), note: (e['note'] as String?) ?? 'Data a definir.'),
          ],
        );

  /// O último catálogo lido do app (o menu de debug lista os climas daqui).
  static ClimateCatalog? lastLoaded;

  final Map<String, ClimateInfo> climates;
  final Map<String, PieceVisual> pieces;
  final Map<String, ClimateTag> tags;

  /// O nome e a frase do motivo de cada evento que força clima (o app Céu), e as frases de quando não há evento (`season`,
  /// `debug`, `feed`).
  final Map<String, ({String name, String reason})> events;
  final Map<String, String> reasons;

  /// Eventos do calendário do Véu que já têm nome e climas, mas ainda não têm data (a Noite das Fendas): o app Céu lista,
  /// nada acontece no mundo. Quando a data sair, o evento entra no `calendar` de uma época nova e sai daqui.
  final List<({String id, String name, List<String> climates, String note})> calendarPending;

  /// O desenho do arco-íris de pé no mapa (época 8): raio, faixas, cores, opacidade e esmaecer (`rainbow_painter.dart`).
  final Map<String, dynamic> rainbowArc;

  /// Os números da fila da Procissão (figuras, espaço, velocidade, velas, alcance): só desenho.
  final Map<String, dynamic> procession;

  /// O visual do clima [id]. Id desconhecido: o estado antigo com esse id, ou Limpo.
  ClimateInfo of(String id) => climates[id] ?? ClimateInfo.legacy(Weather.parse(id));

  PieceVisual piece(String name) => pieces[name] ?? PieceVisual.fallback;
}

/// Números do clima que valem por aparelho (`balance.json`, bloco `climate`): quantas partículas, quanto dura o clarão, a
/// que distância o raio não aparece. Nada aqui muda o mundo.
class ClimateBalance {
  const ClimateBalance({
    this.particleCap = 260,
    this.pocketRate = 0.2,
    this.flashMs = 120,
    this.flashAlpha = 0.55,
    this.dimAlpha = 0.18,
    this.boltMs = 350,
    this.burnMarkS = 60,
    this.strikeMinPlayerM = 15,
    this.flashMaxM = 400,
    this.thunderMaxM = 1000,
    this.fallMs = 600,
    this.footprintEveryM = 3,
    this.footprintMax = 40,
    this.prismSearchM = 6000,
    this.creatureWind = const CreatureWindBalance(),
  });

  factory ClimateBalance.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ClimateBalance();
    double d(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    return ClimateBalance(
      particleCap: (j['particle_cap'] as num?)?.toInt() ?? 260,
      pocketRate: d('pocket_rate', 0.2),
      flashMs: d('flash_ms', 120),
      flashAlpha: d('flash_alpha', 0.55),
      dimAlpha: d('dim_alpha', 0.18),
      boltMs: d('bolt_ms', 350),
      burnMarkS: d('burn_mark_s', 60),
      strikeMinPlayerM: d('strike_min_player_m', 15),
      flashMaxM: d('flash_max_m', 400),
      thunderMaxM: d('thunder_max_m', 1000),
      fallMs: d('fall_ms', 600),
      footprintEveryM: d('footprint_every_m', 3),
      footprintMax: (j['footprint_max'] as num?)?.toInt() ?? 40,
      prismSearchM: d('prism_search_m', 6000),
      creatureWind: CreatureWindBalance.fromJson(j['creature_wind'] as Map<String, dynamic>?),
    );
  }


  /// Teto de partículas somando as camadas, e a fração delas no modo bolso.
  final int particleCap;
  final double pocketRate;

  /// O clarão do raio: duração e opacidade; com "reduzir clarões", um escurecimento de [dimAlpha] no lugar.
  final double flashMs;
  final double flashAlpha;
  final double dimAlpha;

  /// O traço do raio, a marca queimada e a queda de um coletável do céu.
  final double boltMs;
  final double burnMarkS;
  final double fallMs;

  /// O raio a menos disto do jogador não aparece para ele (o ponto é o do mundo, igual para todos).
  final double strikeMinPlayerM;

  /// Até onde o clarão clareia a tela e até onde se ouve o trovão.
  final double flashMaxM;
  final double thunderMaxM;

  /// Pegadas na neve: uma a cada [footprintEveryM] metros, no máximo [footprintMax].
  final double footprintEveryM;
  final int footprintMax;

  /// Até onde o Prisma de orvalho procura um arco-íris ativo (o do aparelho: decide só se o prisma se gasta).
  final double prismSearchM;

  /// O vento nas criaturas do mapa (`creature_wind`): inclinação, empurrão dos leves e partículas soltas. Só desenho.
  final CreatureWindBalance creatureWind;
}
