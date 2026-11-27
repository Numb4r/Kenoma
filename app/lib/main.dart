import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/geolocator_source.dart';
import 'dev/dev_tools.dart';
import 'dev/tuning_debug_menu.dart';
import 'net/signed_feed.dart';
import 'save/ksv_save_store.dart';
import 'ui/colors.dart';
import 'ui/craft/ui_art.dart' show UiArt;
import 'ui/game/game_map_screen.dart';
import 'ui/system_bars.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await applySystemBars(show: false); // tela cheia até o save dizer outra coisa (`kSystemBarsSetting`)
  runApp(const KenomaApp());
  unawaited(UiArt.load()); // 0.26.0: o kit de interface (molduras e ícones) pronto para todas as telas
  // Opcional e silencioso: no máximo uma consulta por dia ao feed assinado; o resultado vale a partir da próxima abertura.
  unawaited(refreshSignedFeed(nowUtc: DateTime.now().millisecondsSinceEpoch ~/ 1000));
}

/// 0.26.2: o ícone abre direto no mapa: o splash do Android, a tela de carregamento do mapa (`KenomaLoading`) e o mapa. O
/// menu de debug fica por baixo na pilha (o "Menu de debug" do selo de modo volta a ele), com as mesmas ferramentas.
class KenomaApp extends StatefulWidget {
  const KenomaApp({super.key});

  @override
  State<KenomaApp> createState() => _KenomaAppState();
}

class _KenomaAppState extends State<KenomaApp> {
  late final DevTools _tools = DevTools(realSource: GeolocatorPositionSource())..detect();

  Route<void> _menu() => MaterialPageRoute<void>(builder: (_) => TuningDebugMenu(devTools: _tools));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kenoma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kOutline,
        fontFamily: 'Silkscreen',
        colorScheme: const ColorScheme.dark(primary: kVeil, secondary: kSignal, surface: kOutline),
      ),
      onGenerateRoute: (_) => _menu(),
      onGenerateInitialRoutes: (_) => [
        _menu(),
        MaterialPageRoute<void>(builder: (_) => GameMapScreen(tools: _tools, openStore: KsvSaveStore.inDocuments)),
      ],
    );
  }
}
