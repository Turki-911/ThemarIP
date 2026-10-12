package com.example.themarip_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives incoming SMS (also while the app is in the background / not running).
 * Only messages from sender IDs configured by the admin portal are forwarded; everything else is ignored
 * and never leaves the device.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        // Multipart SMS arrive as several PDUs from the same sender — join them.
        val bySender = LinkedHashMap<String, StringBuilder>()
        var ts = System.currentTimeMillis()
        for (m in messages) {
            val sender = m.originatingAddress ?: continue
            bySender.getOrPut(sender) { StringBuilder() }.append(m.messageBody ?: "")
            if (m.timestampMillis > 0) ts = m.timestampMillis
        }
        val supported = bySender.filterKeys { SmsUploader.isSupportedSender(context, it) }
        if (supported.isEmpty()) return

        val pending = goAsync()
        val appCtx = context.applicationContext
        Thread {
            try {
                supported.forEach { (sender, body) -> SmsUploader.submit(appCtx, sender, body.toString(), ts) }
            } catch (e: Exception) {
                android.util.Log.w("ThemarSms", "Receiver failed: ${e.message}")
            } finally {
                pending.finish()
            }
        }.start()
    }
}
