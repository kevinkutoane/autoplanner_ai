# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }

# MSAL
-keep class com.microsoft.identity.** { *; }

# Hive & TypeAdapters
-keep class ** extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class * extends hive.TypeAdapter { *; }

# flutter_secure_storage — Android Keystore provider
-keep class androidx.security.crypto.** { *; }

# Workmanager Background Tasks
-keep class androidx.work.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# HomeWidget
-keep class es.antonborri.home_widget.** { *; }

# AndroidX BiometricPrompt
-keep class androidx.biometric.** { *; }

# Keep annotations
-keepattributes *Annotation*
