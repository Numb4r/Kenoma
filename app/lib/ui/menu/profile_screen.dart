/// O app Perfil: nome, nível e XP, escola e Familiar, estatísticas, época e grupo, certificados. Só desenha o que
/// `profile_stats.dart` e o estado dizem.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/features.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../player/profile_stats.dart';
import '../sprites/familiar_sprite.dart';
import '../tema.dart';
import 'phone_shell.dart';
import 'profile_widgets.dart';

/// A chave em `settings` com os pontos de talento que o jogador já viu no Perfil (a bolinha do app lê daqui).
const String kProfileSeenTalentKey = 'profile_seen_talent';

class ProfileScreen extends StatefulWidget {
  /// [nowUtc] é o relógio do jogo (padrão: o real); [cellSideM] dá o lado da célula z20 para a área revelada (sem ele a
  /// área não aparece); [onOpenSettings] abre os Ajustes (sem ele o atalho do grupo não aparece).
  const ProfileScreen({required this.state, required this.data, this.nowUtc, this.cellSideM, this.onOpenSettings, super.key});

  final GameState state;
  final GameData data;
  final int Function()? nowUtc;
  final double Function()? cellSideM;
  final VoidCallback? onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  GameState get s => widget.state;
  Future<ui.Image>? _familiar;

  @override
  void initState() {
    super.initState();
    _markTalentSeen();
  }

  /// Ver o Perfil apaga a bolinha. Guarda o saldo visto (e acompanha quando ele cai).
  void _markTalentSeen() {
    final n = s.conjurer.talentAvailable;
    if (s.settings[kProfileSeenTalentKey] != n) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.setSetting(kProfileSeenTalentKey, n));
    }
  }

  Future<void> _editName() async {
    final ctl = TextEditingController(text: s.conjurer.playerName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KCores.superficie1,
        shape: const RoundedRectangleBorder(side: BorderSide(color: KCores.contorno, width: kContornoDp)),
        title: Text('NOME DO CONJURADOR', style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
        content: TextField(
          key: const Key('profile-name-field'),
          controller: ctl,
          autofocus: true,
          maxLength: kPlayerNameMax,
          style: KTexto.corpo,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\p{L}\p{N} ]', unicode: true))],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(key: const Key('profile-name-ok'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) s.setPlayerName(sanitizeName(ctl.text));
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.nowUtc?.call() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return PhoneScreen(
      title: 'Perfil',
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          _markTalentSeen();
          final certs = certificateIds(s.founder);
          return ListView(padding: const EdgeInsets.all(KEspaco.s2), children: [
            _name(),
            _level(),
            _school(),
            _stats(),
            _epoch(now),
            if (certs.isNotEmpty) _certificates(certs),
          ]);
        },
      ),
    );
  }

  Widget _name() => ProfilePanel(
        title: 'Conjurador',
        child: GestureDetector(
          key: const Key('profile-name'),
          behavior: HitTestBehavior.opaque,
          onTap: _editName,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kToqueMinDp),
            child: Row(children: [
              Expanded(child: Text(s.conjurer.displayName, style: KTexto.titulo, overflow: TextOverflow.ellipsis)),
              Text('EDITAR', style: KTexto.rotulo.copyWith(color: KCores.sinalCiano)),
            ]),
          ),
        ),
      );

  Widget _level() {
    final p = s.progress;
    final daily = p.balance.restDailyDoubled;
    return ProfilePanel(
      title: 'Nível',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${p.level}', key: const Key('profile-level'), style: KTexto.display),
          const SizedBox(width: KEspaco.s2),
          Expanded(
            child: Text(p.atCap ? 'Nível máximo (${p.balance.playerLevelCap})' : '${p.xp} / ${p.toNext} XP', key: const Key('profile-xp'), style: KTexto.corpo),
          ),
        ]),
        const SizedBox(height: KEspaco.s1),
        XpBar(fraction: p.fraction),
        const SizedBox(height: KEspaco.s1),
        Text(
          'Descanso: ${p.restBalance} XP rendem o dobro (${daysLabel(restDays(p.restBalance, daily))}; +$daily por dia).',
          key: const Key('profile-rest'),
          style: KTexto.corpoPequeno,
        ),
      ]),
    );
  }

  Widget _school() {
    final school = s.conjurer.school;
    _familiar ??= loadFamiliarImage(school: school);
    return ProfilePanel(
      title: 'Escola',
      child: Row(children: [
        FutureBuilder<ui.Image>(
          future: _familiar,
          builder: (_, snap) => SizedBox(
            width: 72,
            height: 72,
            child: snap.hasData ? RawImage(image: snap.data, fit: BoxFit.contain, filterQuality: FilterQuality.none) : null,
          ),
        ),
        const SizedBox(width: KEspaco.s2),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(schoolLabel(school), key: const Key('profile-school'), style: KTexto.titulo),
            if (school == null && s.canChooseSchool) Text('Os testes da escola esperam no Chat.', key: const Key('profile-school-hint'), style: KTexto.corpoPequeno),
            const SizedBox(height: KEspaco.s1),
            Text('Pontos de talento: ${s.conjurer.talentAvailable}', key: const Key('profile-talent'), style: KTexto.corpo),
            Text('Ficam guardados. As árvores de talento chegam numa versão futura.', style: KTexto.corpoPequeno),
          ]),
        ),
      ]),
    );
  }

  Widget _stats() {
    final cell = widget.cellSideM;
    return ProfilePanel(
      title: 'Estatísticas',
      child: Wrap(spacing: KEspaco.s2, runSpacing: KEspaco.s2, children: [
        StatTile('Andados', formatKm(s.story.count('walk_m'))),
        StatTile('Capturas', '${s.story.count('capture')}'),
        StatTile('Espécies', '${speciesRegistered(s.bestiary)}'),
        StatTile('Fagulhas', '${s.story.count('spark')}'),
        StatTile('Fusões', '${s.conjurer.fusions}'),
        StatTile('Dias jogados', '${s.conjurer.daysPlayed.length}'),
        if (streetLifeEnabled && cell != null) StatTile('Área revelada', formatKm2(s.fog.areaKm2(cell()))),
      ]),
    );
  }

  Widget _epoch(int now) {
    final epoch = widget.data.schedule.select(now).epoch;
    return ProfilePanel(
      title: 'Época e grupo',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Época ${epoch.id}, desde ${formatDate(epoch.startsUtc)}.', key: const Key('profile-epoch'), style: KTexto.corpo),
        const SizedBox(height: KEspaco.s1),
        Text('GRUPO', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
        Text(s.groupCode, key: const Key('profile-group'), style: KTexto.titulo),
        if (widget.onOpenSettings != null)
          GestureDetector(
            key: const Key('profile-share-seed'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpenSettings,
            child: SizedBox(
              height: kToqueMinDp,
              child: Align(alignment: Alignment.centerLeft, child: Text('COMPARTILHAR SEED >', style: KTexto.rotulo.copyWith(color: KCores.sinalCiano))),
            ),
          ),
      ]),
    );
  }

  Widget _certificates(List<String> ids) => ProfilePanel(
        title: 'Certificados',
        child: Wrap(spacing: KEspaco.s2, runSpacing: KEspaco.s2, children: [
          for (final id in ids)
            if (id == 'founder') const Seal(key: Key('seal-founder'), rows: founderSealRows, label: 'Fundador'),
        ]),
      );
}
