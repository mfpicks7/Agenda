package com.miagenda.local

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import java.io.ByteArrayOutputStream
import android.app.Activity
import android.provider.DocumentsContract

class MainActivity : FlutterActivity() {
    private var documentResult: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private fun selectDocument(result: MethodChannel.Result, bytes: ByteArray? = null) {
        if (documentResult != null) { result.error("BUSY", "Ya hay un documento abierto", null); return }
        documentResult = result
        exportBytes = bytes
        try {
            val intent = Intent(if (bytes == null) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE).setType(if (bytes == null) "*/*" else "application/octet-stream")
            if (bytes != null) intent.putExtra(Intent.EXTRA_TITLE, "MiAgenda-respaldo.sqlite")
            if (Build.VERSION.SDK_INT >= 26) intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                Uri.parse("content://com.android.externalstorage.documents/document/primary%3ADownload"))
            startActivityForResult(intent, 701)
        } catch (_: Exception) {
            documentResult = null; exportBytes = null
            result.error("DOCUMENT", "No se pudo abrir el selector", null)
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 701) return
        val result = documentResult ?: return
        val bytes = exportBytes
        documentResult = null; exportBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        try {
            if (bytes != null) {
                contentResolver.openOutputStream(uri, "wt").use { output ->
                    checkNotNull(output).write(bytes)
                    output.flush()
                }
                result.success(true)
            } else {
                val output = ByteArrayOutputStream()
                contentResolver.openInputStream(uri).use { input ->
                    checkNotNull(input)
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        check(output.size() + count <= 16 * 1024 * 1024)
                        output.write(buffer, 0, count)
                    }
                }
                result.success(output.toByteArray())
            }
        } catch (_: Exception) { result.error("DOCUMENT", "No se pudo leer o guardar el documento (máximo 16 MB)", null) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "miagenda/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "timeZone" -> result.success(TimeZone.getDefault().id)
                "readBackup" -> selectDocument(result)
                "saveBackup" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) result.error("DOCUMENT", "Falta el respaldo", null)
                    else selectDocument(result, bytes)
                }
                "notificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= 26) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
