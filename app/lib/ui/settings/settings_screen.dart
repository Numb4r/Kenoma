/// Ajustes (docs/fase0-spec.md, seção 9): o grupo (código, QR e entrar noutro), a época e o aviso de mundo
/// desatualizado, a versão e o player_id, os interruptores do mapa e o backup.
library;

import '../../core/features.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/seed.dart';
import '../../data/game_data.dart';
import '../../player/game_session.dart';
import '../../save/backup.dart';
import '../../save/backup_io.dart';
import '../../save/ksv1.dart';
import '../../story/local_notifier.dart';
import '../../story/notification_plan.dart';
import '../colors.dart';
import '../menu/screen_frame.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'qr_scan_screen.dart';

/// Abre a câmera e devolve o código de grupo lido, ou `null`.
typedef GroupScanner = Future<String?> Function(BuildContext context);

Future<String?> scanGroupWithCamera(BuildContext context) => Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.session,
    required this.data,
    required this.nowUtc,
    required this.realNowUtc,
    required this.appVersion,
    required this.cellSideM,
    required this.followHeading,
    required this.onFollowHeading,
    required this.onRestart,
    required this.notifier,
    this.io = const DeviceBackupIo(),
    this.scan = scanGroupWithCamera,
    super.key,
  });

  final GameSession session;
  final GameData data;

  /// O relógio do jogo (com o override do debug) e o real, em segundos UTC.
  final int Function() nowUtc;
  final int Function() realNowUtc;
  final String appVersion;

  /// O lado de uma célula z20 (~35 m) na latitude de agora, para a área revelada em km².
  final double Function() cellSideM;

  /// O "seguir direção" de agora, e como ligar e desligar.
  final bool Function() followHeading;
  final void Function(bool on) onFollowHeading;

  /// Recomeça o mapa com o save que está em disco (depois de importar um backup ou trocar de grupo).
  final Future<void> Function() onRestart;
  final BackupIo io;
  final GroupScanner scan;

  /// Quem agenda as notificações locais no sistema.
  final Notifier notifier;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _say(String text) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  static String _date(int utc) {
    final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<bool> _confirm(String title, String body, String yes, {Color color = kEssence}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPanel,
        shape: RoundedRectangleBorder(side: BorderSide(color: color, width: 3)),
        title: Text(title.toUpperCase(), style: TextStyle(fontSize: 16, color: color)),
        content: Text(body, style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR', style: TextStyle(fontSize: 8, color: kDim))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(yes.toUpperCase(), style: TextStyle(fontSize: 8, color: color))),
        ],
      ),
    );
    return ok == true;
  }

  /// Entrar noutro grupo: digitando o código ou escaneando o QR, sempre com confirmação.
  Future<void> _joinGroup() async {
    final field = TextEditingController();
    String? error;
    final code = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: kPanel,
          shape: const RoundedRectangleBorder(side: BorderSide(color: kSignal, width: 3)),
          title: const Text('ENTRAR NOUTRO GRUPO', style: TextStyle(fontSize: 16, color: kSignal)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: field,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(hintText: 'XXXXX-XXXXX', errorText: error),
            ),
            const SizedBox(height: 12),
            PixelButton(
              label: 'Escanear QR',
              color: kVeil,
              onTap: () async {
                final scanned = await widget.scan(context);
                if (scanned == null) return;
                setLocal(() {
                  field.text = scanned;
                  error = null;
                });
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR', style: TextStyle(fontSize: 8, color: kDim))),
            TextButton(
              onPressed: () {
                if (!isValidGroupCode(field.text)) {
                  setLocal(() => error = 'Use de 6 a 20 letras e números');
                } else {
                  Navigator.of(context).pop(formatGroupCode(field.text));
                }
              },
              child: const Text('ENTRAR', style: TextStyle(fontSize: 8, color: kSignal)),
            ),
          ],
        ),
      ),
    );
    if (code == null || !mounted) return;
    final state = widget.session.state;
    if (normalizeSeedCode(code) == normalizeSeedCode(state.groupCode)) {
      _say('Você já está nesse grupo');
      return;
    }
    final ok = await _confirm(
      'Trocar de grupo?',
      'Você passa a ver o mundo do grupo $code.\nO registro de coletas e as marcações são apagados.\nA coleção, o Círculo, a bolsa e o nível ficam.',
      'Trocar',
    );
    if (!ok || !mounted) return;
    state.changeGroup(code);
    await widget.session.flush();
    await widget.onRestart();
  }

  /// Liga ou desliga os avisos. Ligar pede a permissão na hora; se o jogador negar, o interruptor volta para desligado.
  Future<void> _setNotifications(bool on) async {
    final s = widget.session.state;
    if (!on) {
      s.setSetting('notifications', false);
      await widget.notifier.apply(const []);
      return;
    }
    final granted = await widget.notifier.requestPermission();
    if (!mounted) return;
    if (!granted) {
      _say('Sem a permissão do sistema não dá para avisar. Libere nas configurações do celular.');
      return;
    }
    s.setSetting('notifications', true);
    await widget.notifier.apply(planNotifications(enabled: true, nowUtc: widget.realNowUtc(), progress: s.progress, balance: s.balance));
  }

  Future<void> _export() async {
    final s = widget.session;
    await s.flush();
    try {
      await widget.io.share(exportBackup(s.state.toJson(widget.nowUtc())), backupFileName(widget.realNowUtc()));
    } catch (e) {
      if (mounted) _say('Não consegui exportar: $e');
    }
  }

  Future<void> _import() async {
    final bytes = await widget.io.pick();
    if (bytes == null || !mounted) return;
    final Map<String, dynamic> backup;
    try {
      backup = readBackup(bytes);
    } on SaveCorrupt catch (e) {
      _say('Esse arquivo não serve: ${e.reason}');
      return;
    }
    final p = previewBackup(backup);
    if (!mounted) return;
    final ok = await _confirm(
      'Substituir o jogo?',
      'BACKUP DE ${_date(p.savedUtc)}\nNÍVEL ${p.level} · ${p.creatures} CRIATURAS\nGRUPO ${p.groupCode}${p.appVersion.isEmpty ? '' : ' · VERSÃO ${p.appVersion}'}\n\nO jogo que está no aparelho agora será substituído por este.',
      'Importar',
    );
    if (!ok || !mounted) return;
    await widget.session.flush();
    widget.session.dispose(); // nada do jogo antigo grava por cima do que vai entrar
    await restoreBackup(widget.session.store, backup);
    await widget.onRestart();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final now = widget.nowUtc();
        final sel = widget.data.schedule.select(now);
        final id = s.founder?.playerId ?? '';
        return ScreenFrame(
          title: 'Ajustes',
          subtitle: 'Kenoma ${widget.appVersion}',
          children: [
            const SectionTitle('Grupo'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panelBox(),
              child: Column(children: [
                Text(s.groupCode, key: const Key('group-code'), style: const TextStyle(fontSize: 24, color: kText)),
                const SizedBox(height: 12),
                Container(
                  color: const Color(0xFFFFFFFF),
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(data: groupQrPayload(s.groupCode), size: 168, backgroundColor: const Color(0xFFFFFFFF)),
                ),
                const SizedBox(height: 8),
                const Text('QUEM ESCANEIA ESTE QR VÊ O MESMO MUNDO QUE VOCÊ.', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
              ]),
            ),
            const SizedBox(height: 8),
            PixelButton(label: 'Entrar noutro grupo', color: kSignal, onTap: _joinGroup),
            const SectionTitle('Época'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panelBox(line: sel.stale ? kEssence : kPanelLine),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ÉPOCA ${sel.epoch.id}', style: const TextStyle(fontSize: 16, color: kText)),
                const SizedBox(height: 4),
                Text('COMEÇOU EM ${_date(sel.epoch.startsUtc)}', style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
                Text('VALE ATÉ ${_date(sel.epoch.validUntilUtc)}', style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
                if (sel.stale)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('MUNDO DESATUALIZADO. ATUALIZE O APP: SEUS AMIGOS PODEM ESTAR EM OUTRA ÉPOCA.', style: TextStyle(fontSize: 8, color: kEssence, height: 1.8)),
                  ),
              ]),
            ),
            const SectionTitle('App'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panelBox(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VERSÃO ${widget.appVersion}', style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
                const SizedBox(height: 4),
                const Text('PLAYER_ID', style: TextStyle(fontSize: 8, color: kDim)),
                Text(id, key: const Key('player-id'), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
                const SizedBox(height: 8),
                PixelButton(
                  label: 'Copiar player_id',
                  color: kVeil,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: id));
                    if (mounted) _say('player_id copiado');
                  },
                ),
              ]),
            ),
            const SectionTitle('Mapa'),
            if (streetLifeEnabled)
            Container(
              key: const Key('fog-area'),
              padding: const EdgeInsets.all(12),
              decoration: panelBox(),
              child: Text(
                'ÁREA REVELADA: ${s.fog.areaKm2(widget.cellSideM()).toStringAsFixed(2)} KM² · ${s.fog.revealedCount} CÉLULAS',
                style: const TextStyle(fontSize: 8, color: kText, height: 1.8),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nomes de rua', style: TextStyle(fontSize: 8)),
              subtitle: const Text('Rótulos discretos nas ruas principais, que giram com o mapa', style: TextStyle(fontSize: 8, color: kDim)),
              value: s.setting('street_names'),
              activeThumbColor: kSignal,
              onChanged: (v) => s.setSetting('street_names', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tráfego do Véu', style: TextStyle(fontSize: 8)),
              subtitle: const Text('Carros e pedestres fantasmas nas ruas. Só visual', style: TextStyle(fontSize: 8, color: kDim)),
              value: s.settingOr('veil_traffic', true),
              activeThumbColor: kSignal,
              onChanged: (v) => s.setSetting('veil_traffic', v),
            ),
            if (streetLifeEnabled) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chuva no mapa', style: TextStyle(fontSize: 8)),
              subtitle: const Text('Gotas em pixels quando chove. Só visual', style: TextStyle(fontSize: 8, color: kDim)),
              value: s.settingOr('rain_fx', true),
              activeThumbColor: kSignal,
              onChanged: (v) => s.setSetting('rain_fx', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Clima pela internet', style: TextStyle(fontSize: 8)),
              subtitle: const Text('Mostra o clima real (Open-Meteo, posição arredondada a ~1 km). Só visual: os spawns usam o clima da seed', style: TextStyle(fontSize: 8, color: kDim)),
              value: s.setting('weather_online'),
              activeThumbColor: kSignal,
              onChanged: (v) => s.setSetting('weather_online', v),
            ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seguir direção', style: TextStyle(fontSize: 8)),
              subtitle: const Text('O mapa gira com a bússola do celular', style: TextStyle(fontSize: 8, color: kDim)),
              value: widget.followHeading(),
              activeThumbColor: kSignal,
              onChanged: (v) {
                widget.onFollowHeading(v);
                setState(() {});
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisos no celular', style: TextStyle(fontSize: 8)),
              subtitle: const Text('Diárias renovadas e descanso cheio, às 9 h. Desligado por padrão', style: TextStyle(fontSize: 8, color: kDim)),
              value: s.setting('notifications'),
              activeThumbColor: kSignal,
              onChanged: _setNotifications,
            ),
            const SectionTitle('Backup'),
            const Text('O backup é o seu jogo inteiro num arquivo. Mande para o Google Drive ou para si mesmo.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
            const SizedBox(height: 8),
            PixelButton(label: 'Exportar backup', color: kSignal, onTap: _export),
            const SizedBox(height: 8),
            PixelButton(label: 'Importar backup', color: kEssence, onTap: _import),
          ],
        );
      },
    );
  }
}
