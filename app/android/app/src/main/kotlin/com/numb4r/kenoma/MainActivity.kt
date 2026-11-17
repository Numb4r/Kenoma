package com.numb4r.kenoma

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val device = DeviceChannels(this)

    // Comandos de debug do adb (0.24.2): `am start -n com.numb4r.kenoma/.MainActivity --es kenoma_cmd "..."`. O script do
    // celular manda por aqui em vez de digitar; o Dart pega o que abriu o app e recebe os seguintes.
    private var pendingCmd: String? = null
    private var debugCmd: MethodChannel? = null

    private fun takeCmd(intent: Intent?) {
        val cmd = intent?.getStringExtra("kenoma_cmd") ?: return
        intent.removeExtra("kenoma_cmd")
        val ch = debugCmd
        if (ch != null) ch.invokeMethod("cmd", cmd) else pendingCmd = cmd
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeCmd(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        device.onRequestPermissionsResult(requestCode, grantResults)
    }


    // Um som curto para o aparecimento de um Eco Brilhante, sem arquivo de áudio nem pacote: o gerador de tons do sistema.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        device.register(flutterEngine.dartExecutor.binaryMessenger)
        PatrolChannels.register(this)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kenoma/debug_cmd")
        ch.setMethodCallHandler { call, result ->
            if (call.method == "pending") {
                takeCmd(intent)
                result.success(pendingCmd)
                pendingCmd = null
            } else {
                result.notImplemented()
            }
        }
        debugCmd = ch
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
            } else if (call.method == "thunder") {
                // Trovão sem arquivo de áudio: um tom grave e longo, mais fraco de longe (o atraso pela distância vem do Dart).
                try {
                    val volume = (call.argument<Int>("volume") ?: 80).coerceIn(10, 100)
                    val tone = ToneGenerator(AudioManager.STREAM_MUSIC, volume)
                    tone.startTone(ToneGenerator.TONE_CDMA_LOW_L, 700)
                    Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 900)
                } catch (_: RuntimeException) {
                    // sem som neste aparelho: o clarão basta
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
