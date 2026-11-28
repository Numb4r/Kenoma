/// Peças visuais do menu de debug (0.26.6, spec do criativo): cor com significado e igual em todo o menu.
/// - Violeta: escolhido ou ligado (chip preenchido, interruptor, aba ativa).
/// - Ciano: fora do real (a faixa do topo e o ponto nas abas e favoritos).
/// - Laranja: mexe no save, sempre com a tira "MEXE NO SAVE".
/// - Vermelho: destrutivo, sempre com a tira e com confirmação.
/// - Ação comum: neutra, em relevo (`superficie2`, sombra dura).
/// Nenhuma regra mora aqui; quem decide o que cada controle faz é o registro.
library;

import 'package:flutter/material.dart';

import '../ui/kit.dart' show KitAlertDialog, KitSwitch;
import '../ui/pressable.dart';
import '../ui/tema.dart';

/// O que um botão faz com o jogo: a cor e a tira.
enum DebugTone { common, save, destructive }

/// Botão de ação: comum (neutro, em relevo), mexe no save (aro e tira laranja) ou destrutivo (aro e tira vermelha).
/// 48 dp de rótulo; a tira soma 15. Desabilitado fica apagado e não responde.
class DebugButton extends StatelessWidget {
  const DebugButton({required this.label, required this.onTap, this.tone = DebugTone.common, this.enabled = true, this.minWidth = 96, super.key});

  final String label;
  final VoidCallback onTap;
  final DebugTone tone;
  final bool enabled;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final (line, text, tag) = switch (tone) {
      DebugTone.common => (KCores.contorno, KCores.texto, null),
      DebugTone.save => (KCores.brasaLaranja, KCores.brasaLaranja, 'MEXE NO SAVE'),
      DebugTone.destructive => (KCores.falha, KCores.falha, 'APAGA: PEDE CONFIRMAÇÃO'),
    };
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: line, width: kContornoDp), boxShadow: KSombra.pixel),
          child: IntrinsicWidth(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: kToqueMinDp - 2 * kContornoDp),
              padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
              child: Text(label.toUpperCase(), textAlign: TextAlign.center, style: KTexto.rotulo.copyWith(color: text)),
            ),
            if (tag != null)
              Container(
                height: 15,
                alignment: Alignment.center,
                color: line,
                child: FittedBox(child: Text(tag, style: KTexto.rotulo.copyWith(color: KCores.contorno, letterSpacing: 0, fontSize: 10))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Uma opção de uma escolha: preenchida de violeta quando escolhida, plana e de contorno fraco quando não. Sem sombra.
class DebugChip extends StatelessWidget {
  const DebugChip(this.label, {required this.on, required this.onTap, this.enabled = true, super.key});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: enabled ? onTap : null,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: kToqueMinDp),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: on ? KCores.veuVioleta : KCores.fundo,
              border: Border.all(color: on ? KCores.contorno : KCores.linha, width: kContornoDp),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label.toUpperCase(), maxLines: 1, style: KTexto.rotulo.copyWith(color: on ? KCores.contorno : KCores.textoMudo)),
            ),
          ),
        ),
      );
}

/// Colunas da grade de chips pelo maior rótulo do grupo: até 5 letras, 4; até 8, 3; maior, 2. Nunca uma só.
int chipColumns(Iterable<String> labels) {
  final longest = labels.fold<int>(0, (m, l) => l.length > m ? l.length : m);
  return longest <= 5 ? 4 : (longest <= 8 ? 3 : 2);
}

/// Grade de chips (ou de botões) com [columns] colunas e vão de 6 dp.
class DebugGrid extends StatelessWidget {
  const DebugGrid({required this.columns, required this.children, super.key});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - KEspaco.s1 * (columns - 1)) / columns;
        return Wrap(spacing: KEspaco.s1, runSpacing: KEspaco.s1, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}

/// O (i): fechado, contorno mudo; aberto, cheio e claro (muda a forma, não só a cor). Área de 48 dp.
class DebugInfoButton extends StatelessWidget {
  const DebugInfoButton({required this.open, required this.onTap, super.key});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: SizedBox(
          width: kToqueMinDp,
          height: kToqueMinDp,
          child: Icon(open ? Icons.info : Icons.info_outline, size: 18, color: open ? KCores.texto : KCores.textoMudo),
        ),
      );
}

/// A estrela de favorito: cheia em `texto`, vazia em `textoMudo`. Área de 48 dp.
class DebugStar extends StatelessWidget {
  const DebugStar({required this.on, required this.onTap, super.key});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: SizedBox(
          width: kToqueMinDp,
          height: kToqueMinDp,
          child: Icon(on ? Icons.star : Icons.star_border, size: 18, color: on ? KCores.texto : KCores.textoMudo),
        ),
      );
}

/// O interruptor do kit (ligado em violeta), apagado quando não dá para usar.
class DebugSwitch extends StatelessWidget {
  const DebugSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => KitSwitch(value: value, onChanged: onChanged);
}

/// O chip da faixa "fora do real": aro e texto ciano, 36 dp visíveis em 48 de toque, e a caixa do × à direita. O chip
/// inteiro desfaz.
class DebugOverrideChip extends StatelessWidget {
  const DebugOverrideChip(this.label, {required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            height: 36,
            decoration: BoxDecoration(color: KCores.fundo, border: Border.all(color: KCores.sinalCiano, width: kContornoDp)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KEspaco.s1),
                child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.sinalCiano)),
              ),
              Container(width: kContornoDp, color: KCores.sinalCiano),
              const SizedBox(width: 27, child: Icon(Icons.close, size: 18, color: KCores.sinalCiano)),
            ]),
          ),
        ),
      );
}

/// O ponto ciano de 6 dp: algo fora do real lá dentro (numa aba ou num favorito).
class DebugDot extends StatelessWidget {
  const DebugDot({super.key});

  @override
  Widget build(BuildContext context) => Container(width: 6, height: 6, color: KCores.sinalCiano);
}

/// Campo de texto de cantos retos e contorno de 3 dp.
class DebugField extends StatelessWidget {
  const DebugField(this.label, this.controller, {this.numeric = false, this.onChanged, this.onSubmitted, super.key});

  final String label;
  final TextEditingController controller;
  final bool numeric;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
        style: KTexto.corpo,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: KTexto.corpoPequeno,
          isDense: true,
          contentPadding: const EdgeInsets.all(KEspaco.s2),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: KCores.linha, width: kContornoDp), borderRadius: BorderRadius.zero),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: KCores.texto, width: kContornoDp), borderRadius: BorderRadius.zero),
        ),
      );
}

/// Frase de apoio, em Pixelify Sans mudo.
class DebugNote extends StatelessWidget {
  const DebugNote(this.text, {this.color, this.maxLines, super.key});

  final String text;
  final Color? color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: KTexto.corpoPequeno.copyWith(color: color));
}

void debugSnack(BuildContext context, String text) => debugSayer(context)(text);

/// Pega o aviso antes de um `await`: depois dele o [context] pode ter saído da árvore, o aviso não.
void Function(String) debugSayer(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  return (text) => messenger?.showSnackBar(SnackBar(content: Text(text)));
}

/// A confirmação do destrutivo: título, o que some e o botão que repete o verbo, preenchido de vermelho. Com [word], o
/// botão só libera depois de digitar a palavra. Voltar cancela.
Future<bool> debugConfirm(BuildContext context, {required String title, required String body, required String confirm, String? word}) async =>
    await showDialog<bool>(context: context, builder: (_) => _ConfirmDialog(title: title, body: body, confirm: confirm, word: word)) ?? false;

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.title, required this.body, required this.confirm, this.word});

  final String title, body, confirm;
  final String? word;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final open = word == null || _typed.text == word;
    return KitAlertDialog(
      title: Text(widget.title.toUpperCase(), style: KTexto.rotulo),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.body, style: KTexto.corpo),
        if (word != null) ...[
          const SizedBox(height: KEspaco.s2),
          DebugField('Digite $word', _typed, key: const Key('debug-confirm-word'), onChanged: (_) => setState(() {})),
        ],
      ]),
      actions: [
        DebugButton(key: const Key('debug-confirm-cancel'), label: 'Cancelar', onTap: () => Navigator.pop(context, false)),
        Opacity(
          opacity: open ? 1 : 0.4,
          child: Pressable(
            key: const Key('debug-confirm-ok'),
            onTap: open ? () => Navigator.pop(context, true) : null,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: kToqueMinDp, minWidth: 96),
              padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
              decoration: BoxDecoration(color: KCores.falha, border: Border.all(color: KCores.contorno, width: kContornoDp), boxShadow: KSombra.pixel),
              child: Text(widget.confirm.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.contorno)),
            ),
          ),
        ),
      ],
    );
  }
}
