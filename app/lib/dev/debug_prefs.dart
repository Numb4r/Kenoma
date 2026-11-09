/// Preferências do menu de debug: favoritos, seções abertas ou fechadas e o último "Criar criatura". Um JSON pequeno (`debug_menu.json`) nos
/// documentos do app. Toda leitura e escrita tem try/catch: sem disco, o menu funciona e só não lembra.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:path_provider/path_provider.dart';

import 'debug_registry.dart';

class DebugPrefs extends ChangeNotifier {
  /// [file] `null`: só em memória. [defaultOpen]: se as seções (menos Favoritos, que abre sempre) começam abertas.
  DebugPrefs({this.file, this.defaultOpen = false});

  /// Os documentos do app, ou só memória se a pasta não existir (testes).
  static Future<DebugPrefs> inDocuments() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return DebugPrefs(file: File('${dir.path}/debug_menu.json'));
    } catch (_) {
      return DebugPrefs();
    }
  }

  final File? file;
  final bool defaultOpen;
  final List<String> _favorites = [];
  final Map<String, bool> _open = {};
  Map<String, dynamic>? _creatureForm;

  /// O último formulário do "Criar criatura" (`DebugCreatureSpec.toJson`), para o botão "repetir". `null`: nenhum ainda.
  Map<String, dynamic>? get creatureForm => _creatureForm;

  Future<void> setCreatureForm(Map<String, dynamic> form) {
    _creatureForm = form;
    notifyListeners();
    return _save();
  }

  List<String> get favorites => List.unmodifiable(_favorites);
  bool isFavorite(String id) => _favorites.contains(id);

  bool isOpen(DebugSection s) => _open[s.id] ?? (s == DebugSection.favorites || defaultOpen);

  Future<void> load() async {
    try {
      final f = file;
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _favorites
        ..clear()
        ..addAll((j['favorites'] as List? ?? const []).whereType<String>());
      _open
        ..clear()
        ..addAll({for (final e in (j['open'] as Map? ?? const {}).entries) if (e.value is bool) e.key as String: e.value as bool});
      _creatureForm = j['creature_form'] is Map<String, dynamic> ? j['creature_form'] as Map<String, dynamic> : null;
      notifyListeners();
    } catch (_) {
      // arquivo ilegível ou sem disco: segue com os padrões
    }
  }

  Future<void> toggleFavorite(String id) {
    isFavorite(id) ? _favorites.remove(id) : _favorites.add(id);
    notifyListeners();
    return _save();
  }

  Future<void> setOpen(DebugSection s, bool open) {
    _open[s.id] = open;
    notifyListeners();
    return _save();
  }

  Future<void> _queue = Future.value();

  /// Grava em fila: duas gravações juntas no mesmo arquivo poderiam terminar fora de ordem.
  Future<void> _save() => _queue = _queue.then((_) async {
        try {
          await file?.writeAsString(jsonEncode({'favorites': _favorites, 'open': _open, if (_creatureForm != null) 'creature_form': _creatureForm}), flush: true);
        } catch (_) {
          // sem disco: vale só nesta sessão
        }
      });
}
