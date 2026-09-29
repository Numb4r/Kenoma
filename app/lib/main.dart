import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dev/tuning_debug_menu.dart';
import 'ui/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KenomaApp());
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
