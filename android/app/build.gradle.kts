import java.io.FileInputStream
import java.util.Properties

// Dane klucza podpisu wydań. Plik `android/key.properties` **nie jest
// w repozytorium** (pilnuje tego `android/.gitignore`) i trzyma hasła oraz
// ścieżkę do keystore'a leżącego poza projektem.
//
// Gdy pliku nie ma — na świeżym klonie, u innej osoby, w CI — build release
// nie wywala się, tylko podpisuje kluczem debug jak wcześniej. Taki APK nadaje
// się do sprawdzenia, że aplikacja działa, ale **nie** do rozdania ani do Play
// Store: instalacje podpisane różnymi kluczami nie aktualizują się nawzajem.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()

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

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Własny klucz wydań, gdy `key.properties` jest na miejscu.
            // Wcześniej wydania szły na kluczu debug, co znaczyło, że każdy
            // build z innego komputera dawał APK niezgodny z poprzednim:
            // aktualizacja odmawiała instalacji, a logowanie Google zwracało
            // błąd 10, bo odcisk SHA-1 nie zgadzał się z klientem OAuth.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

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
