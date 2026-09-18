package com.earlyecho.earlyecho

/**
 * Per-window pipeline output. Windows are processed independently so their
 * PCM and intermediate tensors can be garbage-collected immediately; the
 * session-level aggregate only keeps these small numeric results.
 */
data class ChunkFeatures(
    val transitionGapsMs: List<Long>,
    val childVoicedMs: Long,
    val adultVoicedMs: Long,
    val recordedMs: Long,
    val transitions: Int,
    val voicedMs: Long = 0,
    val vadFrames: Int = 0,
    val vadVoicedFrames: Int = 0,
    val labelledSegments: List<SpeakerSegment> = emptyList(),
    val pfvFrames: List<PitchFrame> = emptyList(),
)

/**
 * Drives one rolling analysis window through VAD, diarization and feature
 * extraction.
 *
 * The default window is 10 seconds (~320 KB of 16-bit PCM at 16 kHz); the
 * caller swaps in [LOW_MEMORY_WINDOW_SAMPLES] (5 s) when the device reports
 * less than 200 MB of free RAM so analysis cannot push a budget phone into
 * swapping.
 */
class RollingBufferProcessor(
    private val vad: WebRTCVadBridge,
    private val diarizer: PyannoteRunner,
    private val extractor: FeatureExtractor,
    val windowSamples: Int = DEFAULT_WINDOW_SAMPLES,
) {
    fun processChunk(chunk: ShortArray, childAgeMonths: Int): ChunkFeatures {
        val vadMask = vad.process(chunk)
        val voicedFrames = vadMask.count { it }
        val segments = diarizer.diarize(chunk)
        val features = extractor.extract(chunk, segments, childAgeMonths)
        return features.copy(
            voicedMs = voicedFrames * VAD_FRAME_MS,
            vadFrames = vadMask.size,
            vadVoicedFrames = voicedFrames,
        )
    }

    companion object {
        /** 10 s of 16 kHz mono audio — the default rolling window. */
        const val DEFAULT_WINDOW_SAMPLES = 160_000

        /** 5 s window used when free RAM drops below 200 MB. */
        const val LOW_MEMORY_WINDOW_SAMPLES = 80_000

        const val VAD_FRAME_MS = 30L
    }
}

/**
 * Compresses the per-read visual level stream into the fixed-size waveform
 * summary returned in the pipeline result.
 */
object WaveformSummarizer {
    /**
     * Buckets [levels] into [points] mean-pooled values. Short inputs are
     * zero-padded on the right so the contract always returns exactly
     * [points] entries.
     */
    fun summarize(levels: List<Double>, points: Int = WAVEFORM_POINTS): List<Double> {
        if (points <= 0) return emptyList()
        if (levels.isEmpty()) return List(points) { 0.0 }
        return List(points) { bucket ->
            val start = bucket * levels.size / points
            val end = ((bucket + 1) * levels.size / points).coerceAtLeast(start + 1)
            levels.subList(start, end.coerceAtMost(levels.size)).average()
        }
    }

    const val WAVEFORM_POINTS = 256
}
