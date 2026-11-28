/// O registro do menu de debug (0.26.6): cada ação ou ajuste é uma [DebugEntry] com id estável, aba, tipo de controle,
/// parâmetros e valores válidos, se mexe no save e se é destrutiva. A tela (`debug_menu_view.dart`) e a linha de comando
/// (`debug_commands.dart`, `scripts/celular.sh cmd`) são duas vistas dele: as duas passam por [DebugRegistry.execute].
///
/// COMO REGISTRAR UMA ENTRADA NOVA
/// 1. Um id de texto estável `aba.nome` (`world.weather`, `player.xp.add`). Favoritos, testes e o `cmd` guardam o id; um id
///    antigo vira alias ([DebugEntry.aliases]) e nunca some (`test/dev/debug_registry_test.dart`).
/// 2. O tipo ([DebugKind]) decide o desenho e o argumento: alternar (`on`/`off`), escolha (um dos [DebugEntry.options]),
///    número (entre [DebugEntry.min] e [DebugEntry.max]), coordenada (`lat,lon` ou um lugar), ação (parâmetros nomeados,
///    `nome=valor`) e leitura (só devolve o texto de [DebugEntry.read]).
/// 3. [DebugEntry.run] faz a coisa e devolve a frase do aviso (ou `null`: "ok"); erro de uso é [DebugError].
/// 4. O que tira o jogo do real tem [DebugEntry.offReal] (o rótulo do chip do topo) e [DebugEntry.toReal] (desfaz).
/// 5. As entradas padrão ficam nos `debug_items_*.dart`, uma lista por aba, e entram em `buildDefaultRegistry`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

/// As abas do menu, na ordem da tela.
enum DebugTab {
  world('mundo', 'Mundo'),
  position('posicao', 'Posição'),
  creatures('criaturas', 'Criaturas'),
  player('jogador', 'Jogador'),
  visual('visual', 'Visual'),
  system('sistema', 'Sistema');

  const DebugTab(this.id, this.title);
  final String id;
  final String title;
}

/// O controle de uma entrada: o desenho na tela e o argumento no `cmd`.
enum DebugKind {
  toggle('alternar'),
  choice('escolha'),
  number('número'),
  coord('coordenada'),
  action('ação'),
  view('leitura');

  const DebugKind(this.label);
  final String label;
}

/// Um grupo de uma leitura (aba Sistema): o título e as linhas de rótulo e valor.
typedef DebugGroup = ({String title, List<(String, String)> rows});

/// A leitura em texto, um grupo por bloco (o `cmd` e o botão de copiar).
String groupsText(List<DebugGroup> groups) => [
      for (final g in groups) [g.title, for (final (k, v) in g.rows) '  $k: $v'].join('\n'),
    ].join('\n');

/// Um valor válido: [value] é o que o `cmd` recebe, [label] o que a tela mostra.
class DebugOption {
  const DebugOption(this.value, this.label);
  final String value;
  final String label;
}

enum DebugParamKind { choice, number, toggle, text }

/// Um parâmetro de uma ação: no `cmd`, `nome=valor`; na tela, um controle dentro do cartão.
class DebugParam {
  const DebugParam(this.name, this.label, {this.kind = DebugParamKind.choice, this.options = const [], this.optionsOf, this.min, this.max, this.fallback = ''});

  final String name;
  final String label;
  final DebugParamKind kind;
  final List<DebugOption> options;

  /// Valores que dependem de dados carregados depois (espécies, selos).
  final List<DebugOption> Function()? optionsOf;
  final double? min, max;

  /// O valor quando ninguém escolheu.
  final String fallback;

  List<DebugOption> get values => optionsOf?.call() ?? options;
}

/// Erro de uso (argumento inválido, mapa fechado, sem save): vira "erro" no `cmd` e aviso na tela.
class DebugError implements Exception {
  const DebugError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Uma execução: os argumentos já conferidos ('' é o valor do controle) e a tela, se houver.
class DebugCall {
  DebugCall(this.args, this.context);

  final Map<String, String> args;
  final BuildContext? context;

  String get value => args[''] ?? '';
  String operator [](String name) => args[name] ?? '';
  int intOf(String name) => double.parse(args[name]!).round();
  double numberOf(String name) => double.parse(args[name]!);
  bool flag(String name) => args[name] == 'on';

  /// A tela para empurrar uma rota ou abrir um diálogo; sem ela (menu ainda montando), erro.
  BuildContext get screen {
    final c = context;
    if (c == null || !c.mounted) throw const DebugError('sem tela aberta');
    return c;
  }
}

class DebugEntry {
  DebugEntry({
    required this.id,
    required this.name,
    required this.tab,
    required this.kind,
    this.run,
    this.read,
    this.groups,
    this.status,
    this.info,
    this.warn,
    this.keywords = const [],
    this.aliases = const [],
    this.options = const [],
    this.optionsOf,
    this.multi = false,
    this.min,
    this.max,
    this.params = const [],
    this.touchesSave = false,
    this.destructive = false,
    this.confirmWord = 'sim',
    this.selfConfirm = false,
    this.offReal,
    this.toReal,
    this.load,
    this.extra,
    this.copy,
    this.enabled,
    bool? autoLoad,
  })  : autoLoad = autoLoad ?? kind == DebugKind.view,
        assert(kind == DebugKind.view || run != null, '$id sem run');

  final String id;
  final String name;
  final DebugTab tab;
  final DebugKind kind;

  /// Faz a coisa. Devolve a frase do aviso (um `String`); qualquer outra coisa (um setter, `null`) vira "ok".
  final dynamic Function(DebugCall c)? run;

  /// O valor de agora, no formato do argumento (`on`, um valor da escolha, o número, `lat,lon`), ou o texto da leitura.
  final String? Function()? read;

  /// A leitura em grupos de rótulo e valor (o lugar do texto corrido nas leituras): a tela desenha as linhas, o `cmd` e o
  /// copiar levam o texto ([groupsText]).
  final List<DebugGroup> Function()? groups;

  /// O texto da leitura: [read], ou os [groups] em texto.
  String? readText() => read?.call() ?? (groups == null ? null : groupsText(groups!()));

  /// Uma linha de estado sob o título (a escola no save, a resistência da sintonia, a Patrulha).
  final String? Function()? status;

  /// A descrição, atrás do (i).
  final String? info;

  /// Aviso de uma linha, sempre visível.
  final String? warn;
  final List<String> keywords;

  /// Ids antigos e nomes de comando de antes (`tp`, `sim`, `time.clock`): continuam valendo.
  final List<String> aliases;
  final List<DebugOption> options;
  final List<DebugOption> Function()? optionsOf;

  /// Escolha múltipla: cada valor liga ou desliga; `real` limpa.
  final bool multi;
  final double? min, max;
  final List<DebugParam> params;
  final bool touchesSave;
  final bool destructive;

  /// A palavra que libera o destrutivo (`confirma=<palavra>` no `cmd`; digitada na tela quando não é "sim").
  final String confirmWord;

  /// O próprio [run] mostra o que vai mudar e pede a confirmação (importar backup): a tela não pergunta antes.
  final bool selfConfirm;

  /// O rótulo do chip "fora do real" (`RELÓGIO 03:17 UTC`), ou `null` com o jogo no real.
  final String? Function()? offReal;
  final FutureOr<void> Function()? toReal;

  /// Carrega o que as [options] precisam (o catálogo do clima): o `cmd` chama antes de conferir; a tela, num botão.
  final Future<void> Function()? load;

  /// Leitura extra embaixo do controle (só mostra; nenhuma ação mora aqui).
  final WidgetBuilder? extra;

  /// O que o botão de copiar da leitura leva (o padrão é o texto dela).
  final String? Function()? copy;

  /// O cartão chama [load] ao aparecer (as leituras, a escola no save).
  final bool autoLoad;

  /// `null` ou verdadeiro: dá para usar agora. Falso: apagado na tela e erro no `cmd`.
  final bool Function()? enabled;

  /// Valores dos parâmetros escolhidos na tela (a próxima execução usa).
  final Map<String, String> form = {};

  List<DebugOption> get values => optionsOf?.call() ?? options;

  /// O valor de um parâmetro agora: o escolhido na tela ou o padrão.
  String paramValue(DebugParam p) => form[p.name] ?? p.fallback;

  /// Todas as palavras da [query] (sem acento nem caixa) aparecem no nome, nas palavras-chave, no id ou na aba.
  bool matches(String query) {
    final words = fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final hay = fold('$name ${keywords.join(' ')} $id ${aliases.join(' ')} ${tab.title}');
    return words.every(hay.contains);
  }

  /// A linha do `cmd list`: id, tipo, valores, marcas e aliases.
  String describe() {
    final b = StringBuffer('$id · ${kind.label} · $name');
    switch (kind) {
      case DebugKind.toggle:
        b.write(' · on|off');
      case DebugKind.choice:
        b.write(' · ${multi ? 'liga/desliga: ' : ''}${values.map((o) => o.value).join('|')}');
      case DebugKind.number:
        b.write(' · ${_n(min)}..${_n(max)}');
      case DebugKind.coord:
        b.write(' · lat,lon${values.isEmpty ? '' : ' ou ${values.map((o) => o.value == 'mapa' ? 'mapa' : fold(o.label).replaceAll(' ', '')).join('|')}'}');
      case DebugKind.action:
        for (final p in params) {
          b.write(' · ${p.name}=${switch (p.kind) {
            DebugParamKind.choice => p.values.map((o) => o.value).join('|'),
            DebugParamKind.number => '${_n(p.min)}..${_n(p.max)}',
            DebugParamKind.toggle => 'on|off',
            DebugParamKind.text => 'texto',
          }}${p.fallback.isEmpty ? '' : ' (${p.fallback})'}');
        }
      case DebugKind.view:
        break;
    }
    if (offReal != null) b.write(' · real desfaz');
    if (touchesSave) b.write(' · mexe no save');
    if (destructive) b.write(' · destrutivo: confirma=$confirmWord');
    if (aliases.isNotEmpty) b.write(' · alias ${aliases.join(', ')}');
    return b.toString();
  }
}

String _n(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');

const _from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _to = 'aaaaaeeeeiiiiooooouuuucn';

/// Sem acento e sem caixa.
String fold(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = _from.indexOf(c);
    b.write(i < 0 ? c : _to[i]);
  }
  return b.toString();
}

class DebugRegistry {
  final List<DebugEntry> _entries = [];
  final Map<String, DebugEntry> _byName = {};

  /// A tela do menu, para as ações que empurram rotas ou abrem diálogos (o menu é a primeira rota e não sai).
  BuildContext? Function()? screen;

  /// Quem quer saber que algo rodou (a tela se redesenha: nem todo estado avisa sozinho).
  final ValueNotifier<int> ran = ValueNotifier(0);

  List<DebugEntry> get entries => List.unmodifiable(_entries);
  Set<String> get ids => {for (final e in _entries) e.id};

  void add(DebugEntry e) {
    for (final n in [e.id, ...e.aliases]) {
      assert(!_byName.containsKey(n), 'nome repetido no registro: $n');
      _byName[n] = e;
    }
    _entries.add(e);
  }

  void addAll(Iterable<DebugEntry> es) => es.forEach(add);

  /// Pelo id ou por um alias.
  DebugEntry? byName(String name) => _byName[name];

  List<DebugEntry> inTab(DebugTab t) => [for (final e in _entries) if (e.tab == t) e];

  List<DebugEntry> search(String query) => [for (final e in _entries) if (e.matches(query)) e];

  /// As entradas fora do real agora, com o rótulo do chip.
  List<(DebugEntry, String)> offReal() => [
        for (final e in _entries)
          if (e.offReal?.call() case final label?) (e, label),
      ];

  /// Desfaz uma entrada (o chip do topo, ou `cmd <id> real`).
  Future<String> undo(DebugEntry e) async {
    final f = e.toReal;
    if (f == null) throw DebugError('${e.id} não tem o que desfazer');
    await f();
    ran.value++;
    return '${e.id} real';
  }

  /// "Voltar tudo ao real": desfaz o que não mexe no save. Devolve o que ficou.
  Future<List<String>> undoAll() async {
    final kept = <String>[];
    for (final (e, label) in offReal()) {
      if (e.touchesSave) {
        kept.add(label);
      } else {
        await e.toReal?.call();
      }
    }
    ran.value++;
    return kept;
  }

  /// O `cmd state`: o que está fora do real, a fonte de posição e o relógio, em JSON.
  String state({required Map<String, Object?> always}) => jsonEncode({
        ...always,
        'fora_do_real': {for (final (e, label) in offReal()) e.id: {'rotulo': label, 'valor': ?e.read?.call()}},
      });

  /// Confere [raw] contra o tipo de [e] e roda. `real` desfaz. Devolve a frase do aviso; erro de uso é [DebugError].
  Future<String> execute(DebugEntry e, String raw, {BuildContext? context}) async {
    final tokens = raw.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final named = <String, String>{for (final t in tokens) if (t.contains('=')) t.substring(0, t.indexOf('=')): t.substring(t.indexOf('=') + 1)};
    final value = tokens.where((t) => !t.contains('=')).join(' ');
    if (value == '?') {
      await e.load?.call();
      return [e.describe(), if (e.read?.call() case final v?) 'valor: $v', ?e.status?.call()].join(' · ');
    }
    if (e.kind == DebugKind.view) {
      await e.load?.call();
      return e.readText() ?? '';
    }
    if (value == 'real' && e.offReal != null) return undo(e);
    if (e.enabled?.call() == false) throw DebugError('${e.name}: indisponível agora');
    if (e.destructive && named['confirma'] != e.confirmWord) throw DebugError('${e.id} é destrutivo: mande confirma=${e.confirmWord}');
    await e.load?.call();
    final args = <String, String>{};
    switch (e.kind) {
      case DebugKind.toggle:
        final now = e.read?.call() == 'on';
        args[''] = switch (value) {
          '' => now ? 'off' : 'on',
          'on' || 'true' || '1' || 'sim' => 'on',
          'off' || 'false' || '0' || 'nao' || 'não' => 'off',
          _ => throw DebugError('on ou off, não "$value"'),
        };
      case DebugKind.choice:
        args[''] = _option('', e.values, value);
      case DebugKind.number:
        args[''] = _number('', value, e.min, e.max);
      case DebugKind.coord:
        final place = [for (final o in e.values) if (o.value == value || fold(o.label).replaceAll(' ', '') == fold(value).replaceAll(' ', '')) o.value].firstOrNull;
        if (place == 'mapa') {
          args[''] = 'mapa';
        } else {
          final c = parseLatLon(place ?? value);
          if (c == null) throw DebugError('lat,lon ou um lugar (${e.values.map((o) => fold(o.label)).join('|')}), não "$value"');
          args[''] = '${c.$1},${c.$2}';
        }
      case DebugKind.action:
        // Um parâmetro só aceita o valor sem nome (`clock 2027-01-08T02:00`, `turn 30`).
        if (value.isNotEmpty && e.params.length == 1) named.putIfAbsent(e.params.single.name, () => value);
        for (final p in e.params) {
          final v = named[p.name] ?? e.paramValue(p);
          args[p.name] = switch (p.kind) {
            DebugParamKind.choice => _option(p.name, p.values, v),
            DebugParamKind.number => _number(p.name, v, p.min, p.max),
            DebugParamKind.toggle => v == 'on' || v == 'true' || v == '1' ? 'on' : 'off',
            DebugParamKind.text => v,
          };
        }
      case DebugKind.view:
        break;
    }
    final Object? out = await e.run!(DebugCall(args, context ?? screen?.call()));
    ran.value++;
    return out is String ? out : 'ok';
  }

  /// Roda pelo nome (id ou alias): o `cmd`.
  Future<String> executeNamed(String name, String raw) {
    final e = byName(name);
    if (e == null) throw DebugError('não existe: $name (cmd list)');
    return execute(e, raw);
  }
}

String _option(String what, List<DebugOption> options, String v) {
  final pre = what.isEmpty ? '' : '$what: ';
  if (options.isEmpty) throw DebugError('${pre}ainda carregando os valores');
  final n = double.tryParse(v);
  for (final o in options) {
    if (o.value == v || fold(o.label) == fold(v) || (n != null && double.tryParse(o.value) == n)) return o.value;
  }
  throw DebugError('${pre}um de ${options.map((o) => o.value).join('|')}, não "$v"');
}

String _number(String what, String v, double? min, double? max) {
  final n = double.tryParse(v.replaceAll(',', '.'));
  if (n == null || (min != null && n < min) || (max != null && n > max)) throw DebugError('${what.isEmpty ? '' : '$what: '}número de ${_n(min)} a ${_n(max)}, não "$v"');
  return _n(n);
}

/// "lat,lon", "lat, lon" ou "lat lon" (vírgula decimal só sem a vírgula do meio). `null` se não for coordenada.
(double, double)? parseLatLon(String s) {
  final parts = s.trim().split(RegExp(r'[,;\s]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length != 2) return null;
  final a = double.tryParse(parts[0]), b = double.tryParse(parts[1]);
  if (a == null || b == null || a.abs() > 85 || b.abs() > 180) return null;
  return (a, b);
}
