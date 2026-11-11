import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing config from android/key.properties if it exists.
// This file (and the keystore) are gitignored — see key.properties.example.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// A release signed with the debug key can't update the Play Store app and
// fails App Links verification, so don't build one by accident. For a quick
// local test build only, set STARLINK_ALLOW_DEBUG_RELEASE=1.
val allowDebugRelease = System.getenv("STARLINK_ALLOW_DEBUG_RELEASE") == "1"
val buildingRelease =
    gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (buildingRelease && !keystorePropertiesFile.exists() && !allowDebugRelease) {
    throw GradleException(
        "android/key.properties is missing, so this release would be signed with the " +
            "debug key. Add the release keystore (see android/key.properties.example), " +
            "or set STARLINK_ALLOW_DEBUG_RELEASE=1 for a local test build only."
    )
}

android {
    namespace = "com.ardentnetworks.starlink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.3.13750724"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Add compiler options to suppress warnings
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ardentnetworks.starlink"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // The real release keystore from android/key.properties. Debug signing
            // only when STARLINK_ALLOW_DEBUG_RELEASE=1 (checked above).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Disable lintVital for release builds. On Windows the lint cache
    // jars are frequently locked by another JVM (Android Studio / a
    // leftover daemon), causing lintVitalAnalyzeRelease to fail with
    // "The process cannot access the file because it is being used by
    // another process". Flutter apps don't rely on this lint pass.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // Disable the SDK dependency metadata generator. It drives the
    // :app:sdkReleaseDependencyData task, which intermittently fails the
    // release build looking for a dependencies.pb that was never produced.
    // We don't publish to Play with these signed metadata blobs, so turning
    // it off is safe and avoids the flaky input-file-does-not-exist error.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// Firebase Cloud Messaging: apply the Google Services plugin only when
// google-services.json is present, so the build still works without it.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
