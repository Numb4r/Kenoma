/// O cartão de uma [DebugEntry], gerado do tipo dela: alternar (uma linha), escolha (grade de chips), número (barra),
/// coordenada (lugares, campo "lat, lon" e escolher no mapa), ação (parâmetros e o botão) e leitura (o texto). Toda
/// execução passa por [EntryCard.onRun], que chama o registro, como o `cmd`.
///
/// As keys: o cartão é `Key(id)`; um chip de escolha `id=valor`; um parâmetro `id.nome` (e o chip dele `id.nome=valor`);
/// o botão da ação `id.run`; o campo e o botão da coordenada `id.field` e `id.go`; o carregar `id.load`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../ui/pressable.dart';
import '../ui/tema.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

class EntryCard extends StatefulWidget {
  const EntryCard({required this.entry, required this.onRun, required this.favorite, required this.onStar, this.prefix, this.flash = false, super.key});

  final DebugEntry entry;

  /// Roda a entrada com o argumento do `cmd` ('' é o padrão: o formulário dos parâmetros).
  final Future<void> Function(DebugEntry e, String raw) onRun;
  final bool favorite;
  final VoidCallback onStar;

  /// A aba antes do título (nos resultados da busca).
  final String? prefix;

  /// Acabou de ser chamado pelos favoritos: o contorno acende por um instante.
  final bool flash;

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  bool _info = false;
  bool _loading = false;
  final _fields = <String, TextEditingController>{};
  final _drag = <String, double>{};

  DebugEntry get e => widget.entry;

  @override
  void initState() {
    super.initState();
    if (e.kind == DebugKind.view || e.autoLoad) _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final f = e.load;
    if (f == null) return;
    setState(() => _loading = true);
    try {
      await f();
    } catch (_) {
      // sem dados: a entrada mostra o que tiver
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run([String raw = '']) async {
    await widget.onRun(e, raw);
    if (mounted) setState(() {});
  }

  TextEditingController _field(String name, String initial) => _fields.putIfAbsent(name, () => TextEditingController(text: initial));

  bool get _enabled => e.enabled?.call() ?? true;

  DebugTone get _tone => e.destructive ? DebugTone.destructive : (e.touchesSave ? DebugTone.save : DebugTone.common);

  @override
  Widget build(BuildContext context) {
    final title = '${widget.prefix == null ? '' : '${widget.prefix} · '}${e.name}'.toUpperCase();
    final header = Row(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: KEspaco.s2),
          child: Text(title, style: e.kind == DebugKind.toggle ? KTexto.corpo : KTexto.rotulo),
        ),
      ),
      if (e.info != null) DebugInfoButton(key: Key('${e.id}.info'), open: _info, onTap: () => setState(() => _info = !_info)),
      DebugStar(key: Key('star-${e.id}'), on: widget.favorite, onTap: widget.onStar),
      if (e.kind == DebugKind.toggle) ...[
        DebugSwitch(value: e.read?.call() == 'on', onChanged: _enabled ? (v) => _run(v ? 'on' : 'off') : null),
        const SizedBox(width: KEspaco.s1),
      ],
    ]);
    final body = <Widget>[
      if (e.warn != null) DebugNote('ATENÇÃO: ${e.warn}', color: KCores.texto),
      if (_info && e.info != null) DebugNote(e.info!),
      if (e.status?.call() case final st?) DebugNote(st),
      ..._control(),
      if (e.extra != null) Builder(builder: e.extra!),
    ];
    return Container(
      key: Key(e.id),
      margin: const EdgeInsets.only(bottom: KEspaco.s2),
      decoration: BoxDecoration(
        color: KCores.superficie1,
        border: Border.all(color: widget.flash ? KCores.texto : KCores.contorno, width: kContornoDp),
        boxShadow: KSombra.pixel,
      ),
      child: Opacity(
        opacity: _enabled ? 1 : 0.5,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Alternar: a linha inteira liga e desliga (o (i) e a estrela respondem por cima).
          if (e.kind == DebugKind.toggle && _enabled)
            Pressable(onTap: () => _run(e.read?.call() == 'on' ? 'off' : 'on'), child: SizedBox(height: kToqueMinDp, child: header))
          else
            SizedBox(height: kToqueMinDp, child: header),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < body.length; i++) ...[if (i > 0) const SizedBox(height: KEspaco.s1), body[i]],
              ]),
            ),
        ]),
      ),
    );
  }

  List<Widget> _control() => switch (e.kind) {
        DebugKind.toggle => const [],
        DebugKind.choice => _choice(),
        DebugKind.number => [_slider(e.id, e.read?.call(), e.min ?? 0, e.max ?? 1, (v) => _run(v))],
        DebugKind.coord => _coord(),
        DebugKind.action => [..._params(), _runButton()],
        DebugKind.view => [_view()],
      };

  /// Sem valores ainda (o catálogo do clima, os dados da sintonia): o botão que carrega.
  Widget? _loadButton(List<DebugOption> values) => values.isEmpty && e.load != null
      ? Align(
          alignment: Alignment.centerLeft,
          child: DebugButton(key: Key('${e.id}.load'), label: _loading ? 'Carregando...' : 'Carregar', enabled: !_loading, onTap: _load),
        )
      : null;

  List<Widget> _choice() {
    final values = e.values;
    final now = e.read?.call() ?? '';
    final on = e.multi ? now.split(',').toSet() : {now};
    // Com algo fora do real e sem um valor que já seja o real ('auto'), o chip REAL desfaz.
    final real = e.offReal != null && !values.any((o) => o.value == 'auto' || o.value == 'real');
    final chips = [
      if (real) ('real', 'Real', e.offReal!() == null),
      for (final o in values) (o.value, o.label, on.contains(o.value)),
    ];
    return [
      if (chips.isNotEmpty)
        DebugGrid(
          columns: chipColumns(chips.map((c) => c.$2)),
          children: [for (final (v, label, isOn) in chips) DebugChip(label, key: Key('${e.id}=$v'), on: isOn, enabled: _enabled, onTap: () => _run(v))],
        ),
      ?_loadButton(values),
    ];
  }

  Widget _slider(String key, String? value, double min, double max, ValueChanged<String> done) {
    final v = _drag[key] ?? double.tryParse(value ?? '') ?? min;
    return Row(children: [
      Expanded(
        child: Slider(
          key: Key('$key.slider'),
          value: v.clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).round().clamp(1, 400),
          activeColor: KCores.veuVioleta,
          inactiveColor: KCores.linha,
          onChanged: _enabled ? (x) => setState(() => _drag[key] = x.roundToDouble()) : null,
          onChangeEnd: (x) {
            _drag.remove(key);
            done('${x.round()}');
          },
        ),
      ),
      SizedBox(width: 40, child: Text('${v.round()}', textAlign: TextAlign.right, style: KTexto.rotulo)),
    ]);
  }

  List<Widget> _coord() {
    final now = e.read?.call();
    final field = _field('coord', '');
    return [
      DebugGrid(
        columns: chipColumns(e.values.map((o) => o.label)),
        children: [
          for (final o in e.values)
            DebugChip(o.label, key: Key('${e.id}=${fold(o.label).replaceAll(' ', '')}'), on: o.value == now, enabled: _enabled, onTap: () => _run(o.value)),
        ],
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: DebugField('lat, lon', field, key: Key('${e.id}.field'), onSubmitted: (_) => _run(field.text))),
        const SizedBox(width: KEspaco.s1),
        DebugButton(key: Key('${e.id}.go'), label: 'Ir', minWidth: 64, enabled: _enabled, onTap: () => _run(field.text)),
      ]),
    ];
  }

  List<Widget> _params() => [
        for (final p in e.params) ...switch (p.kind) {
          DebugParamKind.choice => [
              Text(p.label.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
              if (p.values.isEmpty)
                ?_loadButton(p.values)
              else
                DebugGrid(
                  columns: chipColumns(p.values.map((o) => o.label)),
                  children: [
                    for (final o in p.values)
                      DebugChip(o.label, key: Key('${e.id}.${p.name}=${o.value}'), on: e.paramValue(p) == o.value, onTap: () => setState(() => e.form[p.name] = o.value)),
                  ],
                ),
            ],
          DebugParamKind.number => [
              Text(p.label.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
              _slider('${e.id}.${p.name}', e.paramValue(p), p.min ?? 0, p.max ?? 1, (v) => setState(() => e.form[p.name] = v)),
            ],
          DebugParamKind.toggle => [
              Row(children: [
                Expanded(child: Text(p.label, style: KTexto.corpo)),
                DebugSwitch(key: Key('${e.id}.${p.name}'), value: e.paramValue(p) == 'on', onChanged: (v) => setState(() => e.form[p.name] = v ? 'on' : 'off')),
              ]),
            ],
          DebugParamKind.text => [
              DebugField(p.label, _field(p.name, e.paramValue(p)), key: Key('${e.id}.${p.name}'), onChanged: (v) => e.form[p.name] = v.trim()),
            ],
        },
      ];

  Widget _runButton() => Align(
        alignment: Alignment.centerLeft,
        child: DebugButton(key: Key('${e.id}.run'), label: 'Executar', tone: _tone, minWidth: _tone == DebugTone.common ? 96 : 150, enabled: _enabled, onTap: _run),
      );

  Widget _view() {
    final groups = e.groups?.call();
    final text = e.readText() ?? '';
    final copy = DebugInfoCopy(key: Key('${e.id}.copy'), text: e.copy?.call() ?? text);
    if (groups == null) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: SelectableText(text, key: Key('${e.id}.text'), style: KTexto.corpoPequeno.copyWith(color: KCores.texto))),
        copy,
      ]);
    }
    // Linhas de rótulo e valor, por grupo; o copiar leva o bloco todo.
    return Column(key: Key('${e.id}.text'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, g) in groups.indexed) ...[
        Row(children: [
          Expanded(child: Text(g.title.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.textoMudo))),
          if (i == 0) copy,
        ]),
        for (final (k, v) in g.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Text(k, style: KTexto.corpoPequeno)),
              const SizedBox(width: KEspaco.s1),
              Expanded(flex: 3, child: Text(v, textAlign: TextAlign.right, style: KTexto.corpoPequeno.copyWith(color: KCores.texto))),
            ]),
          ),
        if (i < groups.length - 1) const SizedBox(height: KEspaco.s1),
      ],
    ]);
  }
}

/// Copia a leitura (o resumo, ou o que a entrada deixou para copiar).
class DebugInfoCopy extends StatelessWidget {
  const DebugInfoCopy({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Copiar',
        icon: const Icon(Icons.copy, size: 18, color: KCores.textoMudo),
        onPressed: () async {
          final say = debugSayer(context);
          await Clipboard.setData(ClipboardData(text: text));
          say('Copiado');
        },
      );
}
