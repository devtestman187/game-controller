package com.thumbparty.app

import android.content.Context
import android.content.res.Configuration
import android.view.Surface
import android.os.BatteryManager
import android.os.PowerManager
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The one native channel: haptics (ticks and the TV's events, lib/src/haptics.dart) and
        // the device status for Diagnostics (lib/src/device_status.dart).
        val haptics = Haptics(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.thumbparty.app/haptics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(haptics.capabilities())
                    "tick" -> {
                        haptics.tick((call.argument<Double>("intensity") ?: 1.0).toFloat())
                        result.success(null)
                    }
                    "play" -> {
                        val segments = (call.argument<List<Any?>>("segments") ?: emptyList()).mapNotNull { item ->
                            (item as? List<*>)?.mapNotNull { (it as? Number)?.toDouble() }?.toDoubleArray()
                        }
                        haptics.play(segments)
                        result.success(null)
                    }
                    "deviceStatus" -> result.success(deviceStatus(applicationContext))
                    "naturalOrientation" -> result.success(naturalOrientation())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * "landscape" on devices whose screen is naturally landscape, like the Pixel Tablet and most
     * Android tablets, otherwise "portrait". Android reports motion sensors relative to the natural
     * orientation, so the tilt code turns them by 90° on landscape devices (lib/src/motion.dart).
     */
    private fun naturalOrientation(): String {
        val rotation = display?.rotation ?: Surface.ROTATION_0
        val turned = rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270
        val landscapeNow = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        return if (landscapeNow != turned) "landscape" else "portrait"
    }
}

/** Battery, heat and this app's CPU time, for the long-session check in Diagnostics. */
private fun deviceStatus(context: Context): Map<String, Any?> {
    val battery = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val level = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    val thermal = when (power.currentThermalStatus) {
        PowerManager.THERMAL_STATUS_NONE -> "nominal"
        PowerManager.THERMAL_STATUS_LIGHT -> "fair"
        PowerManager.THERMAL_STATUS_MODERATE -> "serious"
        PowerManager.THERMAL_STATUS_SEVERE,
        PowerManager.THERMAL_STATUS_CRITICAL,
        PowerManager.THERMAL_STATUS_EMERGENCY,
        PowerManager.THERMAL_STATUS_SHUTDOWN -> "critical"
        else -> "unknown"
    }
    return mapOf(
        "battery" to (if (level in 0..100) level / 100.0 else -1.0),
        "charging" to battery.isCharging,
        "thermal" to thermal,
        "cpuMs" to Process.getElapsedCpuTime().toDouble(),
        "lowPower" to power.isPowerSaveMode,
    )
}
