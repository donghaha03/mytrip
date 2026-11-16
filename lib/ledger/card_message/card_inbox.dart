import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/country.dart';
import '../models/trip.dart';
import 'card_drafts.dart';
import 'card_message_parser.dart';

/// Android 알림 수집 큐(네이티브)와 확인 대기 목록을 잇는다. Android 전용.
///
/// 네이티브 큐는 `drain`하면 비워지므로, 읽어낸 결과(가맹점·금액·일시만)를
/// 기기 저장소에 보관했다가 사용자가 저장하거나 무시하면 지운다.
class CardInbox extends ChangeNotifier {
  static const _channel = MethodChannel('tripapp/card_notifications');
  static const _pendingKey = 'card_pending';
  static const _introKey = 'card_intro_dismissed';

  /// Android이고 네이티브 채널이 응답함.
  bool supported = false;

  /// 시스템 설정에서 알림 접근이 허용됨.
  bool enabled = false;
  bool introDismissed = false;

  /// 카드사 알림인데 형식을 읽지 못한 건수(이번 실행 동안만 센다).
  int unreadable = 0;
  List<ParsedCardPayment> pending = const [];

  bool _busy = false, _disposed = false;

  /// 네이티브 큐를 비우고 대기 목록을 다시 만든다. [saved]는 지금 열린 여행의 지출.
  Future<void> refresh(Iterable<Expense> saved) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _busy) {
      return;
    }
    _busy = true;
    try {
      enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      final drained =
          await _channel.invokeMethod<List<Object?>>('drain') ?? const [];
      final prefs = await SharedPreferences.getInstance();
      introDismissed = prefs.getBool(_introKey) ?? false;
      final fresh = <ParsedCardPayment>[];
      for (final item in drained) {
        if (item is! Map) continue;
        final text = '${item['text'] ?? ''}', title = '${item['title'] ?? ''}';
        final postedAt = item['postedAt'];
        final parsed = parseCardMessage(
          text,
          title: title,
          now: postedAt is int
              ? DateTime.fromMillisecondsSinceEpoch(postedAt)
              : null,
        );
        if (parsed != null && countryByCode(parsed.currency) != null) {
          fresh.add(parsed);
        } else if (cardIssuerOf('$title\n$text') != null) {
          unreadable++;
        }
      }
      pending = dedupeCardPayments([..._stored(prefs), ...fresh], saved);
      await _persist(prefs);
      supported = true;
    } on MissingPluginException {
      supported = false;
    } on PlatformException {
      supported = false;
    } finally {
      _busy = false;
    }
    if (!_disposed) notifyListeners();
  }

  List<ParsedCardPayment> _stored(SharedPreferences prefs) {
    try {
      final list = jsonDecode(prefs.getString(_pendingKey) ?? '[]');
      return list is List
          ? list.map(ParsedCardPayment.fromJson).nonNulls.toList()
          : [];
    } on FormatException {
      return [];
    }
  }

  Future<void> _persist(SharedPreferences prefs) =>
      prefs.setString(_pendingKey, jsonEncode(pending));

  /// 저장했거나 무시한 알림을 대기 목록에서 지운다.
  Future<void> remove(ParsedCardPayment payment) async {
    pending = pending.where((p) => !identical(p, payment)).toList();
    if (!_disposed) notifyListeners();
    await _persist(await SharedPreferences.getInstance());
  }

  Future<void> dismissIntro() async {
    introDismissed = true;
    if (!_disposed) notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_introKey, true);
  }

  /// 시스템의 "알림 접근" 설정 화면을 연다.
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
