package com.numb4r.kenoma

import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/**
 * Lê só as notificações do Uber e da 99, para o carro da corrida aparecer no mapa. O pacote é conferido ANTES de tocar em
 * `notification.extras`: as outras são ignoradas sem leitura. Com o interruptor dos Ajustes desligado, ou sem ninguém
 * ouvindo no Dart, nada é repassado. Título e texto vão pelo EventChannel e somem: nada em disco, nada em log.
 */
class RideNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val pkg = sbn?.packageName ?: return
        if (pkg !in RIDE_PACKAGES) return
        if (!relayEnabled || sink == null) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
        val text = extras.getCharSequence("android.text")?.toString().orEmpty()
        main.post { sink?.success(mapOf("package" to pkg, "title" to title, "text" to text)) }
    }

    /** O lado Dart ouve aqui enquanto há uma corrida. */
    object Stream : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
        }

        override fun onCancel(arguments: Any?) {
            sink = null
        }
    }

    companion object {
        private val RIDE_PACKAGES = setOf("com.ubercab", "com.taxis99")
        private val main = Handler(Looper.getMainLooper())

        @Volatile
        private var sink: EventChannel.EventSink? = null

        /** O interruptor dos Ajustes. Desligado até o Dart dizer o contrário. */
        @Volatile
        var relayEnabled = false
    }
}
