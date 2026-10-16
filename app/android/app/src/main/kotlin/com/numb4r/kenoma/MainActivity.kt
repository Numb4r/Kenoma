package com.numb4r.kenoma

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Um som curto para o aparecimento de um Eco Brilhante, sem arquivo de áudio nem pacote: o gerador de tons do sistema.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kenoma/sound").setMethodCallHandler { call, result ->
            if (call.method == "chime") {
                try {
                    val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 70)
                    tone.startTone(ToneGenerator.TONE_PROP_ACK, 220)
                } catch (_: RuntimeException) {
                    // sem som neste aparelho: o aviso na tela basta
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
