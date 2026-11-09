/// "Criar criatura" (seção Spawns): o formulário que faz nascer na Aura uma criatura do jeito pedido. O que nasce vive fora
/// do mundo determinístico (`world/debug_creatures.dart`) e não conta para o bestiário nem para as estatísticas. O último
/// formulário fica nas preferências do menu, com o botão "repetir".
library;

import 'package:flutter/material.dart';

import '../capture/eco_type.dart';
import '../core/behavior.dart';
import '../data/tuning_data.dart';
import '../ui/tema.dart';
import '../ui/type_label.dart';
import '../world/debug_creatures.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

/// As espécies Eco candidatas do [spec]: a escolhida, ou todas as Eco do tipo. Só as que existem nos dados.
List<String> debugCandidates(DebugCreatureSpec spec, List<EcoSpecies> species) => [
      for (final s in species)
        if (s.tier == 'eco' && !s.ritualOnly && (spec.speciesId != null ? s.id == spec.speciesId : s.type.name == spec.type)) s.id,
    ];

List<DebugItem> creatureItems(DebugEnv env) => [
      DebugItem(
        id: 'spawn.create',
        title: 'Criar criatura',
        section: DebugSection.spawns,
        keywords: const ['criar', 'criatura', 'eco', 'espírito', 'nível', 'brilhante', 'carmesim', 'variante', 'aura', 'repetir', 'spawn'],
        builder: (_) => _CreateCreature(env: env),
      ),
    ];

class _CreateCreature extends StatefulWidget {
  const _CreateCreature({required this.env});

  final DebugEnv env;

  @override
  State<_CreateCreature> createState() => _CreateCreatureState();
}

class _CreateCreatureState extends State<_CreateCreature> {
  final _search = TextEditingController();
  late final Future<TuningData> _data = TuningData.load();
  late DebugCreatureSpec _spec = _saved ?? const DebugCreatureSpec();
  static DebugCreatureSpec? _memory; // sem preferências em disco (testes), o "repetir" vale até fechar o app

  DebugCreatureSpec? get _saved {
    final j = widget.env.prefs?.creatureForm;
    return j == null ? _memory : DebugCreatureSpec.fromJson(j);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(DebugCreatureSpec Function(DebugCreatureSpec s) f) => setState(() => _spec = f(_spec));

  DebugCreatureSpec _copy({String? speciesId, String? type, bool clearSpecies = false, bool? spirit, int? level, bool? shiny, DebugVariant? variant, EcoBehavior? behavior, int? count}) =>
      DebugCreatureSpec(
        speciesId: clearSpecies ? null : speciesId ?? (type != null ? null : _spec.speciesId),
        type: speciesId != null ? null : type ?? _spec.type,
        spirit: spirit ?? _spec.spirit,
        level: level ?? _spec.level,
        shiny: shiny ?? _spec.shiny,
        variant: variant ?? _spec.variant,
        behavior: behavior ?? _spec.behavior,
        count: count ?? _spec.count,
      );

  void _create(DebugCreatureSpec spec, List<EcoSpecies> species) {
    final ids = debugCandidates(spec, species);
    if (ids.isEmpty) return debugSnack(context, 'Escolha uma espécie ou um tipo.');
    widget.env.tools.force.creatures.request(spec, ids);
    _memory = spec;
    widget.env.prefs?.setCreatureForm(spec.toJson());
    setState(() {});
    debugSnack(context, '${spec.count} na fila: nascem na Aura na próxima atualização do mapa (20 min ou até a captura).');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TuningData>(
        future: _data,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return DebugNote(snap.hasError ? 'Erro: ${snap.error}' : 'Carregando as espécies...');
          final ecos = [for (final s in d.species) if (s.tier == 'eco' && !s.ritualOnly) s];
          final types = [for (final t in EcoType.values) if (ecos.any((s) => s.type == t)) t]; // só os tipos que têm espécie
          final q = _search.text.trim().toLowerCase();
          final shown = [for (final s in ecos) if (q.isEmpty || s.name.toLowerCase().contains(q) || s.id.contains(q)) s];
          final last = _saved;
          return DebugColumn([
            const DebugNote('Nasce na Aura com a costura, fora do mundo do grupo. Fica 20 minutos ou até ser capturada, marcada como debug: não conta para o bestiário nem para as estatísticas.'),
            DebugField('Buscar espécie', _search, onChanged: (_) => setState(() {})),
            DebugWrap([
              for (final s in shown) DebugChip(s.name, on: _spec.speciesId == s.id, onTap: () => _set((_) => _copy(speciesId: s.id))),
            ]),
            Text('OU SÓ O TIPO (SORTEIA A ESPÉCIE)', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
            DebugWrap([
              for (final t in types) DebugChip(typeLabel(t), on: _spec.speciesId == null && _spec.type == t.name, onTap: () => _set((_) => _copy(type: t.name, clearSpecies: true))),
            ]),
            DebugWrap([
              DebugChip('Eco', on: !_spec.spirit, onTap: () => _set((_) => _copy(spirit: false))),
              DebugChip('Espírito', on: _spec.spirit, color: KCores.veuVioleta, onTap: () => _set((_) => _copy(spirit: true))),
            ]),
            Text('NÍVEL ${_spec.level}', style: KTexto.rotulo),
            Slider(value: _spec.level.toDouble(), min: 1, max: 40, divisions: 39, label: '${_spec.level}', activeColor: KCores.sinalCiano, onChanged: (v) => _set((_) => _copy(level: v.round()))),
            const DebugNote('Acima do teto da camada (Eco 20, Espírito 30), a sintonia usa o teto.'),
            DebugSwitch(title: 'Brilhante', value: _spec.shiny, onChanged: (v) => _set((_) => _copy(shiny: v))),
            DebugWrap([for (final v in DebugVariant.values) DebugChip(v.label, on: _spec.variant == v, color: KCores.brasaLaranja, onTap: () => _set((_) => _copy(variant: v)))]),
            DebugWrap([for (final b in EcoBehavior.values) DebugChip(b.label, on: _spec.behavior == b, color: KCores.brasaLaranja, onTap: () => _set((_) => _copy(behavior: b)))]),
            Text('QUANTIDADE ${_spec.count}', style: KTexto.rotulo),
            Slider(value: _spec.count.toDouble(), min: 1, max: 10, divisions: 9, label: '${_spec.count}', activeColor: KCores.sinalCiano, onChanged: (v) => _set((_) => _copy(count: v.round()))),
            DebugWrap([
              DebugButton(label: 'Criar na Aura', color: KCores.sinalCiano, onTap: () => _create(_spec, d.species)),
              DebugButton(
                label: 'Repetir',
                color: KCores.textoMudo,
                enabled: last != null,
                onTap: () {
                  if (last == null) return;
                  setState(() => _spec = last);
                  _create(last, d.species);
                },
              ),
            ]),
            if (widget.env.tools.force.creatures.pending > 0) DebugNote('${widget.env.tools.force.creatures.pending} esperando o mapa.'),
          ]);
        },
      );
}
