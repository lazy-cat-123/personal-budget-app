package com.example.app

import android.Manifest
import android.app.RecoverableSecurityException
import android.content.ContentValues
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "personal_budget_app/downloads"
    private val readStorageRequestCode = 4101
    private val pickBackupRequestCode = 4102
    private val deleteBackupsRequestCode = 4103
    private var pendingReadBackupResult: MethodChannel.Result? = null
    private var pendingPickBackupResult: MethodChannel.Result? = null
    private var pendingDeleteBackupsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveCsvFiles" -> saveCsvFiles(call.arguments, result)
                "saveDatabaseBackup" -> saveDatabaseBackup(call.arguments, result)
                "readDatabaseBackup" -> readDatabaseBackup(result)
                "pickDatabaseBackup" -> pickDatabaseBackup(result)
                "cleanDatabaseBackups" -> cleanDatabaseBackups(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == readStorageRequestCode) {
            val result = pendingReadBackupResult ?: return
            pendingReadBackupResult = null
            completeReadDatabaseBackup(result)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickBackupRequestCode) {
            val result = pendingPickBackupResult ?: return
            pendingPickBackupResult = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                result.success(null)
                return
            }

            try {
                result.success(readBytesFromUri(uri))
            } catch (error: Exception) {
                result.error("restore_failed", error.message, null)
            }
        } else if (requestCode == deleteBackupsRequestCode) {
            val result = pendingDeleteBackupsResult ?: return
            pendingDeleteBackupsResult = null
            cleanupBackupsSilently()
            result.success(resultCode == RESULT_OK)
        }
    }

    private fun saveCsvFiles(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val directoryName = args?.get("directoryName") as? String
        val files = args?.get("files") as? List<*>

        if (directoryName.isNullOrBlank() || files == null) {
            result.error("invalid_args", "directoryName and files are required", null)
            return
        }

        try {
            val savedPaths = mutableListOf<String>()
            for (file in files) {
                val fileMap = file as? Map<*, *> ?: continue
                val fileName = fileMap["fileName"] as? String ?: continue
                val content = fileMap["content"] as? String ?: ""
                val savedPath = writeCsvToDownloads(directoryName, fileName, content)
                savedPaths.add(savedPath)
            }
            result.success(savedPaths)
        } catch (error: Exception) {
            result.error("save_failed", error.message, null)
        }
    }

    private fun writeCsvToDownloads(directoryName: String, fileName: String, content: String): String {
        val resolver = applicationContext.contentResolver
        val relativePath = Environment.DIRECTORY_DOWNLOADS + "/PersonalBudgetExports/" + directoryName
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create download file")

        resolver.openOutputStream(uri)?.use { stream ->
            stream.write(content.toByteArray(Charsets.UTF_8))
        } ?: throw IllegalStateException("Could not open download file")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val completedValues = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            resolver.update(uri, completedValues, null, null)
        }

        return "Downloads/PersonalBudgetExports/$directoryName/$fileName"
    }

    private fun saveDatabaseBackup(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val bytes = args?.get("bytes") as? ByteArray
        if (bytes == null) {
            result.error("invalid_args", "bytes are required", null)
            return
        }

        try {
            val path = writeBackupToDownloads(bytes)
            result.success(path)
        } catch (error: Exception) {
            result.error("backup_failed", error.message, null)
        }
    }

    private fun readDatabaseBackup(result: MethodChannel.Result) {
        if (needsStorageReadPermission()) {
            if (pendingReadBackupResult != null) {
                result.error("restore_busy", "A backup restore is already waiting for permission", null)
                return
            }
            pendingReadBackupResult = result
            requestPermissions(
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                readStorageRequestCode,
            )
            return
        }
        completeReadDatabaseBackup(result)
    }

    private fun completeReadDatabaseBackup(result: MethodChannel.Result) {
        try {
            result.success(readBackupFromDownloads())
        } catch (error: Exception) {
            result.error("restore_failed", error.message, null)
        }
    }

    private fun pickDatabaseBackup(result: MethodChannel.Result) {
        if (pendingPickBackupResult != null) {
            result.error("restore_busy", "A backup restore picker is already open", null)
            return
        }

        pendingPickBackupResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/vnd.sqlite3",
                    "application/x-sqlite3",
                    "application/octet-stream",
                    "application/x-sqlite",
                ),
            )
        }

        try {
            startActivityForResult(intent, pickBackupRequestCode)
        } catch (error: Exception) {
            pendingPickBackupResult = null
            result.error("restore_failed", error.message, null)
        }
    }

    private fun writeBackupToDownloads(bytes: ByteArray): String {
        val fileName = "personal_budget.sqlite"
        val directFile = backupDirectFile(fileName)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val relativePath = Environment.DIRECTORY_DOWNLOADS + "/PersonalBudgetBackups/"

            val tempUri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, "personal_budget_tmp.sqlite")
                    put(MediaStore.Downloads.MIME_TYPE, "application/vnd.sqlite3")
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                },
            ) ?: throw IllegalStateException("Could not create temporary database backup")

            if (!writeBytesToUri(tempUri, bytes)) {
                resolver.delete(tempUri, null, null)
                throw IllegalStateException("Could not open database backup")
            }

            deleteDirectBackupFiles()
            deleteDownloadBackupFiles()
            if (backupDirectFiles().isNotEmpty() || findDownloadUris("personal_budget").isNotEmpty()) {
                resolver.delete(tempUri, null, null)
                throw IllegalStateException("Android blocked deleting old backup files. Clean old backup files first.")
            }

            resolver.update(
                tempUri,
                ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.IS_PENDING, 0)
                },
                null,
                null,
            )
            return "Downloads/PersonalBudgetBackups/$fileName"
        }

        deleteDirectBackupFiles()
        directFile.parentFile?.mkdirs()
        directFile.writeBytes(bytes)
        return directFile.absolutePath
    }

    private fun writeBytesToUri(uri: Uri, bytes: ByteArray): Boolean {
        return try {
            applicationContext.contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                stream.write(bytes)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readBackupFromDownloads(): ByteArray? {
        val directFiles = backupDirectFiles()
        for (file in directFiles) {
            if (file.exists() && file.length() > 0) {
                try {
                    return file.readBytes()
                } catch (_: Exception) {
                    // Try the next matching backup.
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val uris = findDownloadUris("personal_budget")
            for (uri in uris) {
                try {
                    val bytes = applicationContext.contentResolver.openInputStream(uri)?.use { stream ->
                        stream.readBytes()
                    }
                    if (bytes != null && bytes.isNotEmpty()) return bytes
                } catch (_: Exception) {
                    // Try the next matching MediaStore item.
                }
            }
            return null
        }

        return null
    }

    private fun readBytesFromUri(uri: Uri): ByteArray? {
        return applicationContext.contentResolver.openInputStream(uri)?.use { stream ->
            stream.readBytes()
        }
    }

    private fun needsStorageReadPermission(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            Build.VERSION.SDK_INT <= 32 &&
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
    }

    private fun backupDirectFile(fileName: String): java.io.File {
        return java.io.File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "PersonalBudgetBackups/$fileName",
        )
    }

    private fun backupDirectFiles(): List<java.io.File> {
        val directory = java.io.File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "PersonalBudgetBackups",
        )
        return directory
            .listFiles { file ->
                file.isFile && isBackupFileName(file.name)
            }
            ?.sortedWith(
                compareByDescending<java.io.File> { file -> file.length() }
                    .thenByDescending { file -> file.lastModified() },
            )
            ?: emptyList()
    }

    private fun isBackupFileName(fileName: String): Boolean {
        return Regex("""personal_budget( ?\(\d+\))?\.sqlite""").matches(fileName)
    }

    private fun deleteDirectBackupFiles() {
        for (file in backupDirectFiles()) {
            try {
                file.delete()
            } catch (_: Exception) {
                // If Android blocks deleting one file, still try the remaining files.
            }
        }
    }

    private fun deleteDownloadBackupFiles() {
        for (uri in findDownloadUris("personal_budget")) {
            try {
                applicationContext.contentResolver.delete(uri, null, null)
            } catch (_: Exception) {
                // Some Android versions block deleting files from an older app install.
            }
        }
    }

    private fun cleanDatabaseBackups(result: MethodChannel.Result) {
        try {
            if (cleanupBackupsSilently()) {
                result.success(true)
                return
            }

            val backupUris = findDownloadUris("personal_budget")
            if (backupUris.size <= 1 && backupDirectFiles().size <= 1) {
                result.success(true)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (pendingDeleteBackupsResult != null) {
                    result.error("cleanup_busy", "Backup cleanup is already waiting for confirmation", null)
                    return
                }
                pendingDeleteBackupsResult = result
                val request = MediaStore.createDeleteRequest(
                    applicationContext.contentResolver,
                    backupUris,
                )
                startIntentSenderForResult(
                    request.intentSender,
                    deleteBackupsRequestCode,
                    null,
                    0,
                    0,
                    0,
                )
                return
            }

            result.success(false)
        } catch (error: RecoverableSecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                pendingDeleteBackupsResult = result
                startIntentSenderForResult(
                    error.userAction.actionIntent.intentSender,
                    deleteBackupsRequestCode,
                    null,
                    0,
                    0,
                    0,
                )
            } else {
                result.error("cleanup_failed", error.message, null)
            }
        } catch (error: Exception) {
            result.error("cleanup_failed", error.message, null)
        }
    }

    private fun cleanupBackupsSilently(): Boolean {
        val directCleaned = deleteDuplicateDirectBackupFiles()
        val duplicateUris = duplicateDownloadBackupUris()
        var allDeleted = true
        for (uri in duplicateUris) {
            try {
                if (applicationContext.contentResolver.delete(uri, null, null) == 0) {
                    allDeleted = false
                }
            } catch (_: Exception) {
                allDeleted = false
            }
        }
        return directCleaned &&
            allDeleted &&
            backupDirectFiles().size <= 1 &&
            findDownloadUris("personal_budget").size <= 1
    }

    private fun duplicateDownloadBackupUris(): List<Uri> {
        val uris = findDownloadUris("personal_budget")
        if (uris.size <= 1) return emptyList()
        return uris.drop(1)
    }

    private fun deleteDuplicateDirectBackupFiles(): Boolean {
        var allDeleted = true
        for (file in backupDirectFiles().drop(1)) {
            try {
                if (!file.delete()) allDeleted = false
            } catch (_: Exception) {
                // If Android blocks deleting one file, still try the remaining files.
                allDeleted = false
            }
        }
        return allDeleted
    }

    private fun deleteDuplicateDownloadBackups(keepUri: Uri) {
        for (uri in findDownloadUris("personal_budget")) {
            if (uri == keepUri) continue
            try {
                applicationContext.contentResolver.delete(uri, null, null)
            } catch (_: Exception) {
                // Keep the canonical backup even if an old duplicate cannot be removed.
            }
        }
    }

    private fun findDownloadUris(fileNamePrefix: String): List<Uri> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()
        val projection = arrayOf(
            MediaStore.Downloads._ID,
            MediaStore.Downloads.DISPLAY_NAME,
            MediaStore.Downloads.RELATIVE_PATH,
            MediaStore.Downloads.DATE_MODIFIED,
            MediaStore.MediaColumns.SIZE,
        )
        val selection = "${MediaStore.Downloads.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("$fileNamePrefix%.sqlite")
        val order = "${MediaStore.MediaColumns.SIZE} DESC, ${MediaStore.Downloads.DATE_MODIFIED} DESC"
        val cursor: Cursor? = applicationContext.contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            order,
        )
        val uris = mutableListOf<Uri>()
        cursor.use {
            while (it != null && it.moveToNext()) {
                val displayName = it.getString(
                    it.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME),
                ) ?: ""
                if (!isBackupFileName(displayName)) continue
                val relativePath = it.getString(
                    it.getColumnIndexOrThrow(MediaStore.Downloads.RELATIVE_PATH),
                ) ?: ""
                if (!relativePath.contains("PersonalBudgetBackups")) continue
                val id = it.getLong(it.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                uris.add(ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id))
            }
        }
        return uris
    }
}
