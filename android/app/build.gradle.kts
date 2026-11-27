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

// Wersja testowa obok wersji ze Sklepu Play (Dawid, 27.11.2026): tester nie
// musi odinstalowywać aplikacji ze Sklepu. Inny identyfikator, nazwa
// „Raporty OSP TEST" i granatowa ikona z napisem TEST:
//
//   flutter build apk --release --target-platform android-arm64 \
//     --android-project-arg=testowa=true --dart-define=OSP_TEST=true
//
// Firebase wymaga, żeby `pl.osp.osp_app.test` był zarejestrowany w projekcie
// i obecny w google-services.json.
val testBuild = project.hasProperty("testowa")

plugins {
    id("com.android.application")
    // Wtyczki Kotlina celowo tu nie ma: od AGP 9 dostarcza ją sam AGP
    // (Built-in Kotlin). Jawne `id("kotlin-android")` sprawiało, że Flutter
    // ostrzegał o nadchodzącym błędzie budowania.
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Konfiguracja Firebase (feature/081) z `android/app/google-services.json`.
// Pliku **nie ma w repozytorium** (`.gitignore`) — pobiera się go z konsoli
// Firebase (projekt osp-app-2026). Bez niego build idzie dalej, ale aplikacja
// nie połączy się z serwerem jednostek.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "UWAGA: brak android/app/google-services.json — aplikacja bez " +
            "połączenia z serwerem Firebase. Nie rozdawaj takiego APK."
    )
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
        // Wersja testowa ma własny identyfikator — instaluje się obok wersji
        // ze Sklepu Play zamiast ją zastępować.
        applicationId = if (testBuild) "pl.osp.osp_app.test" else "pl.osp.osp_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] =
            if (testBuild) "Raporty OSP TEST" else "Raporty OSP"
        manifestPlaceholders["appIcon"] =
            if (testBuild) "@mipmap/ic_launcher_test" else "@mipmap/ic_launcher"
    }

    // Ikona wersji testowej (tool/osp_icons/build_test_icon.py) — tylko
    // w wersji testowej, zwykły build jej nie zawiera.
    if (testBuild) {
        sourceSets.getByName("main").res.srcDir("src/testowa/res")
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
                // Głośno, bo po cichu to już raz się stało: po zmianie
                // komputera paczka „do rozdania" wyszła na kluczu debug.
                logger.warn(
                    "UWAGA: brak android/key.properties — wydanie podpisane " +
                        "kluczem DEBUG. Taki APK nie zaktualizuje aplikacji " +
                        "u kolegów. Nie rozdawaj go."
                )
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
