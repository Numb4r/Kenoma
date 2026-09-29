import 'package:flutter/material.dart';

void main() {
  runApp(const KenomaApp());
}

class KenomaApp extends StatelessWidget {
  const KenomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Kenoma',
      home: Scaffold(),
    );
  }
}
