# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core (for Flutter's deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }
-dontwarn com.google.firebase.messaging.**
-dontwarn com.google.firebase.iid.**

# WebSocket
-keep class org.java_websocket.** { *; }
-keep interface org.java_websocket.** { *; }
-dontwarn org.java_websocket.**

# Web Socket Channel (Dart)
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# OkHttp (used by Dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit (if used)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# Gson (if used by Firebase or other libraries)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep notification related classes
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class com.example.fireout.PermissionReminderService { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Location services
-keep class com.lyokone.location.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.lyokone.location.**
-dontwarn com.baseflow.geolocator.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

# Keep your custom classes
-keep class com.example.fireout.** { *; }

# General Android
-keep class android.support.** { *; }
-keep class androidx.** { *; }
-dontwarn android.support.**
-dontwarn androidx.**

# Keep serialization classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Prevent obfuscation of method names used by reflection
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes SourceFile
-keepattributes LineNumberTable
-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep method channels
-keep class ** {
    public static final java.lang.String CHANNEL_NAME;
}