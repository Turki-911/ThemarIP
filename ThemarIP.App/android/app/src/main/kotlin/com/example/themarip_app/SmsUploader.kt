package com.example.themarip_app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Shared by the broadcast receiver (works with no Flutter engine running) and MainActivity.
 *
 * - Config (API base URL + supported sender IDs) is pushed in from Flutter and cached natively.
 * - Includes built-in defaults for the live Railway API URL and Omani bank senders so SMS
 *   logging works continuously forever as long as the user has logged in once.
 */
object SmsUploader {
    private const val PREFS = "themarip_sms"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_SENDERS = "senders"
    private const val KEY_TOKEN = "auth_token"
    private const val KEY_PAUSED = "paused"
    private const val KEY_PENDING = "pending"
    private const val MAX_PENDING = 100

    private const val DEFAULT_BASE_URL = "https://themarip.up.railway.app/api"
    private val DEFAULT_SENDERS = setOf(
        "bank muscat",
        "bankmuscat",
        "bm-alert",
        "bmalert",
        "nbo",
        "national bank of oman",
        "omanarabbank",
        "oab",
        "bankdhofar",
        "bank dhofar",
        "soharint",
        "sohar international",
        "banknizwa",
        "bank nizwa",
        "ahlibank",
        "ahli bank",
        "alizz"
    )

    // shared_preferences (Flutter, legacy API) stores keys as "flutter.<key>"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val FLUTTER_TOKEN_KEY = "flutter.themarip_user_token"

    private val lock = Any()

    private fun normalizeSender(s: String): String =
        s.trim().lowercase().replace(Regex("[\\s\\-_.]"), "")

    fun configure(ctx: Context, baseUrl: String, senders: List<String>, token: String? = null, paused: Boolean? = null) {
        val mergedSenders = (senders.map { it.trim().lowercase() }.filter { it.isNotEmpty() } + DEFAULT_SENDERS).toSet()
        val editor = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_BASE_URL, baseUrl.trimEnd('/').ifEmpty { DEFAULT_BASE_URL })
            .putStringSet(KEY_SENDERS, mergedSenders)
        if (!token.isNullOrBlank()) {
            editor.putString(KEY_TOKEN, token)
        }
        if (paused != null) {
            editor.putBoolean(KEY_PAUSED, paused)
        }
        editor.apply()
    }

    fun setPaused(ctx: Context, paused: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_PAUSED, paused)
            .apply()
    }

    fun isPaused(ctx: Context): Boolean =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_PAUSED, false)

    fun clear(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun isSupportedSender(ctx: Context, sender: String?): Boolean {
        if (sender.isNullOrBlank()) return false
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_PAUSED, false)) return false

        val stored = prefs.getStringSet(KEY_SENDERS, null)
        val activeSet = if (stored.isNullOrEmpty()) DEFAULT_SENDERS else (stored + DEFAULT_SENDERS)

        val rawLower = sender.trim().lowercase()
        val norm = normalizeSender(sender)
        return activeSet.any { candidate ->
            val candLower = candidate.trim().lowercase()
            val candNorm = normalizeSender(candidate)
            rawLower == candLower ||
                norm == candNorm ||
                (candNorm.length >= 3 && norm.contains(candNorm))
        }
    }

    private fun token(ctx: Context): String? {
        // Prefer the latest Flutter login token first, then fallback to cached dedicated token
        val flutterTok = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(FLUTTER_TOKEN_KEY, null)
        if (!flutterTok.isNullOrBlank()) {
            // Keep dedicated store synced automatically
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_TOKEN, flutterTok)
                .apply()
            return flutterTok
        }
        val dedicated = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_TOKEN, null)
        if (!dedicated.isNullOrBlank()) return dedicated
        return null
    }

    private fun baseUrl(ctx: Context): String {
        val saved = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_BASE_URL, null)
        return if (saved.isNullOrBlank()) DEFAULT_BASE_URL else saved.trimEnd('/')
    }

    private enum class Outcome { DELIVERED, RETRY, DROP }

    /** Sends one SMS; queues it for retry if the server/network is unavailable. Call off the main thread. */
    fun submit(ctx: Context, sender: String, body: String, receivedAtMs: Long) {
        val item = JSONObject()
            .put("sender", sender).put("message", body).put("receivedAtMs", receivedAtMs)
        if (post(ctx, item) == Outcome.RETRY) enqueue(ctx, item)
        else flush(ctx) // network is evidently working — drain anything queued earlier
    }

    /** Retries queued messages. Call off the main thread. */
    fun flush(ctx: Context) {
        synchronized(lock) {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val pending = try { JSONArray(prefs.getString(KEY_PENDING, "[]")) } catch (_: Exception) { JSONArray() }
            if (pending.length() == 0) return
            val remaining = JSONArray()
            var stop = false
            for (i in 0 until pending.length()) {
                val item = pending.getJSONObject(i)
                if (stop) { remaining.put(item); continue }
                if (post(ctx, item) == Outcome.RETRY) { remaining.put(item); stop = true }
            }
            prefs.edit().putString(KEY_PENDING, remaining.toString()).apply()
        }
    }

    private fun enqueue(ctx: Context, item: JSONObject) {
        synchronized(lock) {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val pending = try { JSONArray(prefs.getString(KEY_PENDING, "[]")) } catch (_: Exception) { JSONArray() }
            pending.put(item)
            val trimmed = JSONArray()
            val start = maxOf(0, pending.length() - MAX_PENDING)
            for (i in start until pending.length()) trimmed.put(pending.get(i))
            prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
        }
    }

    private fun post(ctx: Context, item: JSONObject): Outcome {
        val base = baseUrl(ctx)
        val token = token(ctx) ?: return Outcome.RETRY // not signed in yet; keep until they are
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL("$base/sms/ingest").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 6000
                readTimeout = 8000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            conn.outputStream.use { it.write(item.toString().toByteArray(Charsets.UTF_8)) }
            when (val code = conn.responseCode) {
                in 200..299 -> Outcome.DELIVERED
                401, 408, 429, in 500..599 -> Outcome.RETRY
                else -> { android.util.Log.w("ThemarSms", "Dropped SMS, HTTP $code"); Outcome.DROP }
            }
        } catch (e: Exception) {
            android.util.Log.w("ThemarSms", "Send failed: ${e.message}")
            Outcome.RETRY
        } finally {
            conn?.disconnect()
        }
    }
}
