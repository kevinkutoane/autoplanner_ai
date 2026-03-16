# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }

# MSAL
-keep class com.microsoft.identity.** { *; }

# Hive
-keep class ** extends com.google.protobuf.GeneratedMessageLite { *; }

# flutter_secure_storage — Android Keystore provider
-keep class androidx.security.crypto.** { *; }

# Keep annotations
-keepattributes *Annotation*
