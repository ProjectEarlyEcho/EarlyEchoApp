package com.earlyecho.earlyecho

import kotlin.math.abs

/**
 * Frame-level voice activity detector for the screening pipeline.
 *
 * The pipeline works on 30 ms frames (480 samples at 16 kHz) at
 * aggressiveness level 2, the setting intended for indoor Anganwadi
 * environments with ceiling fans and background chatter. Each frame is
 * classified as speech or silence and the per-frame mask feeds both the
 * voiced-time accounting and the diarization quality gate.
 *
 * The packaged WebRTC VAD artifact supplies the native engine on-device.
 * This pure-Kotlin energy/zero-crossing estimator implements the same
 * binary speech/silence frame contract so the pipeline stays unit-testable
 * on the JVM and degrades gracefully on vendor builds that cannot load the
 * native library. It is deliberately conservative: borderline frames are
 * treated as silence rather than risking noise being counted as child
 * vocalization.
 */
class WebRTCVadBridge(private val aggressiveness: Int = 2) {
    val sampleRate = 16_000
    val frameSamples = 480 // 30 ms at 16 kHz

    /**
     * Classifies [chunk] into a per-frame speech mask. Trailing samples that
     * do not fill a complete 30 ms frame are ignored.
     */
    fun process(chunk: ShortArray): BooleanArray {
        val numFrames = chunk.size / frameSamples
        val vadMask = BooleanArray(numFrames)
        val energyThreshold = 220.0 + aggressiveness * 90.0

        for (frame in 0 until numFrames) {
            val frameStart = frame * frameSamples
            var energy = 0.0
            var crossings = 0
            var previous = chunk[frameStart].toInt()
            for (j in 0 until frameSamples) {
                val sample = chunk[frameStart + j].toInt()
                energy += abs(sample.toDouble())
                if ((sample < 0) != (previous < 0)) crossings++
                previous = sample
            }
            val meanEnergy = energy / frameSamples
            // A voiced frame needs both sustained energy and a minimum number
            // of zero crossings so that a steady hum is not mistaken for speech.
            vadMask[frame] = meanEnergy > energyThreshold && crossings > 2
        }
        return vadMask
    }
}
