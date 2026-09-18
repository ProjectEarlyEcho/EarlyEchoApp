package com.earlyecho.earlyecho

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.util.Log
import java.nio.FloatBuffer
import kotlin.math.exp

/**
 * A contiguous voiced span produced by speaker diarization.
 *
 * The ONNX segmentation model only reports that *someone* is speaking;
 * the CHILD / ADULT identity is attached afterwards by the F0 heuristic in
 * [FeatureExtractor]. Until then segments carry [SPEAKER_UNKNOWN].
 */
data class SpeakerSegment(val startMs: Long, val endMs: Long, val speaker: String) {
    companion object {
        const val SPEAKER_CHILD = "CHILD"
        const val SPEAKER_ADULT = "ADULT"
        const val SPEAKER_UNKNOWN = "UNKNOWN"
    }
}

/**
 * ONNX Runtime wrapper around the bundled INT8 pyannote segmentation model.
 *
 * The model emits per-frame speaker-activity log-probabilities which are
 * decoded into merged voiced turns. Segments shorter than the F0 analysis
 * window or sitting in the ambiguous pitch band are left for the feature
 * extractor to discard.
 */
class PyannoteRunner {
    private var environment: OrtEnvironment? = null
    private var session: OrtSession? = null
    private var initialized = false

    @Synchronized
    fun initialize(modelPath: String) {
        if (initialized) return
        try {
            environment = OrtEnvironment.getEnvironment()
            val options = OrtSession.SessionOptions().apply {
                // Two threads keeps diarization responsive on budget phones
                // without starving the audio capture thread.
                setIntraOpNumThreads(2)
                addConfigEntry("session.use_env_allocators", "1")
            }
            session = environment?.createSession(modelPath, options)
            initialized = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load the bundled segmentation model", e)
            initialized = false
        }
    }

    val isReady: Boolean get() = initialized && session != null

    /**
     * Runs speaker segmentation over a 16 kHz mono PCM window and returns
     * merged voiced turns labelled [SpeakerSegment.SPEAKER_UNKNOWN].
     */
    fun diarize(pcm: ShortArray): List<SpeakerSegment> {
        val ortEnv = environment
        val ortSession = session
        if (!initialized || ortEnv == null || ortSession == null) {
            throw IllegalStateException("Segmentation model is not initialized")
        }

        try {
            // Segmentation takes float32 waveform input [batch, channel, samples].
            val floatPcm = FloatArray(pcm.size) { pcm[it] / 32768.0f }
            val shape = longArrayOf(1, 1, pcm.size.toLong())
            val tensor = OnnxTensor.createTensor(ortEnv, FloatBuffer.wrap(floatPcm), shape)

            // Read the declared input name rather than hardcoding one so a
            // future re-export of the bundled model cannot silently rename it.
            val inputName = ortSession.inputNames.firstOrNull() ?: "input_values"
            val result = ortSession.run(mapOf(inputName to tensor))
            val output = result?.get(0)?.value
            result?.close()
            tensor.close()
            return decodeFrameScores(output, pcm.size)
        } catch (e: Exception) {
            Log.e(TAG, "Segmentation inference failed", e)
            return emptyList()
        }
    }

    /**
     * Decodes [batch, frames, classes] model output into voiced turns.
     *
     * The bundled export returns log-probabilities whose first class is
     * silence, so a frame counts as voiced when the best non-silence class
     * reaches probability 0.5. Frames closer than [MERGE_GAP_MS] are merged
     * into a single turn.
     */
    private fun decodeFrameScores(value: Any?, samples: Int): List<SpeakerSegment> {
        val batch = value as? Array<*> ?: throw IllegalStateException("Unexpected ONNX output shape")
        val frames = batch.firstOrNull() as? Array<*> ?: throw IllegalStateException("Unexpected ONNX frame shape")
        if (frames.isEmpty()) return emptyList()

        val frameMs = samples.toDouble() / SAMPLE_RATE / frames.size * 1000.0
        val voicedSpans = mutableListOf<Pair<Long, Long>>()
        for (i in frames.indices) {
            val scores = frames[i] as? FloatArray ?: continue
            val best = scores.indices.maxByOrNull { scores[it] } ?: continue
            val probability = exp(scores[best].toDouble())
            if (best != 0 && probability >= VOICE_PROBABILITY_THRESHOLD) {
                voicedSpans += (i * frameMs).toLong() to ((i + 1) * frameMs).toLong()
            }
        }
        if (voicedSpans.isEmpty()) return emptyList()

        val turns = mutableListOf<SpeakerSegment>()
        var start = voicedSpans.first().first
        var end = voicedSpans.first().second
        for ((nextStart, nextEnd) in voicedSpans.drop(1)) {
            if (nextStart <= end + MERGE_GAP_MS) {
                end = nextEnd
            } else {
                turns += SpeakerSegment(start, end, SpeakerSegment.SPEAKER_UNKNOWN)
                start = nextStart
                end = nextEnd
            }
        }
        turns += SpeakerSegment(start, end, SpeakerSegment.SPEAKER_UNKNOWN)
        return turns
    }

    fun close() {
        session?.close()
        environment?.close()
    }

    private companion object {
        const val TAG = "PyannoteRunner"
        const val SAMPLE_RATE = 16_000
        const val VOICE_PROBABILITY_THRESHOLD = 0.5
        const val MERGE_GAP_MS = 100L
    }
}
