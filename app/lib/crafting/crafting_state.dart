/// O que o crafting da fase 1 guarda no save (bloco `crafting`, schema 10): recipientes (coletores), receitas conhecidas,
/// páginas de grimório, itens fixados na bolsa e o loadout. Dart puro.
library;

import 'quality.dart';

/// Onde está um recipiente: no cinto (enche com a condição em volta do jogador), na bolsa (guardado, não enche) ou
/// plantado num ponto do mapa (enche com a condição daquele lugar, mesmo com o jogador longe).
enum VesselPlace { belt, bag, planted }

/// Um recipiente (garrafa, frasco ou pote) com o que tem dentro. Vazio na bolsa ele é uma pilha comum
/// (`item.vessel.glass`); vira [Vessel] ao ir para o cinto ou ser plantado, e volta a ser pilha ao esvaziar na bolsa.
class Vessel {
  Vessel({
    required this.uid,
    required this.kind,
    required this.place,
    this.content,
    this.quality = Quality.common,
    this.filledUtc = 0,
    this.progressS = 0,
    this.progressRule,
    this.lat = 0,
    this.lon = 0,
    this.plantedUtc = 0,
    this.checkedUtc = 0,
    this.notified = false,
  });

  factory Vessel.fromJson(Map<String, dynamic> j) => Vessel(
        uid: j['uid'] as int,
        kind: j['kind'] as String,
        place: VesselPlace.values.byName(j['place'] as String),
        content: j['content'] as String?,
        quality: Quality.byName(j['q'] as String?),
        filledUtc: (j['filled'] as int?) ?? 0,
        progressS: ((j['progress_s'] as num?) ?? 0).toDouble(),
        progressRule: j['rule'] as String?,
        lat: ((j['lat'] as num?) ?? 0).toDouble(),
        lon: ((j['lon'] as num?) ?? 0).toDouble(),
        plantedUtc: (j['planted'] as int?) ?? 0,
        checkedUtc: (j['checked'] as int?) ?? 0,
        notified: (j['notified'] as bool?) ?? false,
      );

  final int uid;

  /// O id do recipiente vazio (`item.vessel.glass`).
  final String kind;
  VesselPlace place;

  /// O id do que tem dentro (`item.rain_water`), ou `null` se vazio.
  String? content;
  Quality quality;

  /// Quando encheu (segundos UTC): a validade do perecível conta daqui.
  int filledUtc;

  /// No cinto: os segundos de condição já acumulados para a regra [progressRule].
  double progressS;
  String? progressRule;

  /// Plantado: o ponto e o instante do plantio.
  double lat;
  double lon;
  int plantedUtc;

  /// Plantado: até quando a condição já foi conferida (a conta segue daqui, sempre igual).
  int checkedUtc;

  /// A Patrulha já avisou que este plantado encheu.
  bool notified;

  bool get empty => content == null;

  void clear() {
    content = null;
    quality = Quality.common;
    filledUtc = 0;
    progressS = 0;
    progressRule = null;
    checkedUtc = plantedUtc;
    notified = false;
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'kind': kind,
        'place': place.name,
        if (content != null) 'content': content,
        if (quality != Quality.common) 'q': quality.name,
        if (filledUtc != 0) 'filled': filledUtc,
        if (progressS != 0) 'progress_s': progressS,
        if (progressRule != null) 'rule': progressRule,
        if (place == VesselPlace.planted) ...{'lat': lat, 'lon': lon, 'planted': plantedUtc, 'checked': checkedUtc},
        if (notified) 'notified': true,
      };
}

/// Os espaços do loadout (docs/GDD.md, "Regras da fase 1"). Não há espaço de gadget: o jogo ainda não tem gadget equipável.
/// A quest que ensina o crafting (0.24.1): desligada até a primeira Sucata, ligada enquanto há passo a fazer, feita.
enum CraftTutorial { off, on, done }

/// O item que abre a quest: o Caco de vidro, de que a Garrafa de vidro é feita (0.24.2; na 0.24.1 era a Sucata).
const kCraftTutorialTrigger = 'item.glass_shard';

enum LoadoutSlot {
  bag('Bolsa'),
  belt('Cinto de coletores'),
  grimoire('Grimório ativo'),
  amulet('Amuleto'),
  jewel1('Joia'),
  jewel2('Joia');

  const LoadoutSlot(this.label);

  final String label;

  /// O `kind` de item que o espaço aceita.
  String get kind => switch (this) { jewel1 || jewel2 => 'jewel', _ => name };
}

class CraftingState {
  CraftingState({
    List<Vessel>? vessels,
    Set<String>? known,
    Set<String>? pages,
    List<String>? pins,
    Map<LoadoutSlot, String>? equipped,
    Map<LoadoutSlot, String>? looks,
    Set<LoadoutSlot>? hidden,
    this.nextUid = 1,
    this.tutorial = CraftTutorial.off,
    this.tutorialSteps = 0,
    this.gift = false,
  })  : vessels = vessels ?? [],
        known = known ?? {},
        pages = pages ?? {},
        pins = pins ?? [],
        equipped = equipped ?? {},
        looks = looks ?? {},
        hidden = hidden ?? {};

  factory CraftingState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return CraftingState();
    Map<LoadoutSlot, String> slots(Object? m) => {
          for (final e in ((m as Map<String, dynamic>?) ?? const {}).entries)
            if (LoadoutSlot.values.any((s) => s.name == e.key)) LoadoutSlot.values.byName(e.key): e.value as String,
        };
    return CraftingState(
      vessels: [for (final v in (j['vessels'] as List<dynamic>?) ?? const []) Vessel.fromJson(v as Map<String, dynamic>)],
      known: {...((j['known'] as List<dynamic>?) ?? const []).cast<String>()},
      pages: {...((j['pages'] as List<dynamic>?) ?? const []).cast<String>()},
      pins: [...((j['pins'] as List<dynamic>?) ?? const []).cast<String>()],
      equipped: slots(j['equipped']),
      looks: slots(j['looks']),
      hidden: {for (final s in ((j['hidden'] as List<dynamic>?) ?? const []).cast<String>()) if (LoadoutSlot.values.any((x) => x.name == s)) LoadoutSlot.values.byName(s)},
      nextUid: (j['next_uid'] as int?) ?? 1,
      tutorial: CraftTutorial.values.byName((j['tutorial'] as String?) ?? 'off'),
      tutorialSteps: (j['tutorial_steps'] as int?) ?? 0,
      gift: (j['gift'] as bool?) ?? false,
    );
  }

  final List<Vessel> vessels;

  /// Receitas que o jogador conhece (descobertas, de página ou de começo).
  final Set<String> known;

  /// Páginas de grimório recebidas.
  final Set<String> pages;

  /// Ids fixados no topo da bolsa.
  final List<String> pins;

  /// Item equipado em cada espaço (a chave da pilha, com a qualidade).
  final Map<LoadoutSlot, String> equipped;

  /// Aparência: a cara de outro item no espaço (o efeito continua o do equipado).
  final Map<LoadoutSlot, String> looks;

  /// Espaços que não aparecem no personagem.
  final Set<LoadoutSlot> hidden;
  int nextUid;

  /// A quest do crafting, quantos passos dela o mentor já comentou e se ele já deu a primeira garrafa.
  CraftTutorial tutorial;
  int tutorialSteps;
  bool gift;

  Iterable<Vessel> at(VesselPlace p) => vessels.where((v) => v.place == p);

  Map<String, dynamic> toJson() => {
        'vessels': [for (final v in vessels) v.toJson()],
        'known': [...known]..sort(),
        'pages': [...pages]..sort(),
        'pins': pins,
        'equipped': {for (final e in equipped.entries) e.key.name: e.value},
        'looks': {for (final e in looks.entries) e.key.name: e.value},
        'hidden': [for (final s in hidden) s.name],
        'next_uid': nextUid,
        'tutorial': tutorial.name,
        'tutorial_steps': tutorialSteps,
        'gift': gift,
      };
}
