package com.earlyecho.earlyecho.video

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.PointF
import android.media.Image
import android.os.SystemClock
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs
import kotlin.math.hypot

/**
 * A bounded, on-device CameraX analysis pipeline that runs independently from
 * microphone capture. It drives a Flutter texture preview and extracts only
 * aggregated framing and movement-quality signals; it never records a video
 * file or stores individual frames, landmarks, or face tracking IDs.
 */
class VideoPipeline(private val activity: FlutterActivity) {
    private val context: Context = activity
    private val lifecycleOwner: LifecycleOwner = activity
    private val mainExecutor = ContextCompat.getMainExecutor(context)
    private val analyzerExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val aggregate = VideoSessionAggregate()
    private val generation = AtomicInteger(0)
    private val frameInFlight = AtomicBoolean(false)

    private val faceDetector: FaceDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .setMinFaceSize(0.12f)
            .build(),
    )
    private val poseDetector = PoseDetection.getClient(
        PoseDetectorOptions.Builder()
            .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
            .build(),
    )

    @Volatile
    private var capturing = false
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var previewSurface: Surface? = null
    private var permissionResult: MethodChannel.Result? = null
    private var lastFrameAtMs = 0L
    private var previousBodyCenter: PointF? = null

    /**
     * Supplies the Flutter texture surface. Rebinding while capture is active
     * lets a preview that becomes available slightly after the user starts a
     * session appear without interrupting the independent audio capture.
     */
    fun setPreviewSurface(surface: Surface?) {
        previewSurface = surface
        val provider = cameraProvider
        if (capturing && provider != null) {
            try {
                bindUseCases(provider, generation.get())
            } catch (_: Exception) {
                // Video analysis remains available even if the optional preview cannot rebind.
            }
        }
    }

    fun requestCameraPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("ERR_PERMISSION_PENDING", "Camera permission is already being requested", null)
            return
        }
        permissionResult = result
        activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST)
    }

    fun onCameraPermissionResult(granted: Boolean) {
        val pending = permissionResult ?: return
        permissionResult = null
        if (granted) {
            pending.success(true)
        } else {
            pending.error("ERR_PERMISSION", "Camera permission was not granted", null)
        }
    }

    fun start(onStarted: () -> Unit, onError: (String) -> Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            onError("Camera permission is required")
            return
        }
        if (capturing) {
            onStarted()
            return
        }

        aggregate.reset()
        previousBodyCenter = null
        lastFrameAtMs = 0L
        capturing = true
        val captureGeneration = generation.incrementAndGet()
        ProcessCameraProvider.getInstance(context).addListener({
            try {
                if (!capturing || captureGeneration != generation.get()) return@addListener
                val provider = ProcessCameraProvider.getInstance(context).get()
                cameraProvider = provider
                bindUseCases(provider, captureGeneration)
                onStarted()
            } catch (error: Exception) {
                capturing = false
                onError(error.message ?: "Could not start the camera")
            }
        }, mainExecutor)
    }

    /** Stops camera use immediately and returns only aggregated quality data. */
    fun stopAndCollect(): Map<String, Any> {
        capturing = false
        generation.incrementAndGet()
        imageAnalysis?.clearAnalyzer()
        imageAnalysis = null
        cameraProvider?.unbindAll()
        frameInFlight.set(false)
        previousBodyCenter = null
        return aggregate.snapshot()
    }

    fun close() {
        stopAndCollect()
        permissionResult?.error("ERR_CANCELLED", "Camera request was cancelled", null)
        permissionResult = null
        faceDetector.close()
        poseDetector.close()
        analyzerExecutor.shutdownNow()
    }

    private fun bindUseCases(provider: ProcessCameraProvider, captureGeneration: Int) {
        provider.unbindAll()
        val analysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(480, 360))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
        analysis.setAnalyzer(analyzerExecutor) { imageProxy ->
            analyseFrame(imageProxy, captureGeneration)
        }
        imageAnalysis = analysis

        val useCases = mutableListOf<UseCase>(analysis)
        previewSurface?.let { surface ->
            val preview = Preview.Builder().setTargetResolution(Size(480, 360)).build()
            preview.setSurfaceProvider { request ->
                request.provideSurface(surface, mainExecutor) { }
            }
            useCases += preview
        }

        val selector = if (provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        provider.bindToLifecycle(lifecycleOwner, selector, *useCases.toTypedArray())
    }

    private fun analyseFrame(
        imageProxy: androidx.camera.core.ImageProxy,
        captureGeneration: Int,
    ) {
        val now = SystemClock.elapsedRealtime()
        if (!capturing ||
            captureGeneration != generation.get() ||
            now - lastFrameAtMs < FRAME_INTERVAL_MS ||
            !frameInFlight.compareAndSet(false, true)
        ) {
            imageProxy.close()
            return
        }
        lastFrameAtMs = now
        val mediaImage: Image = imageProxy.image ?: run {
            frameInFlight.set(false)
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

        faceDetector.process(image).addOnCompleteListener { faceTask ->
            val face = if (faceTask.isSuccessful) selectPrimaryFace(faceTask.result ?: emptyList()) else null
            val faceObservation = FaceObservation.from(face)
            poseDetector.process(image).addOnCompleteListener { poseTask ->
                try {
                    if (capturing && captureGeneration == generation.get()) {
                        val poseObservation = if (poseTask.isSuccessful) {
                            PoseObservation.from(poseTask.result)
                        } else {
                            PoseObservation.none()
                        }
                        aggregate.add(
                            faceVisible = faceObservation.visible,
                            frontalFace = faceObservation.frontal,
                            eyesVisible = faceObservation.eyesVisible,
                            bodyVisible = poseObservation.visible,
                            normalizedMovement = movementFor(poseObservation),
                        )
                    }
                } finally {
                    frameInFlight.set(false)
                    imageProxy.close()
                }
            }
        }
    }

    private fun selectPrimaryFace(faces: List<Face>): Face? =
        faces.maxByOrNull { face -> face.boundingBox.width() * face.boundingBox.height() }

    private fun movementFor(observation: PoseObservation): Double? {
        if (!observation.visible || observation.center == null || observation.scale == null) {
            previousBodyCenter = null
            return null
        }
        val previous = previousBodyCenter
        previousBodyCenter = observation.center
        if (previous == null) return null
        return (hypot(
            (observation.center.x - previous.x).toDouble(),
            (observation.center.y - previous.y).toDouble(),
        ) / observation.scale).coerceIn(0.0, 1.0)
    }

    private data class FaceObservation(
        val visible: Boolean,
        val frontal: Boolean,
        val eyesVisible: Boolean,
    ) {
        companion object {
            fun from(face: Face?): FaceObservation {
                if (face == null) return FaceObservation(false, false, false)
                val frontal = abs(face.headEulerAngleY) <= MAX_YAW_DEGREES &&
                    abs(face.headEulerAngleX) <= MAX_PITCH_DEGREES
                val eyesVisible = (face.leftEyeOpenProbability ?: 0f) >= EYE_OPEN_CONFIDENCE &&
                    (face.rightEyeOpenProbability ?: 0f) >= EYE_OPEN_CONFIDENCE
                return FaceObservation(true, frontal, eyesVisible)
            }
        }
    }

    private data class PoseObservation(
        val visible: Boolean,
        val center: PointF?,
        val scale: Double?,
    ) {
        companion object {
            fun none(): PoseObservation = PoseObservation(false, null, null)

            fun from(pose: Pose?): PoseObservation {
                if (pose == null) return none()
                val visibleLandmarks = pose.allPoseLandmarks.count {
                    it.inFrameLikelihood >= POSE_LANDMARK_CONFIDENCE
                }
                val left = pose.getPoseLandmark(PoseLandmark.LEFT_SHOULDER)
                val right = pose.getPoseLandmark(PoseLandmark.RIGHT_SHOULDER)
                if (visibleLandmarks < MIN_VISIBLE_POSE_LANDMARKS || left == null || right == null) {
                    return none()
                }
                if (left.inFrameLikelihood < POSE_LANDMARK_CONFIDENCE ||
                    right.inFrameLikelihood < POSE_LANDMARK_CONFIDENCE
                ) {
                    return none()
                }
                val center = PointF(
                    (left.position.x + right.position.x) / 2f,
                    (left.position.y + right.position.y) / 2f,
                )
                val scale = hypot(
                    (left.position.x - right.position.x).toDouble(),
                    (left.position.y - right.position.y).toDouble(),
                )
                return PoseObservation(scale >= MIN_SHOULDER_DISTANCE, center, scale)
            }
        }
    }

    private companion object {
        const val CAMERA_PERMISSION_REQUEST = 43
        const val FRAME_INTERVAL_MS = 250L
        const val MAX_YAW_DEGREES = 25f
        const val MAX_PITCH_DEGREES = 30f
        const val EYE_OPEN_CONFIDENCE = 0.5f
        const val POSE_LANDMARK_CONFIDENCE = 0.5f
        const val MIN_VISIBLE_POSE_LANDMARKS = 8
        const val MIN_SHOULDER_DISTANCE = 12.0
    }
}
