import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 숫자를 입력하는 즉시 천 단위 콤마를 찍어 준다. (1200000 -> 1,200,000)
/// [decimals] 가 0 보다 크면 소수점도 받는다. (12.5 -> 12.5, 1234.56 -> 1,234.56)
///
/// 단순히 문자열만 다시 포맷하면 콤마가 끼어드는 순간 커서가 맨 뒤로 튀기 때문에,
/// "커서 앞에 숫자(와 소수점)가 몇 개 있었는지" 를 세서 포맷된 문자열에서
/// 같은 위치를 다시 찾는다.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.decimals = 0, this.maxDigits = 12});

  /// 소수점 아래 최대 자릿수. 0 이면 소수점 입력을 무시한다.
  final int decimals;

  /// 정수부 최대 자릿수. 넘어가면 입력을 그냥 무시한다.
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final caret = newValue.selection.end.clamp(0, raw.length);

    // 숫자와 (허용되면) 첫 소수점만 남긴다. 커서 앞에 남은 글자 수도 같이 센다.
    final kept = StringBuffer();
    var seenDot = false;
    var keptBeforeCaret = 0;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final code = ch.codeUnitAt(0);
      final isDigit = code >= 0x30 && code <= 0x39; // '0'..'9'
      final isDot = ch == '.' && decimals > 0 && !seenDot;
      if (!isDigit && !isDot) continue;
      if (isDot) seenDot = true;
      kept.write(ch);
      if (i < caret) keptBeforeCaret++;
    }
    final s = kept.toString();
    if (s.isEmpty) return const TextEditingValue();

    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final frac = dot < 0 ? null : s.substring(dot + 1);
    if (intPart.length > maxDigits) return oldValue;
    if (frac != null && frac.length > decimals) return oldValue;

    // 선행 0 제거 ("007" -> "7"). ".5" 처럼 정수부가 비면 "0" 을 채운다.
    var trimmed = intPart.replaceFirst(RegExp(r'^0+(?=.)'), '');
    if (trimmed.isEmpty) trimmed = '0';
    // 잘려 나간(또는 채워 넣은) 만큼 커서 앞 글자 수를 보정
    keptBeforeCaret -= intPart.length - trimmed.length;
    final formatted =
        '${formatNumber(int.parse(trimmed))}${frac == null ? '' : '.$frac'}';
    final target = keptBeforeCaret.clamp(0, formatted.replaceAll(',', '').length);

    // 포맷된 문자열을 훑으면서 콤마가 아닌 글자를 target 개 지난 지점이 새 커서.
    var seen = 0;
    var offset = formatted.length;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == target) {
        offset = i;
        break;
      }
      if (formatted[i] != ',') seen++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// 원화 예산 입력용 (소수점 없음).
class WonInputFormatter extends AmountInputFormatter {
  const WonInputFormatter() : super(decimals: 0);
}

/// "1,234.5" -> 1234.5  (비었거나 이상하면 0)
double parseAmount(String text) =>
    double.tryParse(text.replaceAll(',', '')) ?? 0;
