# R8/ProGuard keep rules for the release build.
#
# Release builds shrink + obfuscate Java/Kotlin. Everything below is here because
# something resolves a class or member BY NAME at runtime, which R8 cannot see.

# Room instantiates every database through reflection - getGeneratedImplementation
# does Class.forName("<db>_Impl") and then calls its no-arg constructor - so R8
# has to keep both the generated subclass and a usable constructor. androidx.work
# arrives transitively (the ads SDK) and its WorkDatabase is initialised by
# androidx.startup BEFORE Flutter runs, so stripping it kills the app on launch,
# with no Dart frame anywhere in the trace:
#   FATAL EXCEPTION: main
#   Unable to get provider androidx.startup.InitializationProvider
#   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
#     at androidx.work.WorkManagerInitializer
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.room.paging.**

# ONNX Runtime (flutter_onnxruntime, #28). Symptom when stripped:
#   "JNI DETECTED ERROR IN APPLICATION: java_class == null in call to
#    GetMethodID ... convertToTensorInfo ... Java_ai_onnxruntime_OrtSession_run"
# The native onnxruntime4j_jni looks up ai.onnxruntime.TensorInfo, OnnxJavaType,
# OnnxTensorLike, … by name, so keep the whole package and its members.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Google ML Kit Subject Segmentation (#26) + its dynamically-loaded modules.
# ML Kit resolves optional model modules reflectively; keep it and the gms
# internal mlkit classes so the "Built-in AI" engine survives shrinking.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.mlkit.**
