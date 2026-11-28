import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/debug_widgets.dart';
import 'package:kenoma/ui/game/compass_button.dart';
import 'package:kenoma/ui/game/hud_bar.dart';
import 'package:kenoma/ui/game/hud_layout.dart';
import 'package:kenoma/ui/kit.dart';
import 'package:kenoma/ui/menu/bestiary/bestiary_widgets.dart';
import 'package:kenoma/ui/menu/phone_menu.dart';
import 'package:kenoma/ui/tuning/tuning_screen.dart' show PixelButton;

/// 0.26.0: todo alvo de toque do HUD e do kit tem pelo menos 48 × 48 dp (a área que responde, não o desenho).
void main() {
  Future<Size> sizeOf(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: UnconstrainedBox(child: KeyedSubtree(key: const Key('alvo'), child: w))))));
    return tester.getSize(find.byKey(const Key('alvo')));
  }

  final targets = <String, Widget>{
    'botão do celular': PhoneButton(onTap: () {}),
    'bússola': CompassButton(angle: 0.3, follow: false, onNorth: () {}, onToggleFollow: () {}),
    'atalho temporário (na faixa)': SizedBox(height: HudSize.strip, width: 120, child: ShortcutChip(label: 'PATRULHA', color: Colors.white, onTap: () {})),
    'interruptor': KitSwitch(value: true, onChanged: (_) {}),
    'linha com interruptor': SizedBox(width: 300, child: KitSwitchTile(title: const Text('X'), value: false, onChanged: (_) {})),
    'botão': PixelButton(label: 'OK', onTap: () {}),
    'botão do sistema': KButton(label: 'OK', onTap: () {}),
    'ficha de filtro': KChip(label: 'FOGO', on: true, onTap: () {}),
    'abas': SizedBox(width: 300, child: KTabs(labels: const ['A', 'B'], index: 0, onTap: (_) {})),
    'segmento': SizedBox(width: 300, child: KSegment(labels: const ['A', 'B'], index: 0, onTap: (_) {})),
    // 0.26.6: o menu de debug também.
    'debug: interruptor': DebugSwitch(value: true, onChanged: (_) {}),
    'debug: (i)': DebugInfoButton(open: false, onTap: () {}),
    'debug: estrela': DebugStar(on: false, onTap: () {}),
    'debug: chip': SizedBox(width: 72, child: DebugChip('1×', on: true, onTap: () {})),
    'debug: botão': DebugButton(label: 'Ir', minWidth: 48, onTap: () {}),
    'debug: botão que mexe no save': DebugButton(label: 'Executar', tone: DebugTone.save, onTap: () {}),
    'debug: chip fora do real': DebugOverrideChip('relógio', onTap: () {}),
    'debug: aba': SizedBox(width: 56, child: DebugTabButton(icon: Icons.pets_sharp, label: 'Criaturas', active: true, onTap: () {})),
  };

  for (final e in targets.entries) {
    testWidgets('${e.key}: pelo menos 48 dp', (tester) async {
      final s = await sizeOf(tester, e.value);
      expect(s.width, greaterThanOrEqualTo(48), reason: 'largura');
      expect(s.height, greaterThanOrEqualTo(48), reason: 'altura');
    });
  }

  test('as zonas fixas do HUD que se tocam têm 48 dp ou mais', () {
    for (final v in [HudSize.bar, HudSize.compass, HudSize.phone, HudSize.radar, HudSize.strip, HudSize.tracker, HudSize.side]) {
      expect(v, greaterThanOrEqualTo(48));
    }
  });
}
