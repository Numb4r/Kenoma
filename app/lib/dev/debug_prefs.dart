/// Preferências do menu de debug: favoritos, a última aba e o último "Criar criatura". Um JSON pequeno (`debug_menu.json`) nos
/// documentos do app. Toda leitura e escrita tem try/catch: sem disco, o menu funciona e só não lembra.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:path_provider/path_provider.dart';

import 'debug_registry.dart';

class DebugPrefs extends ChangeNotifier {
  /// [file] `null`: só em memória.
  DebugPrefs({this.file});

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
  final List<String> _favorites = [];
  String? _tab;
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

  /// A última aba aberta (o id da [DebugTab]); `null`: a primeira.
  DebugTab get tab => DebugTab.values.where((t) => t.id == _tab).firstOrNull ?? DebugTab.values.first;

  Future<void> setTab(DebugTab t) {
    _tab = t.id;
    notifyListeners();
    return _save();
  }

  /// 0.26.6: os favoritos guardados com um id antigo passam para o id novo (o registro resolve o alias).
  void migrateFavorites(String? Function(String id) idOf) {
    final now = [for (final f in _favorites) idOf(f)].nonNulls.toSet().toList();
    if (now.length == _favorites.length && now.indexed.every((p) => _favorites[p.$1] == p.$2)) return;
    _favorites
      ..clear()
      ..addAll(now);
    _save();
  }

  Future<void> load() async {
    try {
      final f = file;
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _favorites
        ..clear()
        ..addAll((j['favorites'] as List? ?? const []).whereType<String>());
      _tab = j['tab'] as String?;
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

  Future<void> _queue = Future.value();

  /// Grava em fila: duas gravações juntas no mesmo arquivo poderiam terminar fora de ordem.
  Future<void> _save() => _queue = _queue.then((_) async {
        try {
          await file?.writeAsString(jsonEncode({'favorites': _favorites, if (_tab != null) 'tab': _tab, if (_creatureForm != null) 'creature_form': _creatureForm}), flush: true);
        } catch (_) {
          // sem disco: vale só nesta sessão
        }
      });
}
