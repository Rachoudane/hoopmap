# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase (firestore/auth/core): no POJO reflection is used (court_mapper.dart
# maps documents by hand), but these are Firebase's own recommended keep
# rules for the SDKs' internal use of annotations/generics.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Core (deferred components): the app doesn't use deferred/dynamic
# feature delivery, but the Flutter engine's embedding references these
# Play Core classes defensively regardless, so R8 flags them as missing
# without these -dontwarn lines (matches moto/wingman's proguard-rules.pro).
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
