package com.suwayomi.tachidesk_sorayomi

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterAndroidVolumeKeydownActivity() {
    companion object {
        private const val PAGE_ACTIONS_CHANNEL =
            "com.suwayomi.tachidesk_sorayomi/reader_page_actions"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PAGE_ACTIONS_CHANNEL,
        ).setMethodCallHandler(::handlePageAction)
    }

    private fun handlePageAction(call: MethodCall, result: MethodChannel.Result) {
        try {
            val file = validatedCacheFile(call.argument<String>("filePath"))
            when (call.method) {
                "copyImage" -> copyImage(file)
                "shareImage" -> shareImage(file, call.argument<String>("message").orEmpty())
                "saveImage" -> {
                    saveImageInBackground(
                        file,
                        call.argument<String>("displayName").orEmpty(),
                        result,
                    )
                    return
                }
                else -> {
                    result.notImplemented()
                    return
                }
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("reader_page_action_failed", error.message, null)
        }
    }

    private fun saveImageInBackground(
        file: File,
        displayName: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                saveImage(file, displayName)
                runOnUiThread { result.success(null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("reader_page_action_failed", error.message, null)
                }
            }
        }.start()
    }

    private fun validatedCacheFile(path: String?): File {
        require(!path.isNullOrBlank()) { "Missing image path" }
        val file = File(path).canonicalFile
        val roots = listOfNotNull(cacheDir, externalCacheDir).map(File::getCanonicalFile)
        val isInsideCache = roots.any { root ->
            file.path.startsWith(root.path + File.separator)
        }
        require(isInsideCache) { "Image is outside the app cache" }
        require(file.isFile && file.canRead()) { "Image is not available" }
        return file
    }

    private fun imageUri(file: File) = FileProvider.getUriForFile(
        this,
        "$packageName.reader_pages",
        file,
    )

    private fun copyImage(file: File) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newUri(contentResolver, file.name, imageUri(file)))
    }

    private fun shareImage(file: File, message: String) {
        val uri = imageUri(file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = detectImageFormat(file).mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            if (message.isNotBlank()) putExtra(Intent.EXTRA_TEXT, message)
            clipData = ClipData.newUri(contentResolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, null))
    }

    private fun saveImage(file: File, requestedName: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IOException("Saving reader images requires Android 10 or newer")
        }

        val format = detectImageFormat(file)
        val baseName = requestedName.ifBlank { "Sorayomi-page" }
        val displayName = if (baseName.lowercase().endsWith(".${format.extension}")) {
            baseName
        } else {
            "$baseName.${format.extension}"
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, format.mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Sorayomi")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            values,
        ) ?: throw IOException("Unable to create the saved image")

        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                FileInputStream(file).use { input -> input.copyTo(output) }
            } ?: throw IOException("Unable to open the saved image")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun detectImageFormat(file: File): ImageFormat {
        val header = ByteArray(16)
        val count = FileInputStream(file).use { it.read(header) }
        if (count >= 8 && header.copyOfRange(0, 8).contentEquals(
                byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A),
            )
        ) return ImageFormat("image/png", "png")
        if (count >= 3 && header[0] == 0xFF.toByte() &&
            header[1] == 0xD8.toByte() && header[2] == 0xFF.toByte()
        ) return ImageFormat("image/jpeg", "jpg")
        if (count >= 6 && String(header, 0, 6, Charsets.US_ASCII).startsWith("GIF8")) {
            return ImageFormat("image/gif", "gif")
        }
        if (count >= 12 && String(header, 0, 4, Charsets.US_ASCII) == "RIFF" &&
            String(header, 8, 4, Charsets.US_ASCII) == "WEBP"
        ) return ImageFormat("image/webp", "webp")
        if (count >= 12 && String(header, 4, 4, Charsets.US_ASCII) == "ftyp") {
            return when (String(header, 8, 4, Charsets.US_ASCII)) {
                "avif", "avis" -> ImageFormat("image/avif", "avif")
                "heic", "heix", "hevc", "hevx", "mif1", "msf1" ->
                    ImageFormat("image/heif", "heic")
                else -> ImageFormat("image/jpeg", "jpg")
            }
        }
        return ImageFormat("image/jpeg", "jpg")
    }

    private data class ImageFormat(val mimeType: String, val extension: String)
}
