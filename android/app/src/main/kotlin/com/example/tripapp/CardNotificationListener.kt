package com.example.tripapp

import android.app.Notification
import android.content.Context
import android.content.pm.ApplicationInfo
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * 카드 승인 알림(문자·카카오톡 알림톡·카드사 앱 푸시)만 골라 기기 안의 큐에 쌓는다.
 * 앱 화면이 꺼져 있어도 동작하고, 해석은 Dart(lib/ledger/card_message)가 한다.
 * 알림 본문은 큐에 저장만 하고 로그에 남기지 않는다.
 */
class CardNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        // 디버그 빌드에서는 `adb shell cmd notification post`(com.android.shell)로 시험한다.
        if (sbn.packageName !in PACKAGES && !(debuggable && sbn.packageName == "com.android.shell")) return
        if ((sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        if (!KEYWORDS.containsMatchIn("$title\n$text") || text.none { it.isDigit() }) return
        CardQueue.add(this, title, text, sbn.postTime)
    }

    private companion object {
        val KEYWORDS = Regex("승인|취소|결제")

        // 카드사 앱 패키지명은 실기기에서 확인이 필요하다(가정). 틀리면 여기만 고친다.
        val PACKAGES = setOf(
            "com.kakao.talk", // 카카오톡 알림톡
            "com.samsung.android.messaging", // 삼성 메시지
            "com.google.android.apps.messaging", // Google 메시지
            "com.android.mms",
            "com.android.messaging",
            "com.shcard.smartpay", // 신한 SOL페이
            "kr.co.samsungcard.mpocket", // 삼성카드
            "com.kbcard.cxh.appcard", // KB Pay
            "com.hyundaicard.appcard", // 현대카드
            "com.lcacApp", // 롯데카드
            "com.hanaskcard.paycla", // 하나Pay
            "com.wooricard.smartapp", // 우리카드
            "nh.smart.nhallonepay", // NH pay
            "kvp.jjy.MispAndroid320", // BC 페이북
        )
    }
}

/** 수집한 알림의 기기 내 큐. Dart가 `drain`으로 가져가면 비운다. */
object CardQueue {
    private const val PREFS = "card_notification_queue"
    private const val KEY = "items"
    private const val MAX = 200

    @Synchronized
    fun add(context: Context, title: String, text: String, postedAt: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = JSONArray(prefs.getString(KEY, null) ?: "[]")
        // 같은 알림이 갱신되어 다시 올라오는 경우
        for (i in 0 until items.length()) {
            if (items.getJSONObject(i).optString("text") == text) return
        }
        items.put(JSONObject().put("title", title).put("text", text).put("postedAt", postedAt))
        while (items.length() > MAX) items.remove(0)
        prefs.edit().putString(KEY, items.toString()).apply()
    }

    @Synchronized
    fun drain(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = JSONArray(prefs.getString(KEY, null) ?: "[]")
        prefs.edit().remove(KEY).apply()
        return List(items.length()) { i ->
            val item = items.getJSONObject(i)
            mapOf(
                "title" to item.optString("title"),
                "text" to item.optString("text"),
                "postedAt" to item.optLong("postedAt"),
            )
        }
    }
}
