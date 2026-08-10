# Reguły R8 dla buildów release.
#
# path_provider_android sięga po io.flutter.util.PathUtils przez JNI, czyli
# po nazwie klasy. R8 takiego odwołania nie widzi, więc uznaje klasę za martwą
# i ją usuwa (potwierdzone w build/app/outputs/mapping/release/usage.txt).
# Skutkiem jest ClassNotFoundException przy Hive.initFlutter() w pierwszej
# linijce main() — aplikacja zawiesza się na systemowym ekranie startowym.
-keep class io.flutter.util.PathUtils { *; }

# Pozostałe klasy silnika, po które wtyczki sięgają refleksyjnie lub przez JNI.
# Bez tego ten sam problem wróci przy kolejnej wtyczce.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Pakiet jni buduje mostki do klas Javy po nazwie.
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn com.github.dart_lang.jni.**
