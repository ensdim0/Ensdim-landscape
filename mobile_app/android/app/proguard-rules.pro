# =============================================================================
# ProGuard / R8 rules for Flutter + Supabase mobile app
# =============================================================================
# These rules protect against reverse engineering by obfuscating class names,
# method names, and removing unused code.

# --- Flutter ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# --- Supabase / GoTrue / PostgREST ---
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# --- OkHttp (used by Supabase under the hood) ---
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# --- Kotlin serialization ---
-keepattributes *Annotation*
-keepattributes InnerClasses
-dontwarn kotlinx.serialization.**

# --- Flutter Secure Storage ---
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# --- Jailbreak Detection ---
-keep class com.scottyab.rootbeer.** { *; }

# --- Safe Device ---
-keep class com.lucasjosino.** { *; }

# --- Package Info Plus ---
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# --- Geolocator / Location services ---
-keep class com.baseflow.geolocator.** { *; }
-keep class io.flutter.plugins.geolocator.** { *; }
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.baseflow.geolocator.**
-dontwarn com.google.android.gms.location.**

# --- Image Picker ---
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# --- General security ---
# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

# Prevent decompilers from extracting string constants easily
-adaptclassstrings
-adaptresourcefilenames
-adaptresourcefilecontents

# Obfuscate all non-kept classes
-repackageclasses ''
-allowaccessmodification
-optimizationpasses 5
