import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

// Only applied once the real `google-services.json` (from Firebase console →
// Project settings → download for this app's package name) is dropped in —
// the plugin itself hard-fails the build when that file is missing, and push
// notifications are meant to degrade gracefully until then, not break local
// builds for everyone else on the team.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// The Maps SDK reads its key from the manifest, so `--dart-define` cannot reach
// it the way it does on web. CI supplies MAPS_API_KEY as an environment
// variable; locally, put `maps.apiKey=...` in android/local.properties, which is
// already git-ignored. Empty is allowed — the app then falls back to its
// stylised map instead of failing to build.
val mapsApiKey: String = System.getenv("MAPS_API_KEY")
    ?: rootProject.file("local.properties").let { file ->
        if (file.exists()) {
            Properties().apply { file.inputStream().use { load(it) } }
                .getProperty("maps.apiKey") ?: ""
        } else {
            ""
        }
    }

android {
    namespace = "com.ovsofts.thekedar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time APIs under the hood on
        // API levels below 33 and needs this to link against them.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ovsofts.thekedar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
