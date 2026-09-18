package com.earlyecho.earlyecho

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.sqrt

/**
 * Pitch-analysis settings for 16 kHz mono screening audio.
 *
 * The semitone reference is only a conversion anchor for the log transform;
 * it is not a clinical baseline and does not imply an expected child F0.
 */
object PfvConfig {
    const val sampleRateHz = 16_000
    const val frameSizeSamples = 512 // 32 ms analysis frame
    const val hopSizeSamples = 256 // 16 ms hop, 50% overlap
    const val minimumPitchHz = 50.0
    const val maximumPitchHz = 600.0
    const val yinAbsoluteThreshold = 0.15
    const val minimumConfidence = 0.85
    const val childMinimumPitchHz = 250.0
    const val childMaximumPitchHz = 600.0
    const val medianWindowFrames = 5
    const val minimumValidFrames = 30
    const val semitoneReferenceHz = 100.0
    const val neighborAgreementSemitones = 1.0
    const val maxContourGapMs = 48L
}

data class PitchEstimate(val f0Hz: Double, val confidence: Double)

data class PitchFrame(
    val f0Hz: Double,
    val confidence: Double,
    val startMs: Long,
)

/**
 * Result of the prosodic F0 variance analysis over child-labelled frames.
 *
 * [semitoneSd] is the contour variability in semitones used for age-bucket
 * z-scoring; [f0StdHz] is the same variability expressed in Hz, which is the
 * unit the `pfv_std` channel field and the Dart scoring threshold expect.
 */
data class PfvResult(
    val semitoneSd: Double?,
    val f0StdHz: Double?,
    val ageZScore: Double?,
    val framesUsed: Int,
    val insufficientData: Boolean,
    val f0MeanHz: Double?,
)

data class PfvAgeReference(
    val label: String,
    val minAgeMonths: Int,
    val maxAgeMonths: Int,
    val meanSemitoneSd: Double,
    val sdSemitoneSd: Double,
)

object PfvAgeReferences {
    /**
     * TODO(clinical-validation): replace these placeholder norms with
     * locally validated, age-banded reference data before field rollout.
     * They are integration defaults only and must not be treated as
     * clinically reviewed thresholds.
     *
     * Buckets mirror the screening age bands: 12–24, 24–36 and 36–60
     * months. Boundary months belong to the higher bucket.
     */
    val placeholderReferences = listOf(
        PfvAgeReference("12-24mo", 12, 23, 1.55, 0.50),
        PfvAgeReference("24-36mo", 24, 35, 1.70, 0.50),
        PfvAgeReference("36-60mo", 36, 60, 1.85, 0.55),
    )

    fun forAge(ageMonths: Int): PfvAgeReference? = placeholderReferences
        .firstOrNull { ageMonths in it.minAgeMonths..it.maxAgeMonths }
}

/** Lightweight YIN pitch tracker exposing both F0 and a confidence score. */
class YinPitchTracker {
    fun estimate(frame: ShortArray): PitchEstimate? {
        if (frame.size < PfvConfig.frameSizeSamples) return null

        val tauMin = PfvConfig.sampleRateHz / PfvConfig.maximumPitchHz.toInt()
        val tauMax = PfvConfig.sampleRateHz / PfvConfig.minimumPitchHz.toInt()
        val yin = DoubleArray(tauMax + 1)
        for (tau in 1..tauMax) {
            var difference = 0.0
            for (i in 0 until frame.size - tau) {
                val delta = frame[i].toDouble() - frame[i + tau].toDouble()
                difference += delta * delta
            }
            yin[tau] = difference
        }

        // Cumulative mean normalized difference keeps small lags from
        // winning over the true period.
        var cumulative = 0.0
        yin[0] = 1.0
        for (tau in 1..tauMax) {
            cumulative += yin[tau]
            yin[tau] = if (cumulative > 0.0) yin[tau] * tau / cumulative else 1.0
        }

        var estimate = -1
        for (tau in tauMin..tauMax) {
            if (yin[tau] < PfvConfig.yinAbsoluteThreshold) {
                var localMinimum = tau
                while (localMinimum < tauMax && yin[localMinimum + 1] < yin[localMinimum]) {
                    localMinimum++
                }
                estimate = localMinimum
                break
            }
        }
        if (estimate == -1) {
            estimate = (tauMin..tauMax).minByOrNull { yin[it] } ?: return null
        }

        val confidence = (1.0 - yin[estimate]).coerceIn(0.0, 1.0)
        val f0 = PfvConfig.sampleRateHz.toDouble() / estimate
        return PitchEstimate(f0, confidence)
    }
}

/**
 * Builds a cleaned F0 contour over child-labelled segments and computes the
 * prosodic variability statistics consumed by the screening result.
 */
class PfvAnalyzer(private val tracker: YinPitchTracker = YinPitchTracker()) {
    fun estimatePitch(samples: ShortArray): PitchEstimate? = tracker.estimate(samples)

    /** Extracts hop-shifted pitch frames inside each child-labelled segment. */
    fun extractFrames(chunk: ShortArray, childSegments: List<SpeakerSegment>): List<PitchFrame> {
        val frames = mutableListOf<PitchFrame>()
        for (segment in childSegments) {
            val start = (segment.startMs * PfvConfig.sampleRateHz / 1000).toInt()
                .coerceAtLeast(0)
            val end = (segment.endMs * PfvConfig.sampleRateHz / 1000).toInt()
                .coerceAtMost(chunk.size)
            var frameStart = start
            while (frameStart + PfvConfig.frameSizeSamples <= end) {
                val frame = chunk.copyOfRange(frameStart, frameStart + PfvConfig.frameSizeSamples)
                tracker.estimate(frame)?.let { estimate ->
                    frames += PitchFrame(
                        f0Hz = estimate.f0Hz,
                        confidence = estimate.confidence,
                        startMs = frameStart * 1000L / PfvConfig.sampleRateHz,
                    )
                }
                frameStart += PfvConfig.hopSizeSamples
            }
        }
        return frames
    }

    /**
     * Cleans the contour (confidence gate, child pitch band, median filter,
     * isolated-outlier removal) then reports variability in both semitones
     * and Hz plus the age-bucketed z-score.
     */
    fun analyzeFrames(frames: List<PitchFrame>, childAgeMonths: Int): PfvResult {
        val eligible = frames
            .asSequence()
            .filter { it.confidence >= PfvConfig.minimumConfidence }
            .filter { it.f0Hz in PfvConfig.childMinimumPitchHz..PfvConfig.childMaximumPitchHz }
            .sortedBy { it.startMs }
            .toList()
        val medianFiltered = medianFilter(eligible)
        val cleaned = removeIsolatedOutliers(medianFiltered)
        val semitones = cleaned.map { toSemitone(it.f0Hz) }
        val reference = PfvAgeReferences.forAge(childAgeMonths)
        if (semitones.size < PfvConfig.minimumValidFrames || reference == null) {
            return PfvResult(
                semitoneSd = null,
                f0StdHz = null,
                ageZScore = null,
                framesUsed = semitones.size,
                insufficientData = true,
                f0MeanHz = cleaned.map { it.f0Hz }.takeIf { it.isNotEmpty() }?.average(),
            )
        }

        val semitoneSd = standardDeviation(semitones)
        val f0Hz = cleaned.map { it.f0Hz }
        val zScore = (semitoneSd - reference.meanSemitoneSd) / reference.sdSemitoneSd
        return PfvResult(
            semitoneSd = semitoneSd,
            f0StdHz = standardDeviation(f0Hz),
            ageZScore = zScore,
            framesUsed = semitones.size,
            insufficientData = false,
            f0MeanHz = f0Hz.average(),
        )
    }

    private fun medianFilter(frames: List<PitchFrame>): List<PitchFrame> {
        if (frames.isEmpty()) return emptyList()
        val radius = PfvConfig.medianWindowFrames / 2
        return frames.indices.map { index ->
            val current = frames[index]
            val start = (index - radius).coerceAtLeast(0)
            val end = (index + radius).coerceAtMost(frames.lastIndex)
            val median = frames.subList(start, end + 1)
                .filter { candidate -> abs(candidate.startMs - current.startMs) <= PfvConfig.maxContourGapMs }
                .map { it.f0Hz }
                .sorted()
                .let { values -> values[values.size / 2] }
            frames[index].copy(f0Hz = median)
        }
    }

    private fun removeIsolatedOutliers(frames: List<PitchFrame>): List<PitchFrame> {
        if (frames.size < 3) return frames
        return frames.filterIndexed { index, frame ->
            if (index == 0 || index == frames.lastIndex) return@filterIndexed true
            val previous = frames[index - 1]
            val next = frames[index + 1]
            if (frame.startMs - previous.startMs > PfvConfig.maxContourGapMs ||
                next.startMs - frame.startMs > PfvConfig.maxContourGapMs
            ) {
                return@filterIndexed true
            }
            val neighborsAgree = abs(toSemitone(previous.f0Hz) - toSemitone(next.f0Hz)) <=
                PfvConfig.neighborAgreementSemitones
            val differsFromPrevious = abs(toSemitone(frame.f0Hz) - toSemitone(previous.f0Hz)) >
                PfvConfig.neighborAgreementSemitones
            val differsFromNext = abs(toSemitone(frame.f0Hz) - toSemitone(next.f0Hz)) >
                PfvConfig.neighborAgreementSemitones
            !(neighborsAgree && differsFromPrevious && differsFromNext)
        }
    }

    companion object {
        /** Converts an F0 in Hz to semitones above the fixed reference. */
        fun toSemitone(f0Hz: Double): Double =
            12.0 * ln(f0Hz / PfvConfig.semitoneReferenceHz) / ln(2.0)

        /** Population standard deviation; empty input yields 0. */
        fun standardDeviation(values: List<Double>): Double {
            if (values.isEmpty()) return 0.0
            val mean = values.average()
            val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
            return sqrt(variance)
        }
    }
}
