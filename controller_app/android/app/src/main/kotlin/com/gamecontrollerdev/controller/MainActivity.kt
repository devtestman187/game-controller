package com.gamecontrollerdev.controller

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The one native channel: haptics (ticks and the TV's events) (see lib/src/haptics.dart).
        val haptics = Haptics(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gamecontrollerdev.controller/haptics")
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
                    else -> result.notImplemented()
                }
            }
    }
}
