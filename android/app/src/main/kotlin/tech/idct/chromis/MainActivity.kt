package tech.idct.chromis

import android.app.ActivityManager
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    // Remove the OS splash instantly (skip the default fade-out) the moment
    // Flutter's first frame is ready, so the native splash hands off to the
    // in-app animated splash with no visible flicker. That first Flutter frame
    // matches windowSplashScreenBackground + the centred logo, so the cut is
    // seamless. See _Splash in lib/app/app.dart.
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Device RAM snapshot so Dart can gate heavy AI features
                    // (the SAM object-removal tier) on device capability.
                    "getMemoryInfo" -> {
                        try {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val info = ActivityManager.MemoryInfo()
                            am.getMemoryInfo(info)
                            result.success(
                                mapOf(
                                    "totalMem" to info.totalMem,
                                    "availMem" to info.availMem,
                                    "lowRam" to am.isLowRamDevice,
                                ),
                            )
                        } catch (e: Exception) {
                            result.error("memory_info_failed", e.message, null)
                        }
                    }
                    // Saves an image into the Pictures gallery (MediaStore.Images).
                    "saveImageToGallery" -> {
                        val name = call.argument<String>("fileName")
                        val mime = call.argument<String>("mimeType") ?: "image/png"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (name.isNullOrEmpty() || bytes == null) {
                            result.error("bad_args", "fileName and bytes are required", null)
                        } else {
                            saveImageToGallery(name, mime, bytes, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Inserts [bytes] as a new file in the public Downloads collection. */
    private fun saveToDownloads(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.MIME_TYPE, mime)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("MediaStore insert returned null")
                resolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: throw IllegalStateException("could not open output stream")
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success("Downloads/$name")
            } else {
                // API 26-28: legacy external Downloads dir (predates scoped storage).
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS,
                )
                dir.mkdirs()
                val file = File(dir, name)
                file.writeBytes(bytes)
                result.success(file.absolutePath)
            }
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    /**
     * Inserts [bytes] as a new image in the Pictures gallery
     * (`Pictures/Chromis`) via MediaStore on Android 10+ - no runtime
     * permission needed. Pre-Q falls back to the Downloads collection.
     */
    private fun saveImageToGallery(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            saveToDownloads(name, mime, bytes, result)
            return
        }
        try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Chromis",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values,
            ) ?: throw IllegalStateException("MediaStore insert returned null")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("could not open output stream")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            result.success("Pictures/Chromis/$name")
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    companion object {
        private const val PLATFORM_CHANNEL = "chromis/platform"
    }
}
