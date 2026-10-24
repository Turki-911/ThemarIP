package com.example.themarip_app

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "themarip/sms"
    private val requestCode = 7421
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    private fun hasPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> {
                if (hasPermission()) { result.success(true); return }
                if (pendingPermissionResult != null) { result.error("busy", "Request in progress", null); return }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECEIVE_SMS), requestCode)
            }
            "configure" -> {
                val base = call.argument<String>("baseUrl")
                val senders = call.argument<List<String>>("senders") ?: emptyList()
                val token = call.argument<String>("token")
                val paused = call.argument<Boolean>("paused")
                if (base.isNullOrBlank()) { result.error("bad_args", "baseUrl required", null); return }
                SmsUploader.configure(applicationContext, base, senders, token, paused)
                // Drain anything queued while offline / signed out.
                Thread { SmsUploader.flush(applicationContext) }.start()
                result.success(null)
            }
            "setPaused" -> {
                val paused = call.argument<Boolean>("paused") ?: false
                SmsUploader.setPaused(applicationContext, paused)
                if (!paused) {
                    Thread { SmsUploader.flush(applicationContext) }.start()
                }
                result.success(null)
            }
            "isPaused" -> result.success(SmsUploader.isPaused(applicationContext))
            "clear" -> { SmsUploader.clear(applicationContext); result.success(null) }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(code, permissions, grantResults)
        if (code == requestCode) {
            pendingPermissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermissionResult = null
        }
    }
}
