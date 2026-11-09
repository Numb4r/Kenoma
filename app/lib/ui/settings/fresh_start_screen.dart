/// A tela do Recomeçar do zero: o que vai ser apagado e o que fica, exportar o backup antes e a palavra RECOMEÇAR para
/// liberar o botão. Só desenha: quem apaga é `save/fresh_start.dart`.
library;

import 'package:flutter/material.dart';

import '../../save/fresh_start.dart' show kFreshStartWord;
import '../colors.dart';
import '../menu/screen_frame.dart';
import '../tuning/tuning_screen.dart' show PixelButton;

class FreshStartScreen extends StatefulWidget {
  const FreshStartScreen({required this.onExport, required this.onConfirm, super.key});

  /// Exporta o backup (o mesmo botão dos Ajustes).
  final Future<void> Function() onExport;

  /// Apaga e reabre o jogo.
  final Future<void> Function() onConfirm;

  @override
  State<FreshStartScreen> createState() => _FreshStartScreenState();
}

const _erased = [
  'Conjurador: nível, XP, escola e talentos',
  'Criaturas, Círculo e Bolsa',
  'Bestiário e pesquisa de rituais',
  'Chat, diárias e o registro de coletas',
  'Células visitadas e o diário da Patrulha',
  'Caches do mapa',
];

const _kept = [
  'O seu player_id e o log de versões',
  'Os certificados de fundador e de evento',
  'O grupo e os Ajustes do aparelho',
  'Os pacotes de região baixados',
];

class _FreshStartScreenState extends State<FreshStartScreen> {
  final _word = TextEditingController();
  bool _busy = false;

  bool get _ready => _word.text.trim().toUpperCase() == kFreshStartWord;

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_ready || _busy) return;
    setState(() => _busy = true);
    await widget.onConfirm();
  }

  Widget _list(List<String> lines, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: panelBox(line: color),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in lines) Text('· ${l.toUpperCase()}', style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        ]),
      );

  @override
  Widget build(BuildContext context) => ScreenFrame(
        title: 'Recomeçar do zero',
        subtitle: 'Sem volta',
        children: [
          const SectionTitle('Vai ser apagado'),
          _list(_erased, kEssence),
          const SectionTitle('Fica'),
          _list(_kept, kSignal),
          const SizedBox(height: 12),
          const Text('Quer guardar o jogo de agora? Exporte o backup antes.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
          const SizedBox(height: 8),
          PixelButton(label: 'Exportar backup', color: kSignal, onTap: widget.onExport),
          const SizedBox(height: 16),
          const Text('Digite $kFreshStartWord para liberar o botão.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
          TextField(
            key: const Key('fresh-start-word'),
            controller: _word,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(hintText: kFreshStartWord),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: _ready && !_busy ? 1 : 0.4,
            child: PixelButton(key: const Key('fresh-start-go'), label: _busy ? 'Apagando...' : 'Recomeçar do zero', color: kEssence, onTap: _confirm),
          ),
        ],
      );
}
