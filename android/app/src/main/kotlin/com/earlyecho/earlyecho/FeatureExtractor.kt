package com.earlyecho.earlyecho

/** Turn-taking and speaker-time totals derived from labelled segments. */
data class TurnSummary(
    val transitionGapsMs: List<Long>,
    val childVoicedMs: Long,
    val adultVoicedMs: Long,
)

/**
 * Converts diarized turns into the acoustic biomarkers.
 *
 * Diarization only reports that someone is speaking; this class attaches the
 * CHILD / ADULT identity with the F0 heuristic (below 200 Hz reads as an
 * adult voice, above 250 Hz as a child, and the band in between stays
 * UNKNOWN so borderline frames never contaminate the biomarkers).
 */
class FeatureExtractor(private val pfvAnalyzer: PfvAnalyzer = PfvAnalyzer()) {
    /**
     * Labels every segment in [chunk], measures turn-taking gaps and speaker
     * durations, and pulls the child pitch contour for PFV analysis.
     */
    fun extract(chunk: ShortArray, segments: List<SpeakerSegment>, childAgeMonths: Int): ChunkFeatures {
        val labelled = segments.map { it.copy(speaker = labelSpeaker(chunk, it)) }
        val summary = summarizeTurns(labelled)
        val childSegments = labelled.filter { it.speaker == SpeakerSegment.SPEAKER_CHILD }
        val pfvFrames = pfvAnalyzer.extractFrames(chunk, childSegments)
        return ChunkFeatures(
            transitionGapsMs = summary.transitionGapsMs,
            childVoicedMs = summary.childVoicedMs,
            adultVoicedMs = summary.adultVoicedMs,
            recordedMs = chunk.size * 1000L / SAMPLE_RATE,
            transitions = summary.transitionGapsMs.size,
            labelledSegments = labelled,
            pfvFrames = pfvFrames,
        )
    }

    /**
     * Estimates the pitch at the head of a segment and applies the F0
     * heuristic: F0 < 200 Hz -> ADULT, F0 > 250 Hz -> CHILD. Low-confidence
     * or ambiguous-pitch segments stay UNKNOWN and are excluded from the
     * child/adult-derived features.
     */
    private fun labelSpeaker(chunk: ShortArray, segment: SpeakerSegment): String {
        val start = (segment.startMs * SAMPLE_RATE / 1000).toInt().coerceAtLeast(0)
        val end = (segment.endMs * SAMPLE_RATE / 1000).toInt().coerceAtMost(chunk.size)
        if (end - start < PfvConfig.frameSizeSamples) return SpeakerSegment.SPEAKER_UNKNOWN
        val labelEnd = (start + PfvConfig.frameSizeSamples).coerceAtMost(end)
        val pitch = pfvAnalyzer.estimatePitch(chunk.copyOfRange(start, labelEnd))
            ?: return SpeakerSegment.SPEAKER_UNKNOWN
        if (pitch.confidence < PfvConfig.minimumConfidence) {
            return SpeakerSegment.SPEAKER_UNKNOWN
        }
        return speakerLabelForF0(pitch.f0Hz)
    }

    companion object {
        const val SAMPLE_RATE = 16_000

        /** F0 below this reads as an adult voice. */
        const val ADULT_MAX_F0_HZ = 200.0

        /** F0 above this reads as a child voice. */
        const val CHILD_MIN_F0_HZ = 250.0

        /** Turn-taking gaps are bucketed into 500 ms bins before the median. */
        const val VTTL_BIN_MS = 500L

        /** F0 heuristic shared by labelling and unit tests. */
        fun speakerLabelForF0(f0Hz: Double): String = when {
            f0Hz < ADULT_MAX_F0_HZ -> SpeakerSegment.SPEAKER_ADULT
            f0Hz > CHILD_MIN_F0_HZ -> SpeakerSegment.SPEAKER_CHILD
            else -> SpeakerSegment.SPEAKER_UNKNOWN
        }

        /**
         * Walks labelled segments in time order, accumulating child and adult
         * voiced time and every adult -> child silence gap.
         */
        fun summarizeTurns(labelled: List<SpeakerSegment>): TurnSummary {
            val gaps = mutableListOf<Long>()
            var childMs = 0L
            var adultMs = 0L
            var lastAdultEnd = -1L
            for (segment in labelled) {
                when (segment.speaker) {
                    SpeakerSegment.SPEAKER_ADULT -> {
                        adultMs += segment.endMs - segment.startMs
                        lastAdultEnd = segment.endMs
                    }
                    SpeakerSegment.SPEAKER_CHILD -> {
                        childMs += segment.endMs - segment.startMs
                        if (lastAdultEnd >= 0 && segment.startMs >= lastAdultEnd) {
                            gaps += segment.startMs - lastAdultEnd
                        }
                    }
                }
            }
            return TurnSummary(gaps, childMs, adultMs)
        }

        /**
         * Median of the adult -> child silence gaps after snapping each gap
         * into its 500 ms bin; the reported value is the bin centre.
         */
        fun medianTransitionGapMs(gapsMs: List<Long>): Double {
            if (gapsMs.isEmpty()) return 0.0
            val bins = gapsMs.map { it / VTTL_BIN_MS }.sorted()
            val middle = bins.size / 2
            val medianBin = if (bins.size % 2 == 1) {
                bins[middle].toDouble()
            } else {
                (bins[middle - 1] + bins[middle]) / 2.0
            }
            return medianBin * VTTL_BIN_MS + VTTL_BIN_MS / 2.0
        }

        /** Child Vocalization Ratio: child voiced ms / total session ms. */
        fun childVocalizationRatio(childVoicedMs: Long, totalSessionMs: Long): Double =
            if (totalSessionMs <= 0) 0.0 else childVoicedMs.toDouble() / totalSessionMs
    }
}
