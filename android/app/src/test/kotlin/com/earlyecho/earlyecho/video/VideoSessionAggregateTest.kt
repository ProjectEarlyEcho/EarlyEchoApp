package com.earlyecho.earlyecho.video

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class VideoSessionAggregateTest {
    @Test
    fun `summary contains only rounded aggregate quality signals`() {
        val aggregate = VideoSessionAggregate()
        aggregate.add(
            faceVisible = true,
            frontalFace = true,
            eyesVisible = true,
            bodyVisible = true,
            normalizedMovement = null,
        )
        aggregate.add(
            faceVisible = true,
            frontalFace = false,
            eyesVisible = false,
            bodyVisible = true,
            normalizedMovement = 0.25,
        )
        aggregate.add(
            faceVisible = false,
            frontalFace = false,
            eyesVisible = false,
            bodyVisible = false,
            normalizedMovement = null,
        )
        aggregate.add(
            faceVisible = false,
            frontalFace = false,
            eyesVisible = false,
            bodyVisible = false,
            normalizedMovement = 0.75,
        )

        val summary = aggregate.snapshot()

        assertEquals("AVAILABLE", summary["analysis_status"])
        assertEquals(4, summary["frames_processed"])
        assertEquals(0.5, summary["face_visible_ratio"])
        assertEquals(0.25, summary["frontal_face_ratio"])
        assertEquals(0.25, summary["eyes_visible_ratio"])
        assertEquals(0.5, summary["body_visible_ratio"])
        assertEquals(0.5, summary["movement_score"])
        assertFalse(summary.containsKey("frame"))
        assertEquals(false, summary["raw_video_retained"])
    }

    @Test
    fun `empty capture is unavailable and reports no retained video`() {
        val summary = VideoSessionAggregate().snapshot()

        assertEquals("UNAVAILABLE", summary["analysis_status"])
        assertEquals(listOf("No usable video frames were analysed."), summary["quality_reasons"])
        assertEquals(false, summary["raw_video_retained"])
    }
}
