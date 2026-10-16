/// Registro dos itens do menu de debug. O menu (`debug_menu_view.dart`) só desenha o que está aqui.
///
/// COMO REGISTRAR UM ITEM NOVO
/// 1. Escolha um `id` de texto estável (`secao.nome`, ex.: `spawn.spirit`). Favoritos e testes guardam o id.
/// 2. Crie o item e some ao registro, em qualquer lugar que tenha acesso ao [DebugRegistry]:
///
///     registry.add(DebugItem(
///       id: 'player.xp',
///       title: 'XP do Conjurador',
///       section: DebugSection.player,
///       keywords: ['experiência', 'xp', 'nível'],
///       builder: (context) => MeuWidgetDeXp(),
///     ));
///
/// 3. O `builder` devolve só o conteúdo (campos, chips, botões; use `debug_widgets.dart`). O título e a estrela de
///    favorito vêm do menu. O item só é construído com a seção aberta, nos Favoritos ou numa busca.
/// 4. Os itens padrão ficam nos `debug_items_*.dart` e entram em `buildDefaultRegistry` (`debug_items.dart`).
///    Para um item de função que ainda não existe, basta chamar `registry.add` ali: a seção que mostrava
///    "sem itens ainda" passa a mostrá-lo.
/// 5. Nunca remova nem renomeie um id existente: `test/dev/debug_registry_test.dart` falha se um id original sumir.
library;

import 'package:flutter/widgets.dart';

/// As seções do menu, na ordem em que aparecem. [favorites] é especial: nunca recebe item, mostra os fixados.
enum DebugSection {
  favorites('favoritos', 'Favoritos'),
  position('posicao', 'Posição'),
  time('tempo', 'Tempo e mundo'),
  spawns('spawns', 'Spawns'),
  map('mapa', 'Mapa e câmera'),
  traffic('trafego', 'Tráfego'),
  player('jogador', 'Jogador'),
  capture('captura', 'Captura'),
  signatures('assinaturas', 'Assinaturas'),
  performance('desempenho', 'Desempenho'),
  save('save', 'Save');

  const DebugSection(this.id, this.title);
  final String id;
  final String title;
}

class DebugItem {
  const DebugItem({required this.id, required this.title, required this.section, required this.builder, this.keywords = const []});

  final String id;
  final String title;
  final DebugSection section;
  final List<String> keywords;
  final WidgetBuilder builder;

  /// Todas as palavras da [query] (sem acento nem caixa) aparecem no título, nas palavras-chave ou na seção.
  bool matches(String query) {
    final words = _fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final hay = _fold('$title ${keywords.join(' ')} ${section.title}');
    return words.every(hay.contains);
  }
}

const _from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _to = 'aaaaaeeeeiiiiooooouuuucn';

String _fold(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = _from.indexOf(c);
    b.write(i < 0 ? c : _to[i]);
  }
  return b.toString();
}

class DebugRegistry {
  final List<DebugItem> _items = [];

  List<DebugItem> get items => List.unmodifiable(_items);
  Set<String> get ids => {for (final i in _items) i.id};

  void add(DebugItem item) {
    assert(item.section != DebugSection.favorites, 'Favoritos não recebe item');
    assert(!_items.any((i) => i.id == item.id), 'id repetido: ${item.id}');
    _items.add(item);
  }

  void addAll(Iterable<DebugItem> items) => items.forEach(add);

  DebugItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<DebugItem> inSection(DebugSection s) => [for (final i in _items) if (i.section == s) i];

  List<DebugItem> search(String query) => [for (final i in _items) if (i.matches(query)) i];
}
