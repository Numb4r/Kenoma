/// Peças visuais do menu de debug no tema novo (`ui/tema.dart`): botão, chip, campo, nota e aviso. Os itens só montam
/// estas peças; nenhuma regra mora aqui.
library;

import 'package:flutter/material.dart';

import '../ui/pressable.dart';
import '../ui/tema.dart';

/// Botão de pixel: superfície 2, contorno de 3 dp, sombra dura; afunda 2 dp ao toque (`Pressable`). Desabilitado
/// fica apagado e não responde.
class DebugButton extends StatelessWidget {
  const DebugButton({required this.label, required this.onTap, this.color = KCores.veuVioleta, this.enabled = true, super.key});

  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: enabled ? onTap : null,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: kToqueMinDp, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2, vertical: KEspaco.s1),
            decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: color, width: kContornoDp), boxShadow: KSombra.pixel),
            child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: color)),
          ),
        ),
      );
}

/// Opção de uma escolha (comportamento, velocidade, clima): contorno na cor quando ligada.
class DebugChip extends StatelessWidget {
  const DebugChip(this.label, {required this.on, required this.onTap, this.color = KCores.sinalCiano, super.key});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: kToqueMinDp),
          padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2, vertical: KEspaco.s1),
          decoration: BoxDecoration(color: on ? KCores.superficie2 : KCores.fundo, border: Border.all(color: on ? color : KCores.contorno, width: kContornoDp)),
          child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: on ? color : KCores.textoMudo)),
        ),
      );
}

/// Interruptor com título e frase de apoio.
class DebugSwitch extends StatelessWidget {
  const DebugSwitch({required this.title, required this.value, required this.onChanged, this.subtitle, this.color = KCores.veuVioleta, super.key});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: KTexto.corpo),
        subtitle: subtitle == null ? null : Text(subtitle!, style: KTexto.corpoPequeno),
        value: value,
        activeThumbColor: color,
        onChanged: onChanged,
      );
}

/// Campo de texto de cantos retos e contorno de 3 dp.
class DebugField extends StatelessWidget {
  const DebugField(this.label, this.controller, {this.numeric = false, this.onChanged, super.key});

  final String label;
  final TextEditingController controller;
  final bool numeric;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
        style: KTexto.corpo,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: KTexto.corpoPequeno,
          isDense: true,
          contentPadding: const EdgeInsets.all(KEspaco.s2),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: KCores.contorno, width: kContornoDp), borderRadius: BorderRadius.zero),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: KCores.sinalCiano, width: kContornoDp), borderRadius: BorderRadius.zero),
        ),
      );
}

/// Frase de apoio, em Pixelify Sans mudo.
class DebugNote extends StatelessWidget {
  const DebugNote(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text, style: KTexto.corpoPequeno.copyWith(color: color));
}

/// Lista vertical de blocos com 12 dp entre eles: o corpo de quase todo item.
class DebugColumn extends StatelessWidget {
  const DebugColumn(this.children, {super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: KEspaco.s2), children[i]]],
      );
}

/// Linha com [Wrap] de 12 dp.
class DebugWrap extends StatelessWidget {
  const DebugWrap(this.children, {super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: KEspaco.s1, runSpacing: KEspaco.s1, children: children);
}

void debugSnack(BuildContext context, String text) => debugSayer(context)(text);

/// Pega o aviso antes de um `await`: depois dele o [context] pode ter saído da árvore, o aviso não.
void Function(String) debugSayer(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  return (text) => messenger.showSnackBar(SnackBar(content: Text(text)));
}
