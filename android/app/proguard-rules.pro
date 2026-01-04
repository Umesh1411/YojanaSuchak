# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Google Generative AI classes
-keep class com.google.ai.generativelanguage.** { *; }
-keep class com.google.generativeai.** { *; }

# Keep speech recognition classes
-keep class com.csdcorp.speech_to_text.** { *; }

# Keep TTS classes
-keep class com.tundralabs.fluttertts.** { *; }

# Gson specific classes
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent obfuscation of data classes
-keep class com.example.mahavoice_scheme_assistant.models.** { *; }






