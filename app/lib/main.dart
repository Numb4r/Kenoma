import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dev/tuning_debug_menu.dart';
import 'net/signed_feed.dart';
import 'ui/colors.dart';
import 'ui/craft/ui_art.dart' show UiArt;
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

class KenomaApp extends StatelessWidget {
  const KenomaApp({super.key});

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
      home: const TuningDebugMenu(),
    );
  }
}
