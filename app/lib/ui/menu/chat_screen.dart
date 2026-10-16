/// O app Chat do celular (docs/GDD.md, "O mentor"): o contato de número desconhecido e as mensagens do tutorial.
/// As mensagens vêm de `assets/data/mentor.json`. Abrir a tela marca tudo como lido.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import 'screen_frame.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.state.markChatRead());
  }

  static String _time(int utc) {
    final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final script = widget.data.mentor;
        final chat = widget.state.story.chat;
        // Chegou mensagem com a tela aberta: já está lida (depois do quadro, para o ponto do celular apagar).
        if (chat.unread > 0) WidgetsBinding.instance.addPostFrameCallback((_) => widget.state.markChatRead());
        return ScreenFrame(
          title: 'Chat',
          subtitle: script.contactName,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: panelBox(),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kOutline, border: Border.all(color: kVeil, width: 2)),
                  child: const Text('?', style: TextStyle(fontSize: 24, color: kVeil)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(script.contactName.toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
                    if (script.contactNote.isNotEmpty) Text(script.contactNote.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (chat.delivered.isEmpty)
              const Text('NENHUMA MENSAGEM AINDA. ABRA O MAPA E ANDE UM POUCO: ALGUÉM ESTÁ OUVINDO.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
            for (final e in chat.delivered)
              if (script.byId(e.id) case final m?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: Key('chat-${m.id}'),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kPanel, border: Border.all(color: m.from == 'familiar' ? kSignal : kVeil, width: 2)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (m.from == 'familiar') const Text('FAMILIAR', style: TextStyle(fontSize: 8, color: kSignal)),
                      Text(m.text, style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
                      const SizedBox(height: 6),
                      Text(_time(e.utc), style: const TextStyle(fontSize: 8, color: kDim)),
                    ]),
                  ),
                ),
          ],
        );
      },
    );
  }
}
