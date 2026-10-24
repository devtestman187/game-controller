package com.gamecontrollerdev.controller

import android.content.Context
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Input ticks with VibrationEffect. Uses the "click" primitive when the
 * hardware supports it (crisp, with intensity), otherwise a short one-shot
 * buzz, with amplitude if the motor allows it. minSdk is 36, so every API
 * used here is available.
 */
class Haptics(context: Context) {
    private val vibrator: Vibrator =
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator

    // "Media" covers games, and isn't silenced by the system touch-feedback switch.
    private val attributes = VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA)
    private val hasVibrator = vibrator.hasVibrator()
    private val hasClick = hasVibrator &&
        vibrator.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_CLICK)
    private val hasAmplitude = hasVibrator && vibrator.hasAmplitudeControl()
    private var lastError: String? = null

    fun capabilities(): Map<String, Any?> = mapOf(
        "supported" to hasVibrator,
        "intensityControl" to (hasClick || hasAmplitude),
        "engine" to when {
            !hasVibrator -> "none (no vibrator)"
            hasClick -> "VibrationEffect composition (click primitive)"
            hasAmplitude -> "VibrationEffect one-shot with amplitude"
            else -> "VibrationEffect one-shot (on/off only)"
        },
        "detail" to lastError,
    )

    fun tick(intensity: Float) {
        if (!hasVibrator) return
        val level = intensity.coerceIn(0f, 1f)
        if (level <= 0f) return
        try {
            val effect = when {
                hasClick -> VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, level)
                    .compose()
                hasAmplitude -> VibrationEffect.createOneShot(TICK_MS, (level * 255).toInt().coerceIn(1, 255))
                else -> VibrationEffect.createOneShot(TICK_MS, VibrationEffect.DEFAULT_AMPLITUDE)
            }
            vibrator.vibrate(effect, attributes)
        } catch (e: RuntimeException) {
            lastError = e.toString()
        }
    }

    private companion object {
        const val TICK_MS = 12L
    }
}
