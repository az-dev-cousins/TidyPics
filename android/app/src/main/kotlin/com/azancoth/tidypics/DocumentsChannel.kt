package com.azancoth.tidypics

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Documents (V2, F16), sans la permission « Accès à tous les fichiers » :
 * tout passe par le sélecteur de fichiers du système (Storage Access
 * Framework), donc accepté par le Play Store.
 *
 * - `pickFiles` : le sélecteur, plusieurs fichiers à la fois (« Trier des
 *   fichiers »).
 * - `pickFolder` / `folders` / `forgetFolder` / `listFolder` : un dossier
 *   donné une fois (« Trier mes documents », le dossier Documents d'abord).
 * - `pdfPreview` : la première page d'un PDF, en image.
 * - `readBytes` : le début d'un fichier (aperçu du texte d'un Word, côté Dart).
 * - `open` : ouvre le fichier dans l'app qui sait le lire.
 * - `moveToAppTrash` / `restore` : la corbeille de TidyPics. La corbeille du
 *   système n'accepte que les photos, vidéos et sons (« All requested items
 *   must be Media items ») : le document est copié dans le stockage de
 *   l'app, puis effacé de son dossier. Il peut y revenir pendant 30 jours.
 */
class DocumentsChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pendingPick: MethodChannel.Result? = null
    private var pendingFolder: MethodChannel.Result? = null

    private val resolver get() = activity.contentResolver

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFiles" -> pickFiles(result)
            "pickFolder" -> pickFolder(result)
            "folders" -> result.success(folders())
            "forgetFolder" -> {
                forgetFolder(call.argument<String>("uri"))
                result.success(null)
            }
            "listFolder" -> runInBackground(result) { listFolder(call.argument<String>("uri")!!) }
            "pdfPreview" -> runInBackground(result) {
                pdfPreview(call.argument<String>("uri")!!, call.argument<Int>("width") ?: 600)
            }
            "readBytes" -> runInBackground(result) {
                readBytes(call.argument<String>("uri")!!, call.argument<Int>("max") ?: (8 shl 20))
            }
            "open" -> result.success(open(call.argument<String>("uri")!!, call.argument<String>("mime")))
            "moveToAppTrash" -> runInBackground(result) {
                moveToAppTrash(call.argument<List<String>>("uris").orEmpty())
            }
            "restore" -> runInBackground(result) {
                restore(
                    call.argument<String>("path")!!,
                    call.argument<String>("name")!!,
                    call.argument<String>("mime"),
                    call.argument<String>("tree"),
                    call.argument<String>("folder"),
                )
            }
            else -> result.notImplemented()
        }
    }

    /** Lecture du stockage hors du fil principal, réponse sur le fil principal. */
    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                activity.runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("documents", e.message, null) }
            }
        }.start()
    }

    private fun pickFiles(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "Sélection déjà en cours", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        activity.startActivityForResult(intent, PICK_FILES)
    }

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingFolder != null) {
            result.error("busy", "Sélection déjà en cours", null)
            return
        }
        pendingFolder = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            // Le dossier Documents d'abord : c'est là que finissent les PDF.
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(EXTERNAL_STORAGE, "primary:Documents"),
            )
        }
        activity.startActivityForResult(intent, PICK_FOLDER)
    }

    private val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    /** À appeler depuis `onActivityResult`. Vrai si la réponse était pour nous. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            PICK_FILES -> {
                val result = pendingPick ?: return true
                pendingPick = null
                if (resultCode != Activity.RESULT_OK || data == null) {
                    result.success(emptyList<Map<String, Any?>>())
                    return true
                }
                val uris = buildList {
                    data.clipData?.let { clip -> for (i in 0 until clip.itemCount) add(clip.getItemAt(i).uri) }
                    data.data?.let { if (isEmpty()) add(it) }
                }
                // Garder l'accès : le fichier peut rester au panier jusqu'au
                // lendemain.
                for (uri in uris) {
                    try {
                        resolver.takePersistableUriPermission(uri, flags)
                    } catch (_: SecurityException) {
                        // Certains fournisseurs ne le permettent pas.
                    }
                }
                runInBackground(result) { uris.mapNotNull { describe(it, null) } }
            }
            PICK_FOLDER -> {
                val result = pendingFolder ?: return true
                pendingFolder = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(null)
                    return true
                }
                resolver.takePersistableUriPermission(uri, flags)
                result.success(folderInfo(uri))
            }
            else -> return false
        }
        return true
    }

    private fun folders(): List<Map<String, Any?>> =
        resolver.persistedUriPermissions
            .filter { it.isReadPermission && DocumentsContract.isTreeUri(it.uri) }
            .map { folderInfo(it.uri) }

    private fun folderInfo(tree: Uri): Map<String, Any?> {
        val id = DocumentsContract.getTreeDocumentId(tree)
        return mapOf("uri" to tree.toString(), "name" to id.substringAfterLast(':').substringAfterLast('/'))
    }

    private fun forgetFolder(uri: String?) {
        if (uri == null) return
        try {
            resolver.releasePersistableUriPermission(Uri.parse(uri), flags)
        } catch (_: SecurityException) {
        }
    }

    /** Tous les fichiers du dossier et de ses sous-dossiers. */
    private fun listFolder(treeString: String): List<Map<String, Any?>> {
        val tree = Uri.parse(treeString)
        val files = mutableListOf<Map<String, Any?>>()
        val pending = ArrayDeque(listOf(DocumentsContract.getTreeDocumentId(tree) to ""))
        while (pending.isNotEmpty()) {
            val (parentId, path) = pending.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
            resolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null,
                null,
                null,
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0)
                    val name = c.getString(1) ?: continue
                    val mime = c.getString(2)
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        // Dossiers cachés (.thumbnails…) : rien à trier.
                        if (!name.startsWith(".")) pending.add(id to "$path$name/")
                        continue
                    }
                    files.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                            "name" to name,
                            "mime" to mime,
                            "size" to (if (c.isNull(3)) 0L else c.getLong(3)),
                            "modified" to (if (c.isNull(4)) 0L else c.getLong(4)),
                            "folder" to path,
                        ),
                    )
                }
            }
        }
        return files
    }

    private fun describe(uri: Uri, folder: String?): Map<String, Any?>? {
        resolver.query(uri, null, null, null, null)?.use { c ->
            if (!c.moveToFirst()) return null
            fun col(name: String) = c.getColumnIndex(name).takeIf { it >= 0 }
            val name = col(OpenableColumns.DISPLAY_NAME)?.let { c.getString(it) } ?: uri.lastPathSegment
            val size = col(OpenableColumns.SIZE)?.let { if (c.isNull(it)) 0L else c.getLong(it) } ?: 0L
            val modified = col(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                ?.let { if (c.isNull(it)) 0L else c.getLong(it) } ?: 0L
            return mapOf(
                "uri" to uri.toString(),
                "name" to name,
                "mime" to resolver.getType(uri),
                "size" to size,
                "modified" to modified,
                "folder" to folder,
            )
        }
        return null
    }

    /** Première page d'un PDF en PNG, et le nombre de pages. */
    private fun pdfPreview(uriString: String, width: Int): Map<String, Any?>? {
        val fd = resolver.openFileDescriptor(Uri.parse(uriString), "r") ?: return null
        fd.use {
            PdfRenderer(it).use { renderer ->
                if (renderer.pageCount == 0) return null
                renderer.openPage(0).use { page ->
                    val height = (width.toFloat() * page.height / page.width).toInt().coerceAtLeast(1)
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    val out = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    bitmap.recycle()
                    return mapOf("png" to out.toByteArray(), "pages" to renderer.pageCount)
                }
            }
        }
    }

    private fun readBytes(uriString: String, max: Int): ByteArray? {
        resolver.openInputStream(Uri.parse(uriString))?.use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            while (out.size() < max) {
                val n = input.read(buffer)
                if (n < 0) break
                out.write(buffer, 0, n)
            }
            return out.toByteArray()
        }
        return null
    }

    private fun open(uriString: String, mime: String?): Boolean {
        val uri = Uri.parse(uriString)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime ?: resolver.getType(uri))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: android.content.ActivityNotFoundException) {
            false
        }
    }

    private val trashDir get() = java.io.File(activity.filesDir, "doc_trash").apply { mkdirs() }

    /**
     * Copie chaque document dans la corbeille de l'app puis l'efface de son
     * dossier. Renvoie, pour ceux qui ont réussi, l'adresse d'origine et le
     * fichier mis de côté.
     */
    private fun moveToAppTrash(uris: List<String>): List<Map<String, String>> {
        val moved = mutableListOf<Map<String, String>>()
        for (s in uris) {
            val uri = Uri.parse(s)
            val copy = java.io.File(trashDir, java.util.UUID.randomUUID().toString())
            try {
                resolver.openInputStream(uri)?.use { input ->
                    copy.outputStream().use { input.copyTo(it) }
                } ?: continue
                if (DocumentsContract.deleteDocument(resolver, uri)) {
                    moved.add(mapOf("uri" to s, "path" to copy.absolutePath))
                } else {
                    copy.delete()
                }
            } catch (e: Exception) {
                copy.delete()
            }
        }
        return moved
    }

    /**
     * Remet un document de la corbeille de l'app : dans son dossier
     * d'origine si on le connaît (dossier donné), sinon dans Téléchargements.
     * Renvoie la nouvelle adresse, ou `null`.
     */
    private fun restore(path: String, name: String, mime: String?, tree: String?, folder: String?): String? {
        val file = java.io.File(path)
        if (!file.exists()) return null
        val type = mime ?: "application/octet-stream"
        val target: Uri? = if (tree != null) {
            val treeUri = Uri.parse(tree)
            var parent = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri),
            )
            // Recrée les sous-dossiers s'il le faut.
            for (part in folder.orEmpty().split('/').filter { it.isNotEmpty() }) {
                parent = childFolder(treeUri, parent, part) ?: break
            }
            DocumentsContract.createDocument(resolver, parent, type, name)
        } else {
            val values = android.content.ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, type)
            }
            resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        }
        if (target == null) return null
        resolver.openOutputStream(target)?.use { out -> file.inputStream().use { it.copyTo(out) } }
            ?: return null
        file.delete()
        return target.toString()
    }

    private fun childFolder(tree: Uri, parent: Uri, name: String): Uri? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getDocumentId(parent),
        )
        resolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name && c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
                }
            }
        }
        return DocumentsContract.createDocument(resolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, name)
    }

    companion object {
        const val PICK_FILES = 7342
        const val PICK_FOLDER = 7343
        private const val EXTERNAL_STORAGE = "com.android.externalstorage.documents"
    }
}
