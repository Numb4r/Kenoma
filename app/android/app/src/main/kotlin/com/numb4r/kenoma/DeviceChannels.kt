package com.numb4r.kenoma

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Sensores opcionais (contador de passos e proximidade) e o atalho para o backup do Android.
 * Tudo é falha silenciosa: sem sensor, sem permissão ou sem tela de ajustes, o Dart recebe `null`/`false`.
 *
 * - `kenoma/steps` (MethodChannel): `hasPermission`, `requestPermission` (ACTIVITY_RECOGNITION, Android 10+) e
 *   `read` (uma leitura do TYPE_STEP_COUNTER: passos acumulados desde o boot, ou null).
 * - `kenoma/proximity` (EventChannel): `true` quando o sensor de proximidade está coberto.
 * - `kenoma/system` (MethodChannel): `openBackupSettings`, `isInstalled`, `launchPackage`, `openUrl`, `notificationAccess`,
 *   `openNotificationSettings` e `setRideRelay` (o interruptor das notificações de corrida).
 * - `kenoma/ride_notifications` (EventChannel): título e texto das notificações do Uber e da 99, só enquanto o Dart ouve.
 */
class DeviceChannels(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "kenoma/steps").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasActivityPermission())
                "requestPermission" -> requestActivityPermission(result)
                "read" -> readSteps(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "kenoma/proximity").setStreamHandler(ProximityHandler())
        EventChannel(messenger, "kenoma/ride_notifications").setStreamHandler(RideNotificationListener.Stream)
        MethodChannel(messenger, "kenoma/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "openBackupSettings" -> result.success(openBackupSettings())
                "isInstalled" -> result.success(launchIntent(call.arguments as? String) != null)
                "launchPackage" -> result.success(launchPackage(call.arguments as? String))
                "openUrl" -> result.success(openUrl(call.arguments as? String))
                "notificationAccess" -> result.success(hasNotificationAccess())
                "openNotificationSettings" -> result.success(openNotificationSettings())
                "setRideRelay" -> {
                    RideNotificationListener.relayEnabled = call.arguments == true
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasActivityPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            activity.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    private fun requestActivityPermission(result: MethodChannel.Result) {
        if (hasActivityPermission()) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        try {
            pendingPermission = result
            activity.requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST_STEPS)
        } catch (_: RuntimeException) {
            pendingPermission = null
            result.success(false)
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_STEPS) return
        val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(ok)
        pendingPermission = null
    }

    /** Uma leitura do contador de passos; null se não há sensor, não há permissão ou ele não responde em 3 s. */
    private fun readSteps(result: MethodChannel.Result) {
        val sm = activity.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sm?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sm == null || sensor == null || !hasActivityPermission()) {
            result.success(null)
            return
        }
        var done = false
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (done) return
                done = true
                sm.unregisterListener(this)
                result.success(event.values[0].toLong())
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        try {
            if (!sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)) {
                result.success(null)
                return
            }
        } catch (_: RuntimeException) {
            result.success(null)
            return
        }
        main.postDelayed({
            if (!done) {
                done = true
                sm.unregisterListener(listener)
                result.success(null)
            }
        }, 3000)
    }

    private fun launchIntent(pkg: String?): Intent? =
        pkg?.let { activity.packageManager.getLaunchIntentForPackage(it) }

    private fun launchPackage(pkg: String?): Boolean = start(launchIntent(pkg))

    private fun openUrl(url: String?): Boolean = url != null && start(Intent(Intent.ACTION_VIEW, Uri.parse(url)))

    private fun openNotificationSettings(): Boolean = start(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))

    private fun start(intent: Intent?): Boolean {
        if (intent == null) return false
        return try {
            activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: RuntimeException) {
            false // inclui ActivityNotFoundException: ninguém abre este link
        }
    }

    private fun hasNotificationAccess(): Boolean {
        val enabled = Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(':').any { it.startsWith("${activity.packageName}/") }
    }

    private fun openBackupSettings(): Boolean {
        val actions = listOf("android.settings.PRIVACY_SETTINGS", Settings.ACTION_SETTINGS)
        for (action in actions) {
            try {
                activity.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: RuntimeException) {
                // tenta o próximo
            }
        }
        return false
    }

    private inner class ProximityHandler : EventChannel.StreamHandler, SensorEventListener {
        private var sm: SensorManager? = null
        private var sink: EventChannel.EventSink? = null
        private var far = 5f

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
            val manager = activity.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val sensor = manager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
            if (manager == null || sensor == null) return // sem sensor: o fluxo fica mudo, o modo bolso nunca cobre
            far = minOf(5f, sensor.maximumRange)
            sm = manager
            try {
                manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            } catch (_: RuntimeException) {
                sm = null
            }
        }

        override fun onCancel(arguments: Any?) {
            sm?.unregisterListener(this)
            sm = null
            sink = null
        }

        override fun onSensorChanged(event: SensorEvent) {
            sink?.success(event.values[0] < far)
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private companion object {
        const val REQUEST_STEPS = 4711
    }
}
