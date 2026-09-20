package com.axl.petal

import android.content.ContentUris
import android.provider.MediaStore
import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.petal/device_media")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scanAudio" -> result.success(scanAudio())
                        "loadArtwork" -> {
                            val uri = call.argument<String>("uri")
                            if (uri == null) result.success(null)
                            else result.success(loadArtwork(uri))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: SecurityException) {
                    result.error("permission_denied", "Audio permission is required to scan this device.", null)
                } catch (error: Exception) {
                    result.error("scan_failed", error.message ?: "Device music scan failed.", null)
                }
            }
    }

    private fun scanAudio(): List<Map<String, Any>> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val output = mutableListOf<Map<String, Any>>()
        contentResolver.query(
            collection,
            projection,
            selection,
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val albumId = cursor.getLong(albumIdColumn)
                output.add(
                    mapOf(
                        "id" to id.toString(),
                        "title" to (cursor.getString(titleColumn) ?: "Untitled Track"),
                        "artist" to (cursor.getString(artistColumn) ?: "Unknown Artist"),
                        "album" to (cursor.getString(albumColumn) ?: ""),
                        "durationMs" to cursor.getLong(durationColumn),
                        "contentUri" to ContentUris.withAppendedId(collection, id).toString(),
                        "artworkUri" to "content://media/external/audio/albumart/$albumId",
                    ),
                )
            }
        }
        return output
    }

    private fun loadArtwork(uri: String): ByteArray? {
        return try {
            contentResolver.openInputStream(Uri.parse(uri))?.use { input ->
                val bytes = input.readBytes()
                if (bytes.size <= 8 * 1024 * 1024) bytes else null
            }
        } catch (_: Exception) {
            null
        }
    }
}
