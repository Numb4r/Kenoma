/// O que o jogador tem e fez: nível e XP, inventário, coleção, Círculo, bestiário, marcações e o registro do
/// que já foi coletado, capturado ou fugiu. Dart puro. Tudo vai para o save (schema em [saveSchemaVersion]).
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/seed.dart';
import '../crafting/crafting_state.dart';
import '../crafting/quality.dart';
import '../save/founder.dart';
import '../story/chat_state.dart' show ChatEntry;
import '../story/forum_data.dart';
import '../story/mentor_script.dart';
import '../story/story_state.dart';
import '../world/map_touch.dart' show TouchState;
import 'npc_state.dart';
import 'bestiary.dart';
import 'conjurer.dart';
import 'conjurer_balance.dart';
import 'home.dart';
import 'mark.dart';
import 'personal_build.dart';
import 'progress_balance.dart';
import 'progression.dart';

/// O registro guarda só as últimas 48 horas (docs/fase0-spec.md, seção 3).
const int registryKeepSeconds = 48 * 3600;

const int saveSchemaVersion = 16;

/// 0.26.4: a célula z21 em que o mapa estava da última vez. Só no save deste aparelho: o backup e a exportação tiram a chave
/// (`exportBackup`), o QR do grupo só leva o código do grupo, e nada a envia. Na abertura, o mapa prepara aquela área.
const String kLastMapCellKey = 'map_last_cell';

/// A chave das células z17 visitadas no save (schema 6).
const String kVisitedCellsKey = 'celulas_visitadas';

/// Uma criatura capturada. O uid é o do spawn de onde ela veio.
class CreatureInstance {
  const CreatureInstance({
    required this.uid,
    required this.speciesId,
    required this.level,
    required this.capturedUtc,
    this.xp = 0,
    this.variant,
    this.shiny = false,
    this.traits = const [],
    this.debug = false,
    this.personal = false,
    this.hidden = false,
  });

  /// Cópia com [level] e [xp] novos.
  CreatureInstance advanced({required int level, required int xp}) => CreatureInstance(
      uid: uid, speciesId: speciesId, level: level, capturedUtc: capturedUtc, xp: xp, variant: variant, shiny: shiny, traits: traits, debug: debug, personal: personal, hidden: hidden);

  factory CreatureInstance.fromJson(Map<String, dynamic> j) => CreatureInstance(
        uid: j['uid'] as String,
        speciesId: j['species'] as String,
        level: j['level'] as int,
        xp: (j['xp'] as int?) ?? 0,
        capturedUtc: j['captured_utc'] as int,
        variant: j['variant'] as String?,
        shiny: (j['shiny'] as bool?) ?? false,
        traits: [for (final t in (j['traits'] as List<dynamic>?) ?? const []) t as String],
        debug: (j['debug'] as bool?) ?? false,
        personal: (j['personal'] as bool?) ?? false,
        hidden: (j['hidden'] as bool?) ?? false,
      );

  /// Uid do spawn, em texto (o inteiro de 64 bits com sinal, em decimal).
  final String uid;
  final String speciesId;
  final int level;
  final int xp;
  final int capturedUtc;

  /// A chave do bioma da variante (`urban`...), ou `null`; e se é Brilhante.
  final String? variant;
  final bool shiny;

  /// Traços herdados (só os Espíritos, vindos dos Ecos da fusão): chaves de variante (`urban`...) ou `shiny`.
  final List<String> traits;

  /// Nasceu pelo "Criar criatura" do menu de debug: não conta para o bestiário nem para as estatísticas.
  final bool debug;

  /// De onde o Eco veio: da camada pessoal de spawn (só deste jogador) e se era Oculto. O Bit rende Essência a mais na
  /// destilação dos que eram Ocultos.
  final bool personal;
  final bool hidden;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'species': speciesId,
        'level': level,
        'xp': xp,
        'captured_utc': capturedUtc,
        if (variant != null) 'variant': variant,
        if (shiny) 'shiny': true,
        if (traits.isNotEmpty) 'traits': traits,
        if (debug) 'debug': true,
        if (personal) 'personal': true,
        if (hidden) 'hidden': true,
      };
}

class GameState extends ChangeNotifier {
  GameState({
    required this.groupCode,
    required this.balance,
    Map<String, int>? inventory,
    List<CreatureInstance>? collection,
    Map<String, int>? collected,
    PlayerProgress? progress,
    this.levelOverride,
    List<String>? circle,
    Map<String, BestiaryEntry>? bestiary,
    List<Mark>? marks,
    this.founder,
    this.createdUtc,
    StoryState? story,
    Iterable<(int, int)>? visitedCells,
    ConjurerState? conjurer,
    CraftingState? crafting,
    TouchState? touches,
    NpcState? npcs,
    this.radarLastUtc = 0,
    Map<String, int>? hiddenRevealed,
    Map<String, dynamic>? settings,
    this.lastSeenUtc = 0,
    List<String>? pins,
    List<BuildEntry>? builds,
    HomeState? home,
    Map<String, dynamic>? extra,
  })  : inventory = {...?inventory},
        collection = [...?collection],
        _collected = {...?collected},
        progress = progress ?? PlayerProgress(balance: balance),
        circle = [...?circle],
        bestiary = {...?bestiary},
        marks = [...?marks],
        settings = {...?settings},
        story = story ?? StoryState(),
        _visited = {...?visitedCells},
        conjurer = conjurer ?? ConjurerState(),
        crafting = crafting ?? CraftingState(),
        touches = touches ?? TouchState(),
        npcs = npcs ?? NpcState(),
        hiddenRevealed = {...?hiddenRevealed},
        pins = [...?pins],
        builds = [...?builds],
        home = home ?? HomeState(),
        _extra = {...?extra};

  /// Jogo novo: seed nova e o inventário inicial do `balance.json`.
  factory GameState.fresh({required String groupCode, required Map<String, int> startInventory, required ProgressBalance balance}) =>
      GameState(groupCode: groupCode, balance: balance, inventory: startInventory);

  factory GameState.fromJson(Map<String, dynamic> j, ProgressBalance balance) {
    const known = {
      'schema_version', 'group_code', 'player', 'level_override', 'inventory', 'collection', 'collected', 'circle', 'bestiary', 'bestiary_pins', 'personal_builds', 'marks', 'saved_utc',
      'founder', 'created_utc', 'last_seen_utc', 'app_version', 'epoch', 'settings', 'story', kVisitedCellsKey, 'radar', 'conjurer', 'crafting', 'touches', 'npcs',
      kLastMapCellKey, 'home', kHomeCellKey,
    };
    final progress = PlayerProgress.fromJson(j['player'] as Map<String, dynamic>?, balance)..settleBanked();
    final state = GameState(
      groupCode: j['group_code'] as String,
      balance: balance,
      progress: progress,
      levelOverride: j['level_override'] as int?,
      inventory: {for (final e in ((j['inventory'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      collection: [for (final c in (j['collection'] as List<dynamic>?) ?? const []) CreatureInstance.fromJson(c as Map<String, dynamic>)],
      collected: {for (final e in ((j['collected'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
      circle: [for (final u in (j['circle'] as List<dynamic>?) ?? const []) u as String],
      bestiary: {
        for (final e in ((j['bestiary'] as Map<String, dynamic>?) ?? const {}).entries) e.key: BestiaryEntry.fromJson(e.value as Map<String, dynamic>),
      },
      marks: [for (final m in (j['marks'] as List<dynamic>?) ?? const []) Mark.fromJson(m as Map<String, dynamic>)],
      pins: [for (final p in (j['bestiary_pins'] as List<dynamic>?) ?? const []) p as String],
      builds: [for (final b in (j['personal_builds'] as List<dynamic>?) ?? const []) BuildEntry.fromJson(b as Map<String, dynamic>)],
      founder: j['founder'] == null ? null : Founder.fromJson(j['founder'] as Map<String, dynamic>),
      createdUtc: j['created_utc'] as int?,
      story: StoryState.fromJson(j['story'] as Map<String, dynamic>?),
      visitedCells: [for (final c in (j[kVisitedCellsKey] as List<dynamic>?) ?? const []) ((c as List<dynamic>)[0] as int, c[1] as int)],
      conjurer: ConjurerState.fromJson(j['conjurer'] as Map<String, dynamic>?),
      crafting: CraftingState.fromJson(j['crafting'] as Map<String, dynamic>?),
      touches: TouchState.fromJson(j['touches'] as Map<String, dynamic>?),
      npcs: NpcState.fromJson(j['npcs'] as Map<String, dynamic>?),
      radarLastUtc: ((j['radar'] as Map<String, dynamic>?)?['last_utc'] as int?) ?? 0,
      hiddenRevealed: {
        for (final e in (((j['radar'] as Map<String, dynamic>?)?['revealed'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int,
      },
      lastSeenUtc: (j['last_seen_utc'] as int?) ?? 0,
      settings: {...?(j['settings'] as Map<String, dynamic>?)},
      home: HomeState.fromJson(j['home'] as Map<String, dynamic>?, cell: switch (j[kHomeCellKey]) { [final int x, final int y] => (x, y), _ => null }),
      // Campos que esta versão não conhece são preservados (spec, seção 10).
      extra: {for (final e in j.entries) if (!known.contains(e.key)) e.key: e.value},
    );
    // Um ponto de talento por nível já subido: saves antigos (e o XP guardado que o teto novo libera) entram com o que o nível pede.
    final owed = (progress.level - 1) * state.cb.talentPerLevel;
    if (state.conjurer.talentEarned < owed) state.conjurer.talentEarned = owed;
    for (var l = 2; l <= progress.level; l++) {
      state.story.events.putIfAbsent('level_$l', () => 1); // saves antigos: os níveis já subidos contam para o mentor
    }
    if (j[kLastMapCellKey] case [final int x, final int y]) state.lastMapCell = (x, y);
    return state;
  }

  /// O Conjurador já pode escolher a escola (nível 3 ou mais) e ainda não escolheu.
  bool get canChooseSchool => conjurer.school == null && playerLevel >= cb.schoolLevel;

  /// Escolhe a escola, de forma definitiva (a troca vem só no nível 30, numa fatia futura). `false` se não pode.
  bool chooseSchool(School school) {
    if (!canChooseSchool) return false;
    conjurer.school = school;
    recordEvent('school_chosen', school.id, 1);
    recordEvent('school_chosen_${school.id}', '', 1); // a fala do Familiar de cada escola
    notifyListeners();
    return true;
  }

  /// O mentor mandou os testes (a escola já é possível e eles ainda não foram oferecidos).
  void offerSchoolTests() {
    if (conjurer.testsOffered) return;
    conjurer.testsOffered = true;
    notifyListeners();
  }

  /// A nota (0 a 100) do jogador no teste da [school].
  void recordSchoolTest(School school, int score) {
    conjurer.testScores[school.id] = score.clamp(0, 100);
    notifyListeners();
  }

  /// Código do grupo: a seed do mundo vem dele.
  String groupCode;
  final ProgressBalance balance;
  final PlayerProgress progress;

  /// Nível forçado pelo menu de debug. `null`: vale o nível real.
  int? levelOverride;
  final Map<String, int> inventory;
  final List<CreatureInstance> collection;
  final Map<String, int> _collected;
  final Map<String, dynamic> _extra;

  /// Uids das criaturas ativas no Círculo, no máximo 3.
  final List<String> circle;
  final Map<String, BestiaryEntry> bestiary;

  /// As formas marcadas no Bestiário (ids de espécie ou de Fagulha), até [maxPins]. As espécies marcadas aparecem com
  /// destaque no mapa e no Radar dentro do alcance dele, e a Patrulha avisa.
  final List<String> pins;
  static const int maxPins = 3;

  bool isPinned(String id) => pins.contains(id);

  /// Marca ou desmarca [id]. `false` se já há [maxPins] marcadas (nada muda).
  bool togglePin(String id) {
    if (!pins.remove(id)) {
      if (pins.length >= maxPins) return false;
      pins.add(id);
    }
    notifyListeners();
    return true;
  }

  /// As builds do jogador pelo tempo, para a camada pessoal de spawn (`personal_build.dart`).
  final List<BuildEntry> builds;

  final List<Mark> marks;

  /// Registro de fundador (`player_id`, primeira versão e log de versões). `null` num jogo ainda sem registro.
  Founder? founder;

  /// 0.26.4: a célula z21 do mapa da última vez ([kLastMapCellKey]). Muda sem avisar ninguém: vai junto na próxima gravação.
  (int, int)? lastMapCell;

  /// Quando o jogo nasceu e o último instante em que o app esteve aberto (relógio que volta não passa dele).
  int? createdUtc;
  int lastSeenUtc;

  /// Versão do app e época de quando o save foi gravado (o cabeçalho da spec).
  String appVersion = '';
  int epochId = 0;

  /// Eventos de jogo, o chat com o mentor e as diárias do fórum.
  final StoryState story;

  /// As células z17 (~280 m) por onde o jogador passou de verdade (o simulador não conta). Sem nada visual: as expedições
  /// da fase 2 vão usar.
  final Set<(int, int)> _visited;

  Set<(int, int)> get visitedCells => Set.unmodifiable(_visited);

  /// Registra a célula z17 ([x], [y]) como visitada. `true` se era nova. Quem chama não passa o caminho do simulador.
  bool markVisited(int x, int y) {
    if (!_visited.add((x, y))) return false;
    notifyListeners();
    return true;
  }

  /// Escola, testes, talentos, pesquisa de rituais e contagens do Perfil.
  final ConjurerState conjurer;

  /// O crafting da fase 1: recipientes, receitas conhecidas, páginas, fixados e loadout.
  final CraftingState crafting;

  /// O mapa que responde ao toque (0.24.2): o dia e o que cada interação já rendeu nele.
  final TouchState touches;

  /// 0.24.5: as trocas do dia com os Outros Veilbreakers e a relação com os conhecidos.
  final NpcState npcs;

  /// 0.28.0: a Casa (lugar, Armazém, móveis e estações).
  final HomeState home;

  /// Os números do Conjurador do `balance.json`: desbloqueios, escolas, fusão.
  ConjurerBalance get cb => balance.conjurer;

  /// A última varredura do Radar (segundos UTC) e os Ocultos que ela revelou, `uid -> até quando`.
  int radarLastUtc;
  final Map<String, int> hiddenRevealed;

  /// O Radar varreu em [nowUtc] e revelou os Ocultos [uids] até [untilUtc].
  void recordSweep(int nowUtc, Iterable<int> uids, int untilUtc) {
    radarLastUtc = nowUtc;
    hiddenRevealed.removeWhere((_, until) => until <= nowUtc);
    for (final u in uids) {
      hiddenRevealed[uidKey(u)] = untilUtc;
    }
    notifyListeners();
  }

  /// O jogador chegou às distorções dos Ocultos [uids] em [nowUtc]: ficam à vista até [untilUtc].
  void revealHidden(Iterable<int> uids, int nowUtc, int untilUtc) {
    hiddenRevealed.removeWhere((_, until) => until <= nowUtc);
    for (final u in uids) {
      hiddenRevealed[uidKey(u)] = untilUtc;
    }
    notifyListeners();
  }

  /// Se o Oculto [uid] foi revelado por uma varredura e ainda está à vista em [nowUtc].
  bool isHiddenRevealed(int uid, int nowUtc) => (hiddenRevealed[uidKey(uid)] ?? 0) > nowUtc;

  /// Um aviso para o jogador (mensagem nova, pedido concluído). A tela do mapa o mostra.
  void Function(String message)? onNotice;

  /// Interruptores do jogador: `street_names` e `follow_heading`.
  final Map<String, dynamic> settings;

  int get seed => seedGlobal(groupCode);

  /// O nível que o jogo usa: o do debug, se houver, senão o real. Define o nível dos Ecos e a resistência.
  int get playerLevel => levelOverride ?? progress.level;

  /// Entra noutro grupo: a seed muda, então o registro de coletas e as marcações (que são do mundo antigo) saem.
  /// A coleção, o Círculo, o inventário e o nível ficam. `false` se o código é o mesmo.
  bool changeGroup(String code) {
    if (normalizeSeedCode(code) == normalizeSeedCode(groupCode)) return false;
    groupCode = formatGroupCode(code);
    _collected.clear();
    marks.clear();
    notifyListeners();
    return true;
  }

  /// Um evento de jogo aconteceu: conta para o tutorial do mentor e para as diárias do fórum. Avisa se algum
  /// pedido ficou pronto.
  void recordEvent(String kind, String key, int n) {
    if (n <= 0) return;
    story.events[kind] = story.count(kind) + n;
    for (final q in story.daily.record(kind, key, n)) {
      onNotice?.call('Pedido de ${q.user} pronto: entregue no Fórum');
    }
    notifyListeners();
  }

  /// Gera os pedidos de hoje se o dia virou. [today] é o dia local; [forum] e [epochId] vêm dos dados.
  void ensureDaily(ForumData forum, int epochId, int today) {
    final newDay = conjurer.markDay(today); // dias jogados, para o Perfil
    if (story.daily.ensure(today: today, seed: seed, epochId: epochId, level: playerLevel, forum: forum) || newDay) notifyListeners();
  }

  /// O nome do Conjurador (já limpo por `sanitizeName`); vazio volta a "Conjurador".
  void setPlayerName(String name) {
    if (conjurer.playerName == name) return;
    conjurer.playerName = name;
    notifyListeners();
  }

  /// Entrega o pedido do [slot]: XP e materiais. `false` se ainda não está pronto.
  bool claimDaily(int slot, int nowUtc) {
    final q = story.daily.atSlot(slot);
    if (q == null || !q.claimable) return false;
    q.claimed = true;
    for (final e in q.rewardItems.entries) {
      add(e.key, e.value);
    }
    gainXp(q.rewardXp, nowUtc);
    return true;
  }

  /// Troca o pedido do [slot] (um reroll por dia).
  bool rerollDaily(int slot, ForumData forum, int epochId) {
    final ok = story.daily.reroll(slot, seed: seed, epochId: epochId, level: playerLevel, forum: forum);
    if (ok) notifyListeners();
    return ok;
  }

  /// O jogador abriu o chat: tudo o que chegou está lido.
  void markChatRead() {
    if (story.chat.unread == 0) return;
    story.chat.markAllRead();
    notifyListeners();
  }

  /// Avança o relógio do tutorial em [dt] segundos de jogo. Devolve a mensagem do mentor que chegou, ou `null`.
  MentorMessage? tickChat(double dt, int nowUtc, MentorScript script) {
    final m = story.chat.tick(dt, nowUtc, script, story.count);
    final fam = story.chat.deliverFamiliar(nowUtc, script, story.count);
    final offered = _offerSchoolTests(nowUtc, script);
    final ev = story.chat.deliverEvents(nowUtc, script, story.count);
    for (final e in ev) {
      if (e.page != null) crafting.pages.add(e.page!);
    }
    if (m != null || offered || ev.any((e) => e.from == 'mentor')) onNotice?.call('Nova mensagem de ${script.contactName}');
    if (fam.isNotEmpty || ev.any((e) => e.from == 'familiar')) onNotice?.call('O Familiar tem algo a dizer');
    if (m != null || fam.isNotEmpty || offered || ev.isNotEmpty) notifyListeners();
    return m;
  }

  /// Entrega no chat a mensagem [id] (das `direct` do `mentor.json`) em [nowUtc], com os números de [vars]. Pode repetir.
  void deliverMessage(String id, int nowUtc, {Map<String, Object> vars = const {}}) {
    story.chat.delivered.add(ChatEntry(id: id, utc: nowUtc, vars: {for (final e in vars.entries) e.key: '${e.value}'}));
    onNotice?.call(id.startsWith('steps_') ? 'O Familiar tem algo a dizer' : 'Nova mensagem no Chat');
    notifyListeners();
  }

  /// No nível da escola, na primeira sessão em que os testes ainda não foram oferecidos, o mentor manda o convite. Uma vez só.
  bool _offerSchoolTests(int nowUtc, MentorScript script) {
    final msg = script.byId('school_tests');
    if (msg == null || conjurer.testsOffered || conjurer.school != null || playerLevel < cb.schoolLevel) return false;
    story.chat.delivered.add(ChatEntry(id: msg.id, utc: nowUtc));
    conjurer.testsOffered = true;
    return true;
  }

  /// Guarda um interruptor do jogador (`street_names`, `follow_heading`).
  void setSetting(String key, Object value) {
    if (settings[key] == value) return;
    settings[key] = value;
    notifyListeners();
  }

  bool setting(String key) => settings[key] == true;

  /// Um interruptor que vale [fallback] enquanto o jogador não mexeu nele.
  bool settingOr(String key, bool fallback) => settings[key] is bool ? settings[key] as bool : fallback;

  /// Avisa a interface e o save de uma mudança feita de fora (o crafting mexe em [crafting] direto).
  void changed() => notifyListeners();

  /// Quantos [itemId] há. Um id puro soma as três qualidades; uma chave com qualidade (`item.chalk@good`) conta só a pilha.
  int count(String itemId) => itemId.contains('@') ? inventory[itemId] ?? 0 : stackKeys(itemId).fold(0, (n, k) => n + (inventory[k] ?? 0));

  /// Quantos [itemId] há na qualidade [q].
  int countQ(String itemId, Quality q) => inventory[stackKey(itemId, q)] ?? 0;

  /// A melhor qualidade de [itemId] que há, ou `null`.
  Quality? bestQuality(String itemId) => Quality.values.reversed.where((q) => countQ(itemId, q) > 0).firstOrNull;

  /// Ganha XP de Conjurador em [nowUtc]. Devolve quantos níveis subiu.
  int gainXp(int raw, int nowUtc) {
    final up = progress.gain(raw, nowUtc);
    conjurer.talentEarned += up * cb.talentPerLevel;
    // Cada nível alcançado vira o evento `level_N`: o mentor liga mensagens a ele (a fusão, no `level_6`).
    for (var l = progress.level - up + 1; l <= progress.level; l++) {
      story.events['level_$l'] = 1;
    }
    notifyListeners();
    return up;
  }

  /// O limite da bolsa (0.24.1): quantos de [n] da pilha [key] cabem. Quem recusa avisa. Sem ele (testes), cabe tudo.
  int Function(String key, int n)? accept;

  /// Põe [n] [itemId] na pilha da qualidade [q] (uma chave com qualidade já diz qual pilha). Devolve quantos entraram: a
  /// bolsa nunca passa do limite ([accept]).
  int add(String itemId, int n, {Quality q = Quality.common}) {
    if (n <= 0) return 0;
    final key = itemId.contains('@') ? itemId : stackKey(itemId, q);
    n = accept?.call(key, n) ?? n;
    if (n <= 0) return 0;
    inventory[key] = (inventory[key] ?? 0) + n;
    // A Fagulha coletada entra no Bestiário (a primeira forma de cada família).
    final id = parseStack(key).id;
    if (id.startsWith('item.dust.')) {
      final e = bestiary[id] ?? const BestiaryEntry();
      bestiary[id] = e.copyWith(captured: true, captures: e.captures + n);
    }
    // O primeiro Caco de vidro abre a quest que ensina o crafting: o mentor manda a mensagem `craft_tut_start`.
    if (id == kCraftTutorialTrigger && crafting.tutorial == CraftTutorial.off) {
      crafting.tutorial = CraftTutorial.on;
      story.events['craft_tut_start'] = 1;
    }
    notifyListeners();
    return n;
  }

  /// Gasta uma unidade (de um id puro, a pior qualidade que houver). `false` se não há.
  bool take(String itemId) => spend({itemId: 1});

  /// As pilhas exatas que [items] gasta: uma chave com qualidade sai da própria pilha; um id puro sai da pior qualidade
  /// primeiro, para guardar o material bom. `null` se falta algum.
  Map<String, int>? stacksFor(Map<String, int> items) {
    final plan = <String, int>{};
    int have(String k) => (inventory[k] ?? 0) - (plan[k] ?? 0);
    for (final e in items.entries) {
      var left = e.value;
      for (final k in e.key.contains('@') ? [e.key] : stackKeys(e.key)) {
        final take = left < have(k) ? left : have(k);
        if (take > 0) plan[k] = (plan[k] ?? 0) + take;
        left -= take > 0 ? take : 0;
        if (left == 0) break;
      }
      if (left > 0) return null;
    }
    return plan;
  }

  void _drop(Map<String, int> stacks) {
    for (final e in stacks.entries) {
      final left = (inventory[e.key] ?? 0) - e.value;
      left <= 0 ? inventory.remove(e.key) : inventory[e.key] = left;
    }
  }

  /// Gasta vários itens de uma vez (o ritual). `false`, sem gastar nada, se falta algum.
  bool spend(Map<String, int> items) {
    final plan = stacksFor(items);
    if (plan == null) return false;
    _drop(plan);
    notifyListeners();
    return true;
  }

  /// Fabrica uma receita se há todos os ingredientes: o resultado sai na qualidade [q]. `false` se falta algum.
  bool craft(Map<String, int> inputs, String outId, int outQty, {Quality q = Quality.common}) {
    final plan = stacksFor(inputs);
    if (plan == null) return false;
    _drop(plan);
    add(outId, outQty, q: q);
    return true;
  }

  static String uidKey(int uid) => uid.toString();

  /// Se o spawn já foi coletado, capturado ou fugiu: não aparece de novo.
  bool isDone(int uid) => _collected.containsKey(uidKey(uid));

  /// Registra o uid em [nowUtc] e limpa o que passou de 48 horas. Uma marcação desse uid acaba.
  void markDone(int uid, int nowUtc) {
    _collected[uidKey(uid)] = nowUtc;
    _collected.removeWhere((_, at) => nowUtc - at > registryKeepSeconds);
    marks.removeWhere((m) => m.uid == uidKey(uid));
    notifyListeners();
  }

  int get registrySize => _collected.length;

  bool hasCaptured(String speciesId) => bestiary[speciesId]?.captured ?? false;

  /// A espécie (e a variante ou o Brilhante, se for) apareceu na visão do jogador. A primeira variante e o primeiro
  /// Brilhante contam como eventos de jogo (o Familiar comenta no chat).
  ///
  /// [tags]: quando foi vista (`seenTags`: a hora e o clima), para a pesquisa do Bestiário.
  void markSeen(String speciesId, {String? variant, bool shiny = false, Set<String> tags = const {}}) {
    var changed = false;
    for (final k in bestiaryKeys(speciesId, variant: variant, shiny: shiny)) {
      final e = bestiary[k] ?? const BestiaryEntry();
      if (e.seen && e.when.containsAll(tags)) continue;
      bestiary[k] = e.copyWith(seen: true, when: {...e.when, ...tags});
      if (!e.seen || k == speciesId) changed = true;
    }
    if (!changed) return;
    if (shiny && story.count('shiny_seen') == 0) story.events['shiny_seen'] = 1;
    if (variant != null && story.count('variant_seen') == 0) story.events['variant_seen'] = 1;
    notifyListeners();
  }

  /// A criatura entra na coleção e no bestiário, e o spawn some do registro de vivos.
  /// Com [debug] (criatura do "Criar criatura"), entra na coleção marcada e não toca no bestiário.
  CreatureInstance capture({
    required int uid,
    required String speciesId,
    required int level,
    required int nowUtc,
    String? variant,
    bool shiny = false,
    bool debug = false,
    String? biome,
    bool personal = false,
    bool hidden = false,
  }) {
    final c = CreatureInstance(uid: uidKey(uid), speciesId: speciesId, level: level, capturedUtc: nowUtc, variant: variant, shiny: shiny, debug: debug, personal: personal, hidden: hidden);
    collection.add(c);
    for (final k in debug ? const <String>[] : bestiaryKeys(speciesId, variant: variant, shiny: shiny)) {
      final e = bestiary[k] ?? const BestiaryEntry();
      bestiary[k] = e.copyWith(captured: true, captures: e.captures + 1, biomes: {...e.biomes, ?biome});
    }
    markDone(uid, nowUtc);
    return c;
  }

  /// Põe uma criatura que não veio de um spawn (a fusão) na coleção e no bestiário como capturada. A de debug fica fora do bestiário.
  void addCreature(CreatureInstance c) {
    collection.add(c);
    for (final k in c.debug ? const <String>[] : bestiaryKeys(c.speciesId, variant: c.variant, shiny: c.shiny)) {
      final e = bestiary[k] ?? const BestiaryEntry();
      bestiary[k] = e.copyWith(captured: true, captures: e.captures + 1);
    }
    notifyListeners();
  }

  CreatureInstance? creature(String uid) {
    for (final c in collection) {
      if (c.uid == uid) return c;
    }
    return null;
  }

  /// Troca uma criatura da coleção por uma versão atualizada (nível, XP).
  void replaceCreature(CreatureInstance next) {
    final i = collection.indexWhere((c) => c.uid == next.uid);
    if (i >= 0) collection[i] = next;
    notifyListeners();
  }

  bool inCircle(String uid) => circle.contains(uid);

  /// Põe a criatura no Círculo, ou tira se já está. `false` se o Círculo está cheio ou ela não existe.
  bool toggleCircle(String uid) {
    if (circle.remove(uid)) {
      notifyListeners();
      return true;
    }
    if (circle.length >= 3 || creature(uid) == null || home.holds(uid)) return false; // 0.28.0: quem está em casa não entra
    circle.add(uid);
    notifyListeners();
    return true;
  }

  /// Tira a criatura da coleção. Criaturas do Círculo e as que estão em casa (0.28.0) não saem.
  bool removeCreature(String uid) {
    if (inCircle(uid) || creature(uid) == null || home.holds(uid)) return false;
    collection.removeWhere((c) => c.uid == uid);
    notifyListeners();
    return true;
  }

  /// As marcações que ainda valem em [nowUtc]. As vencidas saem da lista.
  List<Mark> activeMarks(int nowUtc) {
    final before = marks.length;
    marks.removeWhere((m) => !m.activeAt(nowUtc));
    if (marks.length != before) notifyListeners();
    return List.unmodifiable(marks);
  }

  Mark? markOf(int uid) {
    for (final m in marks) {
      if (m.uid == uidKey(uid)) return m;
    }
    return null;
  }

  /// Marca o sinal. `false` se já há o máximo de marcações ativas.
  bool addMark(Mark m, int nowUtc) {
    if (activeMarks(nowUtc).length >= balance.markMax) return false;
    marks.add(m);
    notifyListeners();
    return true;
  }

  bool removeMark(String uid) {
    final had = marks.any((m) => m.uid == uid);
    marks.removeWhere((m) => m.uid == uid);
    if (had) notifyListeners();
    return had;
  }

  Map<String, dynamic> toJson(int nowUtc) => {
        ..._extra,
        'schema_version': saveSchemaVersion,
        'group_code': groupCode,
        'player': progress.toJson(),
        if (levelOverride != null) 'level_override': levelOverride,
        'saved_utc': nowUtc,
        'created_utc': createdUtc ?? nowUtc,
        'last_seen_utc': lastSeenUtc,
        'app_version': appVersion,
        'epoch': epochId,
        if (founder != null) 'founder': founder!.toJson(),
        if (lastMapCell case (final x, final y)) kLastMapCellKey: [x, y],
        if (home.cell case (final x, final y)) kHomeCellKey: [x, y],
        'home': home.toJson(),
        'settings': settings,
        'story': story.toJson(),
        kVisitedCellsKey: [for (final c in _visited) [c.$1, c.$2]],
        'conjurer': conjurer.toJson(),
        'crafting': crafting.toJson(),
        'touches': touches.toJson(),
        'npcs': npcs.toJson(),
        'radar': {'last_utc': radarLastUtc, 'revealed': hiddenRevealed},
        'inventory': inventory,
        'collection': [for (final c in collection) c.toJson()],
        'collected': _collected,
        'circle': circle,
        'bestiary': {for (final e in bestiary.entries) e.key: e.value.toJson()},
        if (pins.isNotEmpty) 'bestiary_pins': pins,
        if (builds.isNotEmpty) 'personal_builds': [for (final b in builds) b.toJson()],
        'marks': [for (final m in marks) m.toJson()],
      };
}
