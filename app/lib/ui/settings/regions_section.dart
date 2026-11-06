/// Seção "Baixar região" dos Ajustes: as regiões do catálogo, o estado, o tamanho e o botão.
library;

import 'package:flutter/material.dart';

import '../../net/region_catalog.dart';
import '../../net/region_manager.dart';
import '../colors.dart';
import '../menu/screen_frame.dart';
import '../tuning/tuning_screen.dart' show PixelButton;

/// Tamanho em MB, como o aviso de confirmação mostra.
String regionSizeLabel(int bytes) => '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';

class RegionsSection extends StatefulWidget {
  const RegionsSection({required this.manager, super.key});

  final RegionManager manager;

  @override
  State<RegionsSection> createState() => _RegionsSectionState();
}

class _RegionsSectionState extends State<RegionsSection> {
  @override
  void initState() {
    super.initState();
    widget.manager.refreshCatalog(force: widget.manager.catalog == null);
  }

  static String _label(RegionStatus s) => switch (s) {
        RegionStatus.available => 'NÃO BAIXADA',
        RegionStatus.downloading => 'BAIXANDO...',
        RegionStatus.ready => 'PRONTA',
        RegionStatus.failed => 'FALHOU',
        RegionStatus.blocked => 'FORA DESTA ÉPOCA',
      };

  Widget _row(RegionEntry r) {
    final status = widget.manager.statusOf(r);
    return Container(
      key: Key('region-${r.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: panelBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.name.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        Text('${_label(status)} · ${regionSizeLabel(r.totalBytes)}', style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
        if (status == RegionStatus.available || status == RegionStatus.failed) ...[
          const SizedBox(height: 8),
          PixelButton(label: 'Baixar região', color: kSignal, onTap: () => widget.manager.download(r)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.manager,
        builder: (context, _) {
          final regions = widget.manager.catalog?.regions ?? const <RegionEntry>[];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Baixar região'),
            if (regions.isEmpty) const Text('SEM LISTA DE REGIÕES. PRECISA DE INTERNET.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
            for (final r in regions) _row(r),
          ]);
        },
      );
}
