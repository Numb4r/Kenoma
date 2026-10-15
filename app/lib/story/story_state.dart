/// O que a história e o fórum guardam no save: contadores de eventos de jogo, o chat com o mentor e as diárias.
library;

import 'chat_state.dart';
import 'daily_quests.dart';

class StoryState {
  StoryState({Map<String, int>? events, ChatState? chat, DailyState? daily})
      : events = {...?events},
        chat = chat ?? ChatState(),
        daily = daily ?? DailyState();

  factory StoryState.fromJson(Map<String, dynamic>? j) => StoryState(
        events: {for (final e in ((j?['events'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
        chat: ChatState.fromJson(j?['chat'] as Map<String, dynamic>?),
        daily: DailyState.fromJson(j?['daily'] as Map<String, dynamic>?),
      );

  /// Quantas vezes cada evento aconteceu desde o começo (`capture`, `craft`, `distill`, `spark`, `material`, `walk_m`).
  final Map<String, int> events;
  final ChatState chat;
  final DailyState daily;

  int count(String event) => events[event] ?? 0;

  Map<String, dynamic> toJson() => {'events': events, 'chat': chat.toJson(), 'daily': daily.toJson()};
}
