package com.example.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "personal_budget_app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveCsvFiles" -> saveCsvFiles(call.arguments, result)
                else -> result.notImplemented()
            }
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
}
