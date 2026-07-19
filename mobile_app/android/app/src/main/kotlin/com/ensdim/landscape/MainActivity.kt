package com.ensdim.landscape

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val GALLERY_CHANNEL = "ensdim_landscape/gallery"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GALLERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImageToGallery") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val folderName = call.argument<String>("folderName") ?: "Ensdim Landscape System"

                if (bytes == null || fileName.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Missing image bytes or file name", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedUri = saveImageToGallery(bytes, fileName, folderName)
                    result.success(savedUri)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
    }

    private fun saveImageToGallery(
        imageBytes: ByteArray,
        fileName: String,
        folderName: String,
    ): String {
        val mimeType = guessMimeType(fileName)
        val resolver = applicationContext.contentResolver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/$folderName"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val imageUri = resolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                contentValues
            ) ?: throw IllegalStateException("Unable to create MediaStore record")

            resolver.openOutputStream(imageUri)?.use { output ->
                output.write(imageBytes)
            } ?: throw IllegalStateException("Unable to open output stream")

            contentValues.clear()
            contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(imageUri, contentValues, null, null)

            return imageUri.toString()
        }

        val picturesDir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_PICTURES
        )
        val appDir = File(picturesDir, folderName)
        if (!appDir.exists()) {
            appDir.mkdirs()
        }

        val file = File(appDir, fileName)
        FileOutputStream(file).use { stream ->
            stream.write(imageBytes)
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeType),
            null
        )

        return file.absolutePath
    }

    private fun guessMimeType(fileName: String): String {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".gif") -> "image/gif"
            lower.endsWith(".bmp") -> "image/bmp"
            else -> "image/jpeg"
        }
    }
}
