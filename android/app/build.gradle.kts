plugins {
    id("com.android.application")
    // Wtyczki Kotlina celowo tu nie ma: od AGP 9 dostarcza ją sam AGP
    // (Built-in Kotlin). Jawne `id("kotlin-android")` sprawiało, że Flutter
    // ostrzegał o nadchodzącym błędzie budowania.
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pl.osp.osp_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pl.osp.osp_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Bez własnych reguł R8 usuwa io.flutter.util.PathUtils i aplikacja
            // wysypuje się przy starcie. Szczegóły w proguard-rules.pro.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Wersja języka bajtowego Kotlina. Wcześniej ustawiana przez `kotlinOptions`
// wewnątrz bloku `android` — wycofane w Kotlinie 2.3, zastąpione blokiem
// `kotlin { compilerOptions }` z aktualnego szablonu Fluttera.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
