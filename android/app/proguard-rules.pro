# ================================================================
# ProGuard Rules untuk DiaCare AI — Production Ready
# ================================================================

# ----------------------------------------------------------------
# Flutter Core
# ----------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ----------------------------------------------------------------
# Firebase
# ----------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Firebase Database (Realtime)
-keep class com.google.firebase.database.** { *; }

# ----------------------------------------------------------------
# TensorFlow Lite
# ----------------------------------------------------------------
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# ----------------------------------------------------------------
# Google Sign-In
# ----------------------------------------------------------------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ----------------------------------------------------------------
# URL Launcher
# ----------------------------------------------------------------
-keep class androidx.browser.** { *; }

# ----------------------------------------------------------------
# PDF / Printing
# ----------------------------------------------------------------
-keep class com.tom_roush.pdfbox.** { *; }
-dontwarn com.tom_roush.pdfbox.**

# ----------------------------------------------------------------
# Image Picker
# ----------------------------------------------------------------
-keep class io.flutter.plugins.imagepicker.** { *; }

# ----------------------------------------------------------------
# Flutter Local Notifications
# ----------------------------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.work.** { *; }
-dontwarn com.dexterous.**

# ----------------------------------------------------------------
# Path Provider
# ----------------------------------------------------------------
-keep class io.flutter.plugins.pathprovider.** { *; }

# ----------------------------------------------------------------
# Package Info Plus
# ----------------------------------------------------------------
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ----------------------------------------------------------------
# Provider / Dart runtime
# ----------------------------------------------------------------
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses

# ----------------------------------------------------------------
# R classes & Exceptions
# ----------------------------------------------------------------
-keepclassmembers class **.R$* {
    public static <fields>;
}
-keep public class * extends java.lang.Exception

# ----------------------------------------------------------------
# Kotlin
# ----------------------------------------------------------------
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ----------------------------------------------------------------
# Play Store Deferred Components (not used)
# ----------------------------------------------------------------
-dontwarn com.google.android.play.core.**

# ----------------------------------------------------------------
# Coroutines
# ----------------------------------------------------------------
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**
