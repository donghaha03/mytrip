import 'package:intl/intl.dart';

/// 1234567 -> "1,234,567원"
String won(num v) => '${NumberFormat('#,##0').format(v.round())}원';

/// 현지 금액 표시: 1234.5 -> "1,234.5"
String localAmt(num v) => NumberFormat('#,##0.##').format(v);

/// "10.03 14:20"
String dateShort(DateTime d) => DateFormat('MM.dd HH:mm').format(d);

/// "2026.10.03"
String dayOnly(DateTime d) => DateFormat('yyyy.MM.dd').format(d);
