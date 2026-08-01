import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
    namespace = "in.co.ptpl.kaamwala_thekedar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "in.co.ptpl.kaamwala_thekedar"
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
