package com.earlyecho.earlyecho

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log

/**
 * Captures raw microphone audio for the EarlyEcho screening pipeline.
 *
 * The capture contract is 16 kHz mono 16-bit PCM. UNPROCESSED is requested
 * first so OEM gain control, noise suppression, and echo cancellation do not
 * distort the acoustic biomarkers. Devices that reject UNPROCESSED fall back
 * to VOICE_RECOGNITION, and whichever source produced the stream is reported
 * through [audioSourceUsed] so the result payload can flag degraded captures.
 */
class UnprocessedAudioRecorder {
    val sampleRate = 16_000
    val channelConfig = AudioFormat.CHANNEL_IN_MONO
    val audioFormat = AudioFormat.ENCODING_PCM_16BIT

    private var audioRecord: AudioRecord? = null

    /** Which AudioSource produced the stream; surfaced in the pipeline result. */
    var audioSourceUsed: String = "UNPROCESSED"
        private set

    private val minBufferBytes =
        AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)

    /**
     * Initialises the microphone and starts capture. Returns false when no
     * usable input source can be opened (for example when the mic is locked
     * by another app or permission was denied at the platform level).
     */
    fun startRecording(): Boolean {
        releaseRecord()
        audioRecord = buildRecord(MediaRecorder.AudioSource.UNPROCESSED)
        if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
            audioSourceUsed = "UNPROCESSED"
        } else {
            Log.w(TAG, "UNPROCESSED source unavailable, trying VOICE_RECOGNITION")
            releaseRecord()
            audioRecord = buildRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            audioSourceUsed = "VOICE_RECOGNITION"
        }

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord could not be initialised with any source")
            releaseRecord()
            return false
        }

        return try {
            audioRecord?.startRecording()
            true
        } catch (e: IllegalStateException) {
            Log.e(TAG, "AudioRecord failed to start", e)
            releaseRecord()
            false
        }
    }

    private fun buildRecord(source: Int): AudioRecord =
        AudioRecord.Builder()
            .setAudioSource(source)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .setEncoding(audioFormat)
                    .build()
            )
            // Four times the platform minimum keeps the read loop ahead of
            // the hardware even while a 10 s analysis window is being filled.
            .setBufferSizeInBytes(minBufferBytes * 4)
            .build()

    /** Blocking read of up to [sizeInShorts] samples into [buffer]. */
    fun read(buffer: ShortArray, offsetInShorts: Int, sizeInShorts: Int): Int =
        audioRecord?.read(buffer, offsetInShorts, sizeInShorts) ?: 0

    fun stopRecording() {
        try {
            if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                audioRecord?.stop()
            }
        } catch (e: IllegalStateException) {
            Log.w(TAG, "AudioRecord was already stopped", e)
        } finally {
            releaseRecord()
        }
    }

    private fun releaseRecord() {
        audioRecord?.release()
        audioRecord = null
    }

    private companion object {
        const val TAG = "UnprocessedAudioRecorder"
    }
}
