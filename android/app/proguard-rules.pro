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
