package com.earlyecho.earlyecho.video

import kotlin.math.roundToInt

/**
 * Retains only low-dimensional session-quality counters from live video.
 *
 * Raw frames, facial landmarks, pose landmarks, and person identifiers are
 * intentionally discarded as soon as an inference finishes. These values are
 * never a behavioural, attention, or developmental assessment.
 */
class VideoSessionAggregate {
    private var processedFrames = 0
    private var faceVisibleFrames = 0
    private var frontalFaceFrames = 0
    private var eyesVisibleFrames = 0
    private var bodyVisibleFrames = 0
    private var movementSampleCount = 0
    private var movementTotal = 0.0

    @Synchronized
    fun reset() {
        processedFrames = 0
        faceVisibleFrames = 0
        frontalFaceFrames = 0
        eyesVisibleFrames = 0
        bodyVisibleFrames = 0
        movementSampleCount = 0
        movementTotal = 0.0
    }

    @Synchronized
    fun add(
        faceVisible: Boolean,
        frontalFace: Boolean,
        eyesVisible: Boolean,
        bodyVisible: Boolean,
        normalizedMovement: Double?,
    ) {
        processedFrames += 1
        if (faceVisible) faceVisibleFrames += 1
        if (frontalFace) frontalFaceFrames += 1
        if (eyesVisible) eyesVisibleFrames += 1
        if (bodyVisible) bodyVisibleFrames += 1
        if (normalizedMovement != null) {
            movementSampleCount += 1
            movementTotal += normalizedMovement.coerceIn(0.0, 1.0)
        }
    }

    @Synchronized
    fun snapshot(): Map<String, Any> {
        val faceRatio = ratio(faceVisibleFrames, processedFrames)
        val bodyRatio = ratio(bodyVisibleFrames, processedFrames)
        val quality = when {
            processedFrames == 0 -> "UNAVAILABLE"
            faceRatio >= MIN_FACE_VISIBLE_RATIO && bodyRatio >= MIN_BODY_VISIBLE_RATIO -> "AVAILABLE"
            else -> "LIMITED"
        }
        val reasons = buildList {
            if (processedFrames == 0) {
                add("No usable video frames were analysed.")
            } else {
                if (faceRatio < MIN_FACE_VISIBLE_RATIO) {
                    add("The participant's face was not visible in enough frames.")
                }
                if (bodyRatio < MIN_BODY_VISIBLE_RATIO) {
                    add("The participant's body was not visible in enough frames.")
                }
            }
        }
        return mapOf(
            "analysis_status" to quality,
            "frames_processed" to processedFrames,
            "face_visible_ratio" to rounded(faceRatio),
            "frontal_face_ratio" to rounded(ratio(frontalFaceFrames, processedFrames)),
            "eyes_visible_ratio" to rounded(ratio(eyesVisibleFrames, processedFrames)),
            "body_visible_ratio" to rounded(bodyRatio),
            "movement_score" to rounded(
                if (movementSampleCount == 0) 0.0 else movementTotal / movementSampleCount,
            ),
            "quality_reasons" to reasons,
            "raw_video_retained" to false,
        )
    }

    private fun ratio(numerator: Int, denominator: Int): Double =
        if (denominator == 0) 0.0 else numerator.toDouble() / denominator

    private fun rounded(value: Double): Double = (value * 1000.0).roundToInt() / 1000.0

    private companion object {
        const val MIN_FACE_VISIBLE_RATIO = 0.25
        const val MIN_BODY_VISIBLE_RATIO = 0.20
    }
}
