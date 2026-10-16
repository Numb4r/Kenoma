/// Os apps do celular: a ordem e o nível que libera cada um vêm de `phone.apps` no `balance.json`; o nome na tela e
/// o ponto laranja de novidade ficam aqui. Dart puro.
library;

import '../../crafting/fusion.dart' show fusionPossible;
import '../../crafting/ritual.dart' show ritualResearchUnseen;
import '../../player/game_state.dart';

/// Os ids dos apps. Mudou um id? Mude também o `balance.json` e as falas de `phone_unlock` do `mentor.json`.
abstract final class PhoneAppId {
  static const vision = 'vision';
  static const radar = 'radar';
  static const bestiary = 'bestiary';
  static const circle = 'circle';
  static const bag = 'bag';
  static const bench = 'bench';
  static const chat = 'chat';
  static const forum = 'forum';
  static const profile = 'profile';
  static const settings = 'settings';
}

/// O nome de cada app na tela (a caixa alta é de quem desenha).
const Map<String, String> phoneAppLabels = {
  PhoneAppId.vision: 'Visão espectral',
  PhoneAppId.radar: 'Radar',
  PhoneAppId.bestiary: 'Bestiário',
  PhoneAppId.circle: 'Círculo',
  PhoneAppId.bag: 'Bolsa',
  PhoneAppId.bench: 'Bancada',
  PhoneAppId.chat: 'Chat',
  PhoneAppId.forum: 'Fórum',
  PhoneAppId.profile: 'Perfil',
  PhoneAppId.settings: 'Ajustes',
};

class PhoneApp {
  const PhoneApp({required this.id, required this.unlockLevel});

  final String id;
  final int unlockLevel;

  String get label => phoneAppLabels[id] ?? id;

  bool unlockedAt(int level) => level >= unlockLevel;

  /// Foi liberado depois do começo do jogo: só estes se formam com a costura e ganham fala do Familiar.
  bool get isNewcomer => unlockLevel > 1;
}

class PhoneApps {
  const PhoneApps(this.apps);

  factory PhoneApps.fromBalance(Map<String, dynamic> balance) {
    final list = ((balance['phone'] as Map<String, dynamic>?)?['apps'] as List<dynamic>?) ?? const [];
    return PhoneApps([for (final a in list) PhoneApp(id: (a as Map<String, dynamic>)['id'] as String, unlockLevel: a['unlock_level'] as int)]);
  }

  /// Na ordem da grade.
  final List<PhoneApp> apps;

  /// Os apps já liberados no nível do Conjurador que ele ainda não viu se formar.
  List<PhoneApp> unseen(GameState s) =>
      [for (final a in apps) if (a.isNewcomer && a.unlockedAt(s.playerLevel) && !s.setting(phoneSeenKey(a.id))) a];
}

String phoneSeenKey(String appId) => 'phone_seen_$appId';

/// Há pontos de talento que o jogador ainda não viu no Perfil (o Perfil grava o saldo visto ao abrir).
bool profileHasNews(GameState s) => s.conjurer.talentAvailable > ((s.settings['profile_seen_talent'] as int?) ?? 0);

int claimableRequests(GameState s) => s.story.daily.quests.where((q) => q.claimable).length;

/// Pontos de novidade (a bolinha laranja): um `bool Function(GameState)` por id de app. Para ligar um app novo ao ponto,
/// troque o `(_) => false` pela condição; o celular e o botão do mapa já leem daqui.
final Map<String, bool Function(GameState)> phoneAppBadges = {
  PhoneAppId.chat: (s) => s.story.chat.unread > 0,
  PhoneAppId.forum: (s) => claimableRequests(s) > 0,
  PhoneAppId.bench: fusionPossible, // fusão possível
  PhoneAppId.profile: profileHasNews,
  PhoneAppId.bestiary: ritualResearchUnseen, // espaço de ritual novo revelado e ainda não visto
};

/// O app [a] tem novidade agora (e está liberado).
bool phoneAppHasBadge(GameState s, PhoneApp a) => a.unlockedAt(s.playerLevel) && (phoneAppBadges[a.id]?.call(s) ?? false);
