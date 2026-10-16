/// O roteiro do mentor no chat (docs/GDD.md, "O mentor" e "Tutorial"): as mensagens do tutorial lidas de
/// `assets/data/mentor.json`. O texto é conteúdo, não código; os mesmos textos estão em `docs/textos-mentor.md`
/// para revisão. Dart puro.
library;

/// Uma condição de jogo para a mensagem sair: o evento aconteceu ao menos [min] vezes.
class MentorRequirement {
  const MentorRequirement({required this.event, required this.min});

  final String event;
  final int min;
}

class MentorMessage {
  const MentorMessage({required this.id, required this.afterS, required this.text, this.requires, this.from = 'mentor', this.action});

  factory MentorMessage.fromJson(Map<String, dynamic> j, {String from = 'mentor'}) => MentorMessage(
        id: j['id'] as String,
        from: from,
        afterS: ((j['after_s'] as num?) ?? 0).toDouble(),
        text: j['text'] as String,
        action: j['action'] as String?,
        requires: j['requires'] == null
            ? null
            : MentorRequirement(event: (j['requires'] as Map<String, dynamic>)['event'] as String, min: (j['requires'] as Map<String, dynamic>)['min'] as int),
      );

  final String id;

  /// Quem fala: `mentor` ou `familiar` (as falas do Familiar saem sozinhas quando o evento acontece).
  final String from;

  /// Segundos de jogo com o mapa aberto, desde a mensagem anterior, até esta sair.
  final double afterS;
  final String text;
  final MentorRequirement? requires;

  /// Botão opcional que o Chat mostra embaixo da mensagem (`school_tests`: abre os testes de escola).
  final String? action;
}

class MentorScript {
  const MentorScript({required this.contactName, required this.contactNote, required this.tutorial, this.familiar = const [], this.school = const [], this.phoneUnlock = const {}});

  factory MentorScript.fromJson(Map<String, dynamic> j) => MentorScript(
        contactName: (j['contact'] as Map<String, dynamic>)['name'] as String,
        contactNote: ((j['contact'] as Map<String, dynamic>)['note'] as String?) ?? '',
        tutorial: [for (final m in j['tutorial'] as List<dynamic>) MentorMessage.fromJson(m as Map<String, dynamic>)],
        familiar: [for (final m in (j['familiar'] as List<dynamic>?) ?? const []) MentorMessage.fromJson(m as Map<String, dynamic>, from: 'familiar')],
        school: [for (final m in (j['school'] as List<dynamic>?) ?? const []) MentorMessage.fromJson(m as Map<String, dynamic>)],
        phoneUnlock: {for (final e in ((j['phone_unlock'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
      );

  final String contactName;
  final String contactNote;
  final List<MentorMessage> tutorial;

  /// As falas do Familiar, cada uma ligada a um acontecimento do jogo.
  final List<MentorMessage> familiar;

  /// As mensagens do mentor sobre a escola (`school_*`): o convite aos testes (sai por nível, ver `GameState.tickChat`) e as que
  /// esperam um evento.
  final List<MentorMessage> school;

  /// A fala do Familiar quando um app novo do celular se forma (id do app -> texto). Só os apps de nível 2 em diante.
  final Map<String, String> phoneUnlock;

  MentorMessage? byId(String id) {
    for (final m in [...tutorial, ...familiar, ...school]) {
      if (m.id == id) return m;
    }
    return null;
  }
}
