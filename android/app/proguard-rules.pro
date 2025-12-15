# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep BackendLoggingService
-keep class nl.liionpower.app.BackendLoggingService { *; }
-keepclassmembers class nl.liionpower.app.BackendLoggingService {
    *;
}

# Keep Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.** {
    volatile <fields>;
}
-keep class kotlinx.coroutines.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep all model classes that might be used with Firestore
-keep class * implements java.io.Serializable { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile




