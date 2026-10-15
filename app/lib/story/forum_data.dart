/// Os modelos dos pedidos do fórum Limen, lidos de `assets/data/forum.json`. Dart puro.
library;

class ForumTemplate {
  const ForumTemplate({
    required this.id,
    required this.category,
    required this.kind,
    required this.keys,
    required this.targetMin,
    required this.targetMax,
    required this.step,
    required this.user,
    required this.rewardXp,
    required this.rewardItems,
    required this.texts,
  });

  factory ForumTemplate.fromJson(Map<String, dynamic> j) {
    final target = (j['target'] as List<dynamic>).cast<int>();
    final reward = j['reward'] as Map<String, dynamic>;
    return ForumTemplate(
      id: j['id'] as String,
      category: j['category'] as String,
      kind: j['kind'] as String,
      keys: (j['keys'] as List<dynamic>).cast<String>(),
      targetMin: target[0],
      targetMax: target[1],
      step: j['step'] as int,
      user: j['user'] as String,
      rewardXp: reward['xp'] as int,
      rewardItems: {for (final e in (reward['items'] as Map<String, dynamic>).entries) e.key: e.value as int},
      texts: (j['texts'] as List<dynamic>).cast<String>(),
    );
  }

  final String id;

  /// `explorar`, `coletar`, `cacar` ou `casa`.
  final String category;

  /// O evento do jogo que conta: `walk_m`, `spark`, `material`, `capture`, `craft` ou `distill`.
  final String kind;

  /// As variações do pedido (o tipo, o item ou a receita). `any` aceita qualquer uma.
  final List<String> keys;
  final int targetMin;
  final int targetMax;
  final int step;
  final String user;
  final int rewardXp;
  final Map<String, int> rewardItems;
  final List<String> texts;
}

class ForumSlot {
  const ForumSlot({required this.slot, required this.categories});

  final int slot;
  final List<String> categories;
}

class ForumData {
  const ForumData({required this.forum, required this.users, required this.slots, required this.levelScale, required this.templates});

  factory ForumData.fromJson(Map<String, dynamic> j) => ForumData(
        forum: j['forum'] as String,
        users: (j['users'] as List<dynamic>).cast<String>(),
        slots: [
          for (final s in j['slots'] as List<dynamic>)
            ForumSlot(slot: (s as Map<String, dynamic>)['slot'] as int, categories: (s['categories'] as List<dynamic>).cast<String>()),
        ],
        levelScale: (j['level_scale_per_level'] as num).toDouble(),
        templates: [for (final t in j['templates'] as List<dynamic>) ForumTemplate.fromJson(t as Map<String, dynamic>)],
      );

  final String forum;
  final List<String> users;
  final List<ForumSlot> slots;

  /// Quanto o alvo cresce por nível do Conjurador acima do 1.
  final double levelScale;
  final List<ForumTemplate> templates;

  ForumTemplate? template(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}
