/// A câmera que lê o QR do grupo. Devolve o código de grupo do primeiro QR válido que aparecer.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/seed.dart';
import '../colors.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  String? _bad;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = b.rawValue == null ? null : parseGroupQr(b.rawValue!);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    if (capture.barcodes.isNotEmpty && _bad == null) setState(() => _bad = 'Esse QR não é de um grupo do Kenoma');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOutline,
      body: Stack(children: [
        MobileScanner(
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('NÃO CONSEGUI ABRIR A CÂMERA. CONFIRA A PERMISSÃO DO APP NOS AJUSTES DO CELULAR. (${error.errorCode.name})',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: kEssence, height: 1.8)),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Row(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(width: 48, height: 48, child: Center(child: Text('<', style: TextStyle(fontSize: 24, color: kText)))),
              ),
              const Text('ESCANEAR GRUPO', style: TextStyle(fontSize: 16, color: kText)),
            ]),
            const Spacer(),
            Container(
              width: double.infinity,
              color: kOutline.withValues(alpha: 0.85),
              padding: const EdgeInsets.all(16),
              child: Text(_bad ?? 'APONTE PARA O QR DE UM AMIGO', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: _bad == null ? kText : kEssence)),
            ),
          ]),
        ),
      ]),
    );
  }
}
