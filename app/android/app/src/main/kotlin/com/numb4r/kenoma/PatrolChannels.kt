package com.numb4r.kenoma

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Contador de passos e bateria, sem Activity: servem ao app e ao motor Flutter do serviço da Patrulha do Véu.
 *
 * `read` devolve `{steps, boot_ms}` (passos desde o boot e a hora do boot em ms UTC, `currentTimeMillis - elapsedRealtime`),
 * ou null sem sensor, sem permissão ou sem resposta em 3 s. A hora do boot separa "o celular reiniciou" de "o sensor deu
 * uma leitura menor".
 */
object StepReader {
    private val main = Handler(Looper.getMainLooper())

    fun hasPermission(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ctx.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    fun battery(ctx: Context): Int? =
        (ctx.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager)
            ?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?.takeIf { it in 0..100 }

    fun read(ctx: Context, result: MethodChannel.Result) {
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sm?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sm == null || sensor == null || !hasPermission(ctx)) {
            result.success(null)
            return
        }
        var done = false
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (done) return
                done = true
                sm.unregisterListener(this)
                val bootMs = System.currentTimeMillis() - SystemClock.elapsedRealtime()
                result.success(mapOf("steps" to event.values[0].toLong(), "boot_ms" to bootMs))
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
}

/** Liga `kenoma/steps` (só `read`) e `kenoma/battery` em cada motor Flutter que o serviço da Patrulha cria. */
class PatrolChannels private constructor(private val ctx: Context) : FlutterForegroundTaskLifecycleListener {
    override fun onEngineCreate(flutterEngine: FlutterEngine?) {
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger ?: return
        MethodChannel(messenger, "kenoma/steps").setMethodCallHandler { call, result ->
            if (call.method == "read") StepReader.read(ctx, result) else result.notImplemented()
        }
        MethodChannel(messenger, "kenoma/battery").setMethodCallHandler { _, result -> result.success(StepReader.battery(ctx)) }
    }

    override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}
    override fun onTaskRepeatEvent() {}
    override fun onTaskDestroy() {}
    override fun onEngineWillDestroy() {}

    companion object {
        private var registered = false

        /** Uma vez por processo, antes de o app ligar o serviço (que só começa com o app à vista). */
        fun register(ctx: Context) {
            if (registered) return
            registered = true
            FlutterForegroundTaskPlugin.addTaskLifecycleListener(PatrolChannels(ctx.applicationContext))
        }
    }
}
