package com.gamecontrollerdev.controller

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Input ticks and the TV's haptic events with VibrationEffect. Uses the "click" primitive when the
 * hardware supports it (crisp, with intensity), otherwise a short one-shot
 * buzz, with amplitude if the motor allows it. minSdk is 31 (Android 12):
 * vibration attributes need Android 13, so Android 12 uses the older audio
 * attributes (found by the M7 emulator check: the app crashed at start).
 */
class Haptics(context: Context) {
    private val vibrator: Vibrator =
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator

    // "Media" covers games, and isn't silenced by the system touch-feedback switch.
    private val attributes: VibrationAttributes? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA)
        } else {
            null
        }

    // Android 12: the same "media" usage, as audio attributes.
    private val audioAttributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
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
            vibrate(effect)
        } catch (e: RuntimeException) {
            lastError = e.toString()
        }
    }

    /**
     * A haptic event from the TV. [segments] are `[startMs, durationMs, intensity,
     * sharpness]` (duration 0 = a tap), built in lib/src/haptic_patterns.dart.
     * They become one waveform: taps are short pulses (crisp ones shorter),
     * buzzes hold their strength, and where segments overlap the stronger one
     * wins. Without amplitude control it's an on/off pattern. A new vibration
     * replaces the one playing, as Android allows only one at a time.
     */
    fun play(segments: List<DoubleArray>) {
        if (!hasVibrator) return
        try {
            waveform(segments)?.let { vibrate(it) }
        } catch (e: RuntimeException) {
            lastError = e.toString()
        }
    }

    private fun vibrate(effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && attributes != null) {
            vibrator.vibrate(effect, attributes)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(effect, audioAttributes)
        }
    }

    private class Span(val start: Int, val end: Int, val amplitude: Int)

    private fun waveform(segments: List<DoubleArray>): VibrationEffect? {
        val spans = segments.filter { it.size >= 4 }.map { s ->
            val start = max(0.0, s[0]).roundToInt()
            val length = if (s[1] <= 0.0) {
                if (s[3] >= 0.5) TAP_SHARP_MS else TAP_SOFT_MS
            } else {
                max(1, s[1].roundToInt())
            }
            Span(start, start + length, (s[2].coerceIn(0.0, 1.0) * 255).roundToInt())
        }.filter { it.amplitude > 0 }
        if (spans.isEmpty()) return null
        val edges = (spans.flatMap { listOf(it.start, it.end) } + 0).toSortedSet().toList()
        val timings = mutableListOf<Long>()
        val levels = mutableListOf<Int>()
        for (i in 0 until edges.size - 1) {
            val from = edges[i]
            val to = edges[i + 1]
            val amplitude = spans.filter { it.start <= from && it.end >= to }.maxOfOrNull { it.amplitude } ?: 0
            val level = when {
                amplitude == 0 -> 0
                hasAmplitude -> amplitude
                else -> VibrationEffect.DEFAULT_AMPLITUDE
            }
            if (levels.isNotEmpty() && levels.last() == level) {
                timings[timings.size - 1] += (to - from).toLong()
            } else {
                timings.add((to - from).toLong())
                levels.add(level)
            }
        }
        return VibrationEffect.createWaveform(timings.toLongArray(), levels.toIntArray(), -1)
    }

    private companion object {
        const val TICK_MS = 12L
        const val TAP_SHARP_MS = 15
        const val TAP_SOFT_MS = 30
    }
}
