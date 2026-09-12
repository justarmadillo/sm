package com.incrementalreader.incremental_reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private companion object {
        const val AUTOMATIC_BACKUP_CHANNEL = "incremental_reader/automatic_backup"
        const val CHOOSE_BACKUP_FOLDER_REQUEST = 4107
    }

    private var folderPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTOMATIC_BACKUP_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "chooseFolder" -> chooseBackupFolder(result)
                "saveBackup" -> saveBackup(
                    sourcePath = call.argument<String>("sourcePath"),
                    directoryLocation = call.argument<String>("directoryLocation"),
                    fileName = call.argument<String>("fileName"),
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun chooseBackupFolder(result: MethodChannel.Result) {
        if (folderPickerResult != null) {
            result.error("picker_active", "A folder picker is already open", null)
            return
        }
        folderPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, CHOOSE_BACKUP_FOLDER_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != CHOOSE_BACKUP_FOLDER_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = folderPickerResult
        folderPickerResult = null
        val directoryUri = data?.data
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || directoryUri == null) {
            result.success(null)
            return
        }
        try {
            val grantedFlags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(directoryUri, grantedFlags)
            result.success(
                mapOf(
                    "location" to directoryUri.toString(),
                    "label" to backupFolderLabel(directoryUri),
                ),
            )
        } catch (exception: Exception) {
            result.error("folder_permission_failed", exception.message, null)
        }
    }

    private fun backupFolderLabel(directoryUri: Uri): String {
        val documentId = DocumentsContract.getTreeDocumentId(directoryUri)
        val readable = documentId.substringAfter(':').replace('/', File.separatorChar)
        return readable.ifBlank { documentId }
    }

    private fun saveBackup(
        sourcePath: String?,
        directoryLocation: String?,
        fileName: String?,
        result: MethodChannel.Result,
    ) {
        if (sourcePath.isNullOrBlank() || directoryLocation.isNullOrBlank() || fileName.isNullOrBlank()) {
            result.error("invalid_arguments", "Backup source, folder, and name are required", null)
            return
        }
        thread(name = "automatic-backup-copy") {
            try {
                writeBackupToDocumentTree(
                    sourceFile = File(sourcePath),
                    directoryUri = Uri.parse(directoryLocation),
                    fileName = fileName,
                )
                runOnUiThread { result.success(true) }
            } catch (exception: Exception) {
                runOnUiThread {
                    result.error("backup_write_failed", exception.message, null)
                }
            }
        }
    }

    private fun writeBackupToDocumentTree(
        sourceFile: File,
        directoryUri: Uri,
        fileName: String,
    ) {
        val directoryDocumentUri = DocumentsContract.buildDocumentUriUsingTree(
            directoryUri,
            DocumentsContract.getTreeDocumentId(directoryUri),
        )
        val destinationUri = DocumentsContract.createDocument(
            contentResolver,
            directoryDocumentUri,
            "application/zip",
            fileName,
        ) ?: error("The selected folder refused the backup file")
        FileInputStream(sourceFile).use { input ->
            contentResolver.openOutputStream(destinationUri, "w").use { output ->
                requireNotNull(output) { "The selected folder could not be opened" }
                input.copyTo(output)
                output.flush()
            }
        }
    }
}
