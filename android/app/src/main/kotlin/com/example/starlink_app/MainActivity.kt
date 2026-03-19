package com.example.starlink_app

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
  private val channelName = "starlink_app/downloads"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "saveToDownloads" -> {
          val args = call.arguments as? Map<*, *>
          val filename = (args?.get("filename") as? String)?.trim().orEmpty()
          val mimeType = (args?.get("mimeType") as? String)?.trim().orEmpty()
          val bytes = args?.get("bytes") as? ByteArray

          if (filename.isEmpty() || bytes == null) {
            result.error("BAD_ARGS", "filename and bytes are required", null)
            return@setMethodCallHandler
          }

          try {
            val savedUri = saveBytesToDownloads(
              filename = filename,
              mimeType = if (mimeType.isEmpty()) "application/octet-stream" else mimeType,
              bytes = bytes
            )
            result.success(savedUri.toString())
          } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun saveBytesToDownloads(filename: String, mimeType: String, bytes: ByteArray): Uri {
    val resolver = applicationContext.contentResolver

    val values = ContentValues().apply {
      put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
      put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        // Visible in Files app: Downloads/Starlink
        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Starlink")
        put(MediaStore.MediaColumns.IS_PENDING, 1)
      }
    }

    val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      MediaStore.Downloads.EXTERNAL_CONTENT_URI
    } else {
      // Pre-Android 10: still try Downloads collection
      MediaStore.Downloads.EXTERNAL_CONTENT_URI
    }

    val itemUri = resolver.insert(collection, values) ?: throw IOException("Unable to create download entry")

    try {
      resolver.openOutputStream(itemUri)?.use { out ->
        out.write(bytes)
        out.flush()
      } ?: throw IOException("Unable to open output stream")
    } catch (e: Exception) {
      // Cleanup failed item
      resolver.delete(itemUri, null, null)
      throw e
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val done = ContentValues().apply {
        put(MediaStore.MediaColumns.IS_PENDING, 0)
      }
      resolver.update(itemUri, done, null, null)
    }

    return itemUri
  }
}
