package com.earlyecho.earlyecho

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Hosts the `com.earlyecho/audio_pipeline` MethodChannel used by the Dart
 * screening flow.
 *
 * Call sequence expected from Dart:
 * 1. `requestPermission` — runtime RECORD_AUDIO grant.
 * 2. `startRecording` — begins capture; each filled rolling window runs
 *    VAD -> diarization -> feature extraction in the background.
 * 3. `stopRecording` — ends capture.
 * 4. `runPipeline` — aggregates every analysed window into the feature-vector
 *    contract consumed by `SessionFeatures.fromChannelMap` on the Dart side.
 *
 * An EventChannel on `com.earlyecho/audio_pipeline/waveform` streams
 * visual-only amplitude levels for the recording UI. These values are
 * display data only; they are never part of the feature vector.
 */
class MainActivity : FlutterActivity() {
    private val pipelineChannel = "com.earlyecho/audio_pipeline"

    private val recorder = UnprocessedAudioRecorder()
    private val vad = WebRTCVadBridge(2)
    private val diarizer = PyannoteRunner()
    private val pfvAnalyzer = PfvAnalyzer()
    private val extractor = FeatureExtractor(pfvAnalyzer)
    private val executor = Executors.newSingleThreadExecutor()
    private val aggregate = SessionAggregate(pfvAnalyzer)

    @Volatile
    private var capturing = false
    private val captureGeneration = AtomicInteger(0)
    private var modelError: String? = null
    private var modelReady = false
    private var waveformSink: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipelineChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "requestPermission" -> requestMicrophonePermission(result)
                        "startRecording" -> startCapture(call, result)
                        "stopRecording" -> {
                            stopCapture()
                            result.success(true)
                        }
                        "runPipeline" -> runPipeline(call, result)
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERR_PIPELINE", e.message, null)
                }
            }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$pipelineChannel/waveform",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                waveformSink = events
            }

            override fun onCancel(arguments: Any?) {
                waveformSink = null
            }
        })
    }

    private fun requestMicrophonePermission(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        permissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MIC_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MIC_PERMISSION_REQUEST) return
        val pending = permissionResult ?: return
        permissionResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            pending.success(true)
        } else {
            pending.error(
                "ERR_PERMISSION",
                "Microphone permission was not granted",
                null,
            )
        }
    }

    private fun startCapture(call: MethodCall, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("ERR_PERMISSION", "Microphone permission is required", null)
            return
        }
        if (capturing) {
            result.error("ERR_ALREADY_RECORDING", "A recording is already in progress", null)
            return
        }
        if (!recorder.startRecording()) {
            result.error("ERR_MIC_UNAVAILABLE", "Could not initialize microphone", null)
            return
        }

        aggregate.reset()
        aggregate.ageMonths = call.argument<Int>("child_age_months") ?: 0
        modelError = null
        capturing = true
        val generation = captureGeneration.incrementAndGet()
        val windowSamples = if (lowMemory()) {
            RollingBufferProcessor.LOW_MEMORY_WINDOW_SAMPLES
        } else {
            RollingBufferProcessor.DEFAULT_WINDOW_SAMPLES
        }

        executor.execute {
            val readBuffer = ShortArray(1600) // 100 ms reads keep waveform updates lively
            val chunk = ShortArray(windowSamples)
            var buffered = 0
            while (capturing && generation == captureGeneration.get()) {
                val read = recorder.read(readBuffer, 0, readBuffer.size)
                // stop() releases the recorder while a read may be blocked;
                // a stale worker must never append to the next capture.
                if (!capturing || generation != captureGeneration.get()) break
                if (read <= 0) continue

                val peak = readBuffer.take(read).maxOfOrNull { abs(it.toInt()) } ?: 0
                val level = sqrt(peak.toDouble() / Short.MAX_VALUE.toDouble())
                    .coerceIn(0.0, 1.0)
                aggregate.addWaveform(level)
                runOnUiThread { waveformSink?.success(level) }

                if (buffered + read > chunk.size) buffered = 0
                System.arraycopy(readBuffer, 0, chunk, buffered, read)
                buffered += read
                if (buffered < chunk.size) continue

                try {
                    ensureModel()
                    RollingBufferProcessor(vad, diarizer, extractor, windowSamples)
                        .processChunk(chunk, aggregate.ageMonths)
                        .also { aggregate.add(it) }
                } catch (e: Exception) {
                    modelError = e.message ?: "Audio analysis failed"
                }
                buffered = 0
            }

            // A mid-activity skip can stop capture before the rolling window
            // fills. Pad the tail with silence and retain its real duration so
            // already-recorded speech still contributes to the session.
            if (buffered > 0 && modelError == null) {
                try {
                    ensureModel()
                    val padded = chunk.copyOf()
                    val actualMs = buffered * 1000L / 16_000L
                    RollingBufferProcessor(vad, diarizer, extractor, windowSamples)
                        .processChunk(padded, aggregate.ageMonths)
                        .copy(recordedMs = actualMs)
                        .also { aggregate.add(it) }
                } catch (e: Exception) {
                    modelError = e.message ?: "Audio analysis failed"
                }
            }
        }
        result.success(true)
    }

    private fun stopCapture() {
        capturing = false
        captureGeneration.incrementAndGet()
        recorder.stopRecording()
    }

    /**
     * Queued after the capture worker on the same single-thread executor, so
     * the final analysis window has fully landed before the aggregate is read.
     */
    private fun runPipeline(call: MethodCall, result: MethodChannel.Result) {
        val ageMonths = call.argument<Int>("child_age_months") ?: 0
        val timings = call.argument<List<Map<String, Any>>>("protocol_timings")
            .orEmpty()
        executor.execute {
            aggregate.ageMonths = ageMonths
            aggregate.protocolCount = timings.size
            val payload = aggregate.payload(
                recorder.audioSourceUsed,
                ageMonths,
                modelError,
            )
            runOnUiThread { result.success(payload) }
        }
    }

    /** Below 200 MB free RAM the rolling window halves to keep analysis safe. */
    private fun lowMemory(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        return info.availMem < 200L * 1024L * 1024L
    }

    /** Stages the bundled ONNX model from assets into a file ONNX can mmap. */
    private fun ensureModel() {
        if (modelReady) return
        val target = File(cacheDir, "pyannote-segmentation-3.0.onnx")
        if (!target.exists()) {
            assets.open("models/pyannote-segmentation-3.0.onnx").use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
        }
        diarizer.initialize(target.absolutePath)
        if (!diarizer.isReady) {
            throw IllegalStateException("Segmentation model failed to load")
        }
        modelReady = true
    }

    override fun onPause() {
        // Never keep the microphone open through an interruption.
        stopCapture()
        super.onPause()
    }

    override fun onDestroy() {
        stopCapture()
        executor.shutdownNow()
        diarizer.close()
        super.onDestroy()
    }

    companion object {
        private const val MIC_PERMISSION_REQUEST = 42
    }

    /**
     * Running aggregate across every analysed rolling window.
     *
     * Only small numeric results survive each window; PCM and tensors are
     * released immediately so the memory profile stays flat on budget phones.
     */
    private class SessionAggregate(private val pfvAnalyzer: PfvAnalyzer) {
        var ageMonths = 0
        var protocolCount = 0

        private var voicedMs = 0L
        private var childMs = 0L
        private var adultMs = 0L
        private var recordedMs = 0L
        private var transitions = 0
        private var vadFrames = 0
        private var vadVoicedFrames = 0
        private val gapsMs = mutableListOf<Long>()
        private val pitchFrames = mutableListOf<PitchFrame>()
        private val levels = mutableListOf<Double>()
        private val trace = mutableListOf<Map<String, Any>>()

        fun reset() {
            voicedMs = 0
            childMs = 0
            adultMs = 0
            recordedMs = 0
            transitions = 0
            vadFrames = 0
            vadVoicedFrames = 0
            gapsMs.clear()
            pitchFrames.clear()
            levels.clear()
            trace.clear()
        }

        fun addWaveform(level: Double) {
            levels += level
        }

        fun add(features: ChunkFeatures) {
            val offsetMs = recordedMs
            voicedMs += features.voicedMs
            childMs += features.childVoicedMs
            adultMs += features.adultVoicedMs
            recordedMs += features.recordedMs
            transitions += features.transitions
            vadFrames += features.vadFrames
            vadVoicedFrames += features.vadVoicedFrames
            gapsMs += features.transitionGapsMs
            pitchFrames += features.pfvFrames.map { frame ->
                frame.copy(startMs = frame.startMs + offsetMs)
            }
            trace += mapOf(
                "step" to "vad",
                "start_ms" to offsetMs,
                "end_ms" to recordedMs,
                "frames_dropped" to (features.vadFrames - features.vadVoicedFrames),
                "frames_kept" to features.vadVoicedFrames,
            )
            trace += mapOf(
                "step" to "diarize",
                "segments" to features.labelledSegments.size,
            )
        }

        /**
         * Builds the Dart channel contract. Status is COMPLETE only when the
         * session produced enough analysable speech; anything less returns
         * INCOMPLETE with human-readable `quality_reasons` for a retry prompt.
         */
        fun payload(
            audioSource: String,
            age: Int,
            analysisFailure: String?,
        ): Map<String, Any?> {
            val reasons = mutableListOf<String>()
            if (analysisFailure != null) {
                reasons += "Audio analysis could not be completed; please repeat the recording."
            }
            if (voicedMs < 20_000) {
                reasons += "At least 20 seconds of voiced audio is required."
            }
            if (childMs < 5_000) {
                reasons += "At least 5 seconds of child vocalization is required."
            }
            if (transitions < 3) {
                reasons += "At least 3 adult-to-child exchanges are required."
            }

            val vttlMs = FeatureExtractor.medianTransitionGapMs(gapsMs)
            val pfv = pfvAnalyzer.analyzeFrames(pitchFrames, age)
            val cvr = FeatureExtractor.childVocalizationRatio(childMs, recordedMs)
            if (age >= 36 && pfv.insufficientData) {
                reasons += "Not enough confident child pitch frames for prosody analysis."
            }

            val pfvSemitoneSd = pfv.semitoneSd ?: 0.0
            val vttlFlagged = vttlMs > 1000.0
            val pfvFlagged = age >= 36 && !pfv.insufficientData && pfvSemitoneSd < 15.0
            val cvrFlagged = cvr < cvrThreshold(age)
            val complete = reasons.isEmpty() && gapsMs.isNotEmpty()

            val f0Hz = pitchFrames.map { it.f0Hz }
            trace += mapOf(
                "step" to "f0_extract",
                "child_frames" to pfv.framesUsed,
                "f0_mean_hz" to (pfv.f0MeanHz ?: 0.0),
                "f0_std_hz" to (pfv.f0StdHz ?: 0.0),
            )
            trace += mapOf(
                "step" to "protocols",
                "count" to protocolCount,
            )

            return mapOf(
                "vttl_ms" to vttlMs,
                "pfv_std" to pfvSemitoneSd,
                "pfv_z_score" to (pfv.ageZScore ?: 0.0),
                "cvr_ratio" to cvr,
                "vttl_flagged" to vttlFlagged,
                "pfv_flagged" to pfvFlagged,
                "cvr_flagged" to cvrFlagged,
                "child_age_months" to age,
                "audio_source_used" to audioSource,
                "analysis_status" to if (complete) "COMPLETE" else "INCOMPLETE",
                "frames_processed" to vadFrames,
                "voiced_seconds" to voicedMs / 1000.0,
                "child_voiced_seconds" to childMs / 1000.0,
                "adult_voiced_seconds" to adultMs / 1000.0,
                "transition_count" to transitions,
                "quality_reasons" to reasons,
                "waveform" to WaveformSummarizer.summarize(levels),
                "decision_trace" to trace,
                "f0_mean_hz" to (f0Hz.takeIf { it.isNotEmpty() }?.average() ?: 0.0),
            )
        }

        private fun cvrThreshold(ageMonths: Int): Double = when {
            ageMonths < 24 -> 0.08
            ageMonths < 36 -> 0.12
            else -> 0.15
        }
    }
}
