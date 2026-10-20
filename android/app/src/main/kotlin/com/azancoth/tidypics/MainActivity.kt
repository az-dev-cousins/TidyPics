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
 * - `storage` : capacité du téléphone, espace libre et place des photos.
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
                    else -> result.notImplemented()
                }
            }
    }

    private fun storage(): Map<String, Long> {
        val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
        var photos = 0L
        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) photos += cursor.getLong(0)
        }
        return mapOf(
            "total" to stat.totalBytes,
            "free" to stat.availableBytes,
            "photos" to photos,
        )
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
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
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
        val uris = ids.mapNotNull { it.toLongOrNull() }
            .map { ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, it) }
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
