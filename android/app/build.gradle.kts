import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing keys are read from android/key.properties (git-ignored; copy
// from key.properties.template and fill in). Absent → release falls back to the
// debug keystore so local `flutter run --release` still works, but a Play upload
// REQUIRES the real keystore. See docs/release-and-data-safety.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "tech.idct.chromis"
    // file_picker's flutter_plugin_android_lifecycle requires compileSdk 36.
    // (Only affects which APIs compile; minSdk 26 / targetSdk are unchanged.)
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store identity - matches the code package `namespace`.
        applicationId = "tech.idct.chromis"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Real upload keystore when key.properties is present; debug keys as
            // a dev fallback so `flutter run --release` works without it.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Release builds shrink + obfuscate. ONNX Runtime and ML Kit resolve
            // their Java classes by name via JNI, so they must be kept explicitly
            // (see proguard-rules.pro) or on-device inference aborts the VM.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Release builds ship only real-device ABIs (arm64-v8a, armeabi-v7a). Each ABI
// carries ~60 MiB of native code (ONNX Runtime), and x86_64 is emulator-only -
// shipping it fattens the universal APK. This uses the variant packaging API
// because buildType-level ndk.abiFilters is silently clobbered under the Flutter
// Gradle plugin. Scoped to release so debug keeps all ABIs (x86_64 emulators).
//
// Skipped when the Flutter tool requests `--split-per-abi` so the x86_64 split
// APK (a never-distributed byproduct) stays a valid artifact.
val isSplitPerAbiBuild =
    project.findProperty("split-per-abi")?.toString()?.toBoolean() ?: false
if (!isSplitPerAbiBuild) {
    androidComponents {
        onVariants(selector().withBuildType("release")) { variant ->
            variant.packaging.jniLibs.excludes.add("**/x86_64/**")
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
