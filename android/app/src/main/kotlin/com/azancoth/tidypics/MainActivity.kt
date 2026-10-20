package com.azancoth.tidypics

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Le peu de code natif de TidyPics : ce que photo_manager ne fait pas.
 *
 * - `sdkInt` : version d'Android (« Gestion des médias » demande Android 12).
 * - `trashedIds` : parmi des photos envoyées à la corbeille, celles qui y sont
 *   encore (l'utilisateur a pu les restaurer ou vider la corbeille ailleurs).
 * - `deleteForever` : vide la corbeille pour ces photos (« Vider maintenant »).
 * - `storage` : capacité du téléphone, espace libre, place des photos et des
 *   vidéos.
  * - `sizes` : taille de chaque photo et vidéo, en une requête.
 * - `openInGallery` : ouvre une photo dans l'app Galerie (ou Google Photos).
 *
 * Photos et vidéos passent par la table `Files` de MediaStore, qui couvre
 * les deux.
 */
class MainActivity : FlutterActivity() {
    private var pendingDelete: Pair<MethodChannel.Result, List<String>>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tidypics/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "trashedIds" -> result.success(trashedIds(call.argument<List<String>>("ids").orEmpty()))
                    "deleteForever" -> deleteForever(call.argument<List<String>>("ids").orEmpty(), result)
                    "storage" -> result.success(storage())
                                        "sizes" -> result.success(sizes())
                    "openInGallery" -> result.success(openInGallery(call.argument<String>("id")))
                    else -> result.notImplemented()
                }
            }
    }

    private val files = MediaStore.Files.getContentUri("external")

    private val mediaSelection =
        "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}," +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})"

    private fun storage(): Map<String, Long> {
        val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
        var photos = 0L
        var videos = 0L
        contentResolver.query(
            files,
            arrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE, MediaStore.MediaColumns.SIZE),
            mediaSelection,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getInt(0) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) {
                    videos += cursor.getLong(1)
                } else {
                    photos += cursor.getLong(1)
                }
            }
        }
        return mapOf(
            "total" to stat.totalBytes,
            "free" to stat.availableBytes,
            "photos" to photos,
            "videos" to videos,
        )
    }

        private fun openInGallery(id: String?): Boolean {
        val uri = mediaUris(listOfNotNull(id)).firstOrNull() ?: return false
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, contentResolver.getType(uri))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: android.content.ActivityNotFoundException) {
            false
        }
    }

    private fun sizes(): Map<String, Long> {
        val sizes = HashMap<String, Long>()
        contentResolver.query(
            files,
            arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.SIZE),
            mediaSelection,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) sizes[cursor.getLong(0).toString()] = cursor.getLong(1)
        }
        return sizes
    }

    /** Adresse MediaStore de chaque élément (photo ou vidéo), corbeille comprise. */
    private fun mediaUris(ids: List<String>): List<android.net.Uri> {
        val uris = mutableListOf<android.net.Uri>()
        for (chunk in ids.chunked(500)) {
            val args = Bundle().apply {
                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
                putString(
                    android.content.ContentResolver.QUERY_ARG_SQL_SELECTION,
                    "${MediaStore.MediaColumns._ID} IN (${chunk.joinToString(",") { "?" }})",
                )
                putStringArray(
                    android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS,
                    chunk.toTypedArray(),
                )
            }
            contentResolver.query(
                files,
                arrayOf(MediaStore.MediaColumns._ID, MediaStore.Files.FileColumns.MEDIA_TYPE),
                args,
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val base = if (cursor.getInt(1) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) {
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    } else {
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    }
                    uris.add(ContentUris.withAppendedId(base, cursor.getLong(0)))
                }
            }
        }
        return uris
    }

    private fun trashedIds(ids: List<String>): List<String> {
        if (ids.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        val found = mutableListOf<String>()
        // Par paquets : une requête SQL accepte un nombre limité de paramètres.
        for (chunk in ids.chunked(500)) {
            val args = Bundle().apply {
                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_ONLY)
                putString(
                    android.content.ContentResolver.QUERY_ARG_SQL_SELECTION,
                    "${MediaStore.MediaColumns._ID} IN (${chunk.joinToString(",") { "?" }})",
                )
                putStringArray(
                    android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS,
                    chunk.toTypedArray(),
                )
            }
            contentResolver.query(
                files,
                arrayOf(MediaStore.MediaColumns._ID),
                args,
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) found.add(cursor.getLong(0).toString())
            }
        }
        return found
    }

    private fun deleteForever(ids: List<String>, result: MethodChannel.Result) {
        if (ids.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.success(emptyList<String>())
            return
        }
        if (pendingDelete != null) {
            result.error("busy", "Une suppression est déjà en cours", null)
            return
        }
        val uris = mediaUris(ids)
        if (uris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }
        // Une seule popup pour tout le lot ; aucune avec « Gestion des médias ».
        val request = MediaStore.createDeleteRequest(contentResolver, uris)
        pendingDelete = result to ids
        startIntentSenderForResult(request.intentSender, DELETE_REQUEST, null, 0, 0, 0)
    }

    @Deprecated("Toujours le moyen de recevoir la réponse d'une demande MediaStore")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DELETE_REQUEST) return
        val (result, ids) = pendingDelete ?: return
        pendingDelete = null
        result.success(if (resultCode == Activity.RESULT_OK) ids else emptyList())
    }

    private companion object {
        const val DELETE_REQUEST = 7341
    }
}
