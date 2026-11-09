package com.numb4r.kenoma

import android.Manifest
import android.app.Activity
import android.app.backup.BackupManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Sensores opcionais (contador de passos e proximidade) e o atalho para o backup do Android.
 * Tudo é falha silenciosa: sem sensor, sem permissão ou sem tela de ajustes, o Dart recebe `null`/`false`.
 *
 * - `kenoma/steps` (MethodChannel): `hasPermission`, `requestPermission` (ACTIVITY_RECOGNITION, Android 10+) e
 *   `read` (ver [StepReader]).
 * - `kenoma/battery` (MethodChannel): a carga da bateria em %, ou null.
 * - `kenoma/proximity` (EventChannel): `true` quando o sensor de proximidade está coberto.
 * - `kenoma/system` (MethodChannel): `openBackupSettings`, `requestBackup` (BackupManager.dataChanged), `isInstalled`, `launchPackage`, `openUrl`, `notificationAccess`,
 *   `openNotificationSettings`, `setRideRelay` (o interruptor das notificações de corrida) e `activeRides` (as notificações de
 *   corrida que já estão na barra).
 * - `kenoma/ride_notifications` (EventChannel): título e texto das notificações do Uber e da 99, só enquanto o Dart ouve.
 */
class DeviceChannels(private val activity: Activity) {
    private var pendingPermission: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "kenoma/steps").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasActivityPermission())
                "requestPermission" -> requestActivityPermission(result)
                "read" -> StepReader.read(activity, result)
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "kenoma/proximity").setStreamHandler(ProximityHandler())
        MethodChannel(messenger, "kenoma/battery").setMethodCallHandler { _, result -> result.success(StepReader.battery(activity)) }
        EventChannel(messenger, "kenoma/ride_notifications").setStreamHandler(RideNotificationListener.Stream)
        MethodChannel(messenger, "kenoma/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "openBackupSettings" -> result.success(openBackupSettings())
                "requestBackup" -> {
                    BackupManager(activity).dataChanged()
                    result.success(true)
                }
                "isInstalled" -> result.success(launchIntent(call.arguments as? String) != null)
                "launchPackage" -> result.success(launchPackage(call.arguments as? String))
                "openUrl" -> result.success(openUrl(call.arguments as? String))
                "notificationAccess" -> result.success(hasNotificationAccess())
                "openNotificationSettings" -> result.success(openNotificationSettings())
                "activeRides" -> result.success(RideNotificationListener.activeRides())
                "setRideRelay" -> {
                    RideNotificationListener.relayEnabled = call.arguments == true
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasActivityPermission(): Boolean = StepReader.hasPermission(activity)

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
