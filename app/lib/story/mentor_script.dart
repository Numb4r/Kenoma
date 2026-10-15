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
  const MentorMessage({required this.id, required this.afterS, required this.text, this.requires});

  factory MentorMessage.fromJson(Map<String, dynamic> j) => MentorMessage(
        id: j['id'] as String,
        afterS: (j['after_s'] as num).toDouble(),
        text: j['text'] as String,
        requires: j['requires'] == null
            ? null
            : MentorRequirement(event: (j['requires'] as Map<String, dynamic>)['event'] as String, min: (j['requires'] as Map<String, dynamic>)['min'] as int),
      );

  final String id;

  /// Segundos de jogo com o mapa aberto, desde a mensagem anterior, até esta sair.
  final double afterS;
  final String text;
  final MentorRequirement? requires;
}

class MentorScript {
  const MentorScript({required this.contactName, required this.contactNote, required this.tutorial});

  factory MentorScript.fromJson(Map<String, dynamic> j) => MentorScript(
        contactName: (j['contact'] as Map<String, dynamic>)['name'] as String,
        contactNote: ((j['contact'] as Map<String, dynamic>)['note'] as String?) ?? '',
        tutorial: [for (final m in j['tutorial'] as List<dynamic>) MentorMessage.fromJson(m as Map<String, dynamic>)],
      );

  final String contactName;
  final String contactNote;
  final List<MentorMessage> tutorial;

  MentorMessage? byId(String id) {
    for (final m in tutorial) {
      if (m.id == id) return m;
    }
    return null;
  }
}
