import java.security.MessageDigest

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.earlyecho.earlyecho"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.earlyecho.earlyecho"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // On-device ONNX inference for the bundled speaker-segmentation model.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.18.0")
    // Prebuilt WebRTC VAD artifact used by the frame-level speech mask.
    implementation("com.cloudflare.realtimekit.android-vad:webrtc:2.0.10-cf.4")
    testImplementation("junit:junit:4.13.2")
}

// The pinned segmentation model is checked at build time. It ships inside the
// APK assets; the app never downloads a model at runtime.
tasks.register("verifySegmentationModel") {
    val model = file("src/main/assets/models/pyannote-segmentation-3.0.onnx")
    val manifest = file("src/main/assets/models/SHA256SUMS")
    doLast {
        check(model.exists()) { "Missing pinned segmentation ONNX model: $model" }
        check(manifest.exists()) { "Missing model checksum manifest: $manifest" }
        val expected = manifest.readLines()
            .firstOrNull { it.endsWith("  pyannote-segmentation-3.0.onnx") }
            ?.substringBefore("  ")?.trim()
        check(!expected.isNullOrBlank()) { "Checksum manifest has no model entry" }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(model.readBytes())
            .joinToString("") { byte -> "%02x".format(byte) }
        check(digest.equals(expected, ignoreCase = true)) {
            "Segmentation model SHA-256 mismatch"
        }
    }
}

tasks.named("preBuild") { dependsOn("verifySegmentationModel") }
