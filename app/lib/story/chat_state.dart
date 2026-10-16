/// O chat com o mentor: o que já foi entregue, o que já foi lido e o relógio do tutorial. As mensagens saem
/// uma de cada vez, depois de [MentorMessage.afterS] segundos de jogo com o mapa aberto e, se a mensagem pede,
/// depois de um evento (a primeira captura, por exemplo). Dart puro.
library;

import 'mentor_script.dart';

class ChatEntry {
  const ChatEntry({required this.id, required this.utc});

  factory ChatEntry.fromJson(Map<String, dynamic> j) => ChatEntry(id: j['id'] as String, utc: j['utc'] as int);

  final String id;

  /// Quando a mensagem chegou, em segundos UTC.
  final int utc;

  Map<String, dynamic> toJson() => {'id': id, 'utc': utc};
}

class ChatState {
  ChatState({List<ChatEntry>? delivered, this.readCount = 0, this.waitS = 0}) : delivered = [...?delivered];

  factory ChatState.fromJson(Map<String, dynamic>? j) => ChatState(
        delivered: [for (final e in (j?['delivered'] as List<dynamic>?) ?? const []) ChatEntry.fromJson(e as Map<String, dynamic>)],
        readCount: (j?['read'] as int?) ?? 0,
        waitS: ((j?['wait_s'] as num?) ?? 0).toDouble(),
      );

  final List<ChatEntry> delivered;

  /// Quantas das entregues o jogador já viu.
  int readCount;

  /// Segundos de jogo desde a última entrega.
  double waitS;

  int get unread => delivered.length - readCount;

  /// Quantas mensagens do tutorial do mentor já saíram (as do Familiar não contam).
  int mentorDelivered(MentorScript script) {
    final ids = {for (final m in script.tutorial) m.id};
    return delivered.where((e) => ids.contains(e.id)).length;
  }

  bool tutorialDone(MentorScript script) => mentorDelivered(script) >= script.tutorial.length;

  void markAllRead() => readCount = delivered.length;

  /// Avança [dt] segundos de jogo. Entrega no máximo uma mensagem por chamada; devolve a entregue, ou `null`.
  /// [eventCount] diz quantas vezes um evento do jogo aconteceu.
  MentorMessage? tick(double dt, int nowUtc, MentorScript script, int Function(String event) eventCount) {
    if (tutorialDone(script)) return null;
    final next = script.tutorial[mentorDelivered(script)];
    waitS += dt;
    final req = next.requires;
    if (waitS < next.afterS || (req != null && eventCount(req.event) < req.min)) return null;
    delivered.add(ChatEntry(id: next.id, utc: nowUtc));
    waitS = 0;
    return next;
  }

  /// As falas do Familiar cujo acontecimento já houve e que ainda não saíram. Saem na hora, todas de uma vez, e só uma
  /// vez cada. Devolve as entregues agora.
  List<MentorMessage> deliverFamiliar(int nowUtc, MentorScript script, int Function(String event) eventCount) =>
      _deliverOnEvent(script.familiar, nowUtc, eventCount);

  /// Igual a [deliverFamiliar], para as mensagens por acontecimento do JSON (`event_messages`, as do ritual).
  List<MentorMessage> deliverEvents(int nowUtc, MentorScript script, int Function(String event) eventCount) =>
      _deliverOnEvent(script.events, nowUtc, eventCount);

  List<MentorMessage> _deliverOnEvent(List<MentorMessage> list, int nowUtc, int Function(String event) eventCount) {
    final out = <MentorMessage>[];
    for (final m in list) {
      final req = m.requires;
      if (delivered.any((e) => e.id == m.id) || (req != null && eventCount(req.event) < req.min)) continue;
      delivered.add(ChatEntry(id: m.id, utc: nowUtc));
      out.add(m);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {'delivered': [for (final e in delivered) e.toJson()], 'read': readCount, 'wait_s': waitS};
}
