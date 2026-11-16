package com.example.tripapp

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 카드 알림 자동 입력 (lib/ledger/card_message/card_inbox.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tripapp/card_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(isListenerEnabled())
                    "openSettings" -> try {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    } catch (e: ActivityNotFoundException) {
                        result.error("unavailable", "알림 접근 설정을 열 수 없어요", null)
                    }
                    "drain" -> result.success(CardQueue.drain(this))
                    else -> result.notImplemented()
                }
            }
    }

    private fun isListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        val mine = ComponentName(this, CardNotificationListener::class.java)
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == mine }
    }
}
