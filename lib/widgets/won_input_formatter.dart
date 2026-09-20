import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 숫자를 입력하는 즉시 천 단위 콤마를 찍어 준다. (1200000 -> 1,200,000)
///
/// 단순히 문자열만 다시 포맷하면 콤마가 끼어드는 순간 커서가 맨 뒤로 튀기 때문에,
/// "커서 앞에 숫자가 몇 개 있었는지" 를 세서 포맷된 문자열에서 같은 위치를 다시 찾는다.
class WonInputFormatter extends TextInputFormatter {
  const WonInputFormatter({this.maxDigits = 12});

  /// 예산에 12자리(999,999,999,999) 넘게 넣을 일은 없다.
  /// 넘어가면 입력을 그냥 무시한다.
  final int maxDigits;

  static final _nonDigit = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > maxDigits) return oldValue;

    // 선행 0 제거 ("007" -> "7"). 전부 0 이면 "0" 하나는 남긴다.
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=.)'), '');
    final formatted = formatNumber(int.parse(trimmed));

    // 커서 앞의 숫자 개수. 선행 0 이 잘린 만큼은 빼 준다.
    final caret = newValue.selection.end.clamp(0, newValue.text.length);
    final droppedZeros = digits.length - trimmed.length;
    var digitsBeforeCaret =
        newValue.text.substring(0, caret).replaceAll(_nonDigit, '').length -
            droppedZeros;
    digitsBeforeCaret = digitsBeforeCaret.clamp(0, trimmed.length);

    // 포맷된 문자열을 훑으면서 숫자를 그만큼 지난 지점이 새 커서 위치.
    var seen = 0;
    var offset = formatted.length;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == digitsBeforeCaret) {
        offset = i;
        break;
      }
      if (formatted[i] != ',') seen++;
    }
    if (seen == digitsBeforeCaret && offset == formatted.length) {
      offset = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
