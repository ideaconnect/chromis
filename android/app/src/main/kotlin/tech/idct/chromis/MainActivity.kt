package tech.idct.chromis

import android.Manifest
import android.app.ActivityManager
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    /** A gallery save waiting on the pre-Q storage permission prompt. */
    private var pendingSave: PendingSave? = null

    private data class PendingSave(
        val name: String,
        val mime: String,
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    // Remove the OS splash instantly (skip the default fade-out) the moment
    // Flutter's first frame is ready, so the native splash hands off to the
    // in-app animated splash with no visible flicker. That first Flutter frame
    // matches windowSplashScreenBackground + the centred logo, so the cut is
    // seamless. See _Splash in lib/app/app.dart.
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
        // BEFORE super.onCreate, which can already register Flutter's own
        // callback when it restores state - see backToBackground.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backToBackground!!,
            )
        }
        super.onCreate(savedInstanceState)
    }

    /**
     * Back on the last route sends the app to the background instead of
     * finishing the activity (#65).
     *
     * Finishing tears the FlutterEngine down while the process lives on, with
     * the AdMob banner's WebView still drawing into a platform-view texture.
     * Both crashes of that teardown are ours to avoid, not to fix: on Mali the
     * engine frees GPU fences the driver's backend thread is still signalling
     * and the process aborts on "pthread_mutex_lock called on a destroyed
     * mutex" (flutter#187703, fixed only in 3.47, which this app cannot take;
     * flutter#191168, open), and on the emulator the WebView trips a CHECK
     * once its texture is closed under it - two back-outs in three, on 3.44.6
     * and 3.44.9 alike. Moving the task back keeps everything alive, which is
     * what Android 12+ does for any other app's root activity, and coming
     * back becomes a warm resume rather than a cold start.
     *
     * This is where the last back lands while back still arrives as
     * `onBackPressed`: below Android 16, or with predictive back off.
     */
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    /**
     * The same as [popSystemNavigator], for Android 16+, where an app
     * targeting 36 gets no `onBackPressed` at all - only OnBackInvokedCallbacks.
     *
     * Flutter registers its callback while a route can pop and unregisters it
     * on the last route, handing that back to the system - which finished the
     * activity, so [popSystemNavigator] never ran. This one stays registered
     * underneath: callbacks of equal priority run most-recent-first, and
     * Flutter's is registered after it every time, so it is reached only when
     * Flutter has stepped aside. Flutter's own judgement of "can pop" is left
     * alone on purpose - keeping its callback registered on the last route
     * instead swallowed the back swipe on Home after any trip to the editor.
     */
    private val backToBackground: OnBackInvokedCallback? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            OnBackInvokedCallback { moveTaskToBack(true) }
        } else {
            null
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

    /**
     * Pre-Q gallery write: `Pictures/Chromis/<name>` on the shared volume,
     * then a media scan so it shows up in the gallery. Runs on [galleryWriter];
     * the permission it needs has already been checked on the main thread.
     *
     * Everything below Android 10 predates scoped storage, so this needs
     * WRITE_EXTERNAL_STORAGE (declared with `maxSdkVersion="28"`). Without it
     * the write threw, the channel answered `save_failed`, and the user got
     * "Couldn't save the image" on every attempt with no way to succeed - and
     * on the free tier, each attempt had already cost a rewarded ad.
     *
     * The old implementation also wrote to Downloads and never ran a media
     * scan, so even with the permission the file would not have appeared where
     * the UI said it would.
     */
    private fun saveToPicturesLegacy(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        try {
            @Suppress("DEPRECATION")
            val pictures = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES,
            )
            val dir = File(pictures, "Chromis")
            dir.mkdirs()
            val file = File(dir, name)
            file.writeBytes(bytes)
            // Without this the file exists but no gallery app lists it.
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf(mime),
                null,
            )
            result.success("Pictures/Chromis/$name")
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_STORAGE) return
        val save = pendingSave ?: return
        pendingSave = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            galleryWriter.execute {
                saveToPicturesLegacy(save.name, save.mime, save.bytes, save.result)
            }
        } else {
            // A distinct code from save_failed: Dart can tell "you said no"
            // from "it broke", and say something the user can act on.
            save.result.error(
                "permission_denied",
                "storage permission is required to save on this Android version",
                null,
            )
        }
    }

    /**
     * Saves [bytes] into the Pictures gallery (`Pictures/Chromis`): MediaStore
     * on Android 10+, which needs no runtime permission, and the legacy file +
     * media-scan path below that, which asks for storage access first.
     *
     * Called on the main thread, and nothing past the permission check may
     * stay on it (#66). The write goes through the media provider's FUSE layer
     * and the final `update` makes it scan the file before returning - 150 ms
     * for a 1.9 MB PNG on an emulator, and a 2 GB phone's storage is several
     * times slower. That is the main thread a tap is waiting on, right after
     * the export's rewarded ad has closed. Replies may come from any thread.
     */
    private fun saveImageToGallery(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                // Ask once, then retry from onRequestPermissionsResult. Only
                // one save can be in flight - the export button disables
                // itself while busy - so a single slot is enough.
                pendingSave = PendingSave(name, mime, bytes, result)
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    REQUEST_WRITE_STORAGE,
                )
                return
            }
            galleryWriter.execute { saveToPicturesLegacy(name, mime, bytes, result) }
            return
        }
        galleryWriter.execute { saveToMediaStore(name, mime, bytes, result) }
    }

    /** Android 10+ gallery write via MediaStore. Runs on [galleryWriter]. */
    private fun saveToMediaStore(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
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
            val resolver = applicationContext.contentResolver
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
        private const val REQUEST_WRITE_STORAGE = 4201

        /**
         * Where gallery writes run - one thread for the process rather than per
         * activity, so an activity recreated mid-save cannot start a second
         * writer beside the first.
         */
        private val galleryWriter: ExecutorService =
            Executors.newSingleThreadExecutor { task -> Thread(task, "chromis-gallery") }
    }
}
