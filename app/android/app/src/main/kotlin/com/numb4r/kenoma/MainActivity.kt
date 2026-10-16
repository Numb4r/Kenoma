package com.numb4r.kenoma

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val device = DeviceChannels(this)

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        device.onRequestPermissionsResult(requestCode, grantResults)
    }


    // Um som curto para o aparecimento de um Eco Brilhante, sem arquivo de áudio nem pacote: o gerador de tons do sistema.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        device.register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kenoma/sound").setMethodCallHandler { call, result ->
            if (call.method == "chime") {
                try {
                    val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 70)
                    tone.startTone(ToneGenerator.TONE_PROP_ACK, 220)
                    // Libera o gerador logo depois do tom: cada um segura um AudioTrack nativo.
                    Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 400)
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
