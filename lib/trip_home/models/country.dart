import '../theme/app_theme.dart';

const kWonSymbol = '₩';

/// 여행 국가·통화 표시 정보. 실제 환산은 공통 RateApi만 사용한다.
class Country {
  const Country({
    required this.flag,
    required this.name,
    required this.currency,
    required this.symbol,
    required this.unitLabel,
    required this.unitAmount,
    required this.krwPerUnit,
  });

  final String flag;
  final String name;
  final String currency; // USD, JPY ...
  final String symbol; // $, ¥ ...
  final String unitLabel; // 달러, 엔 ...
  final int unitAmount; // 1, 100, 1000
  final double krwPerUnit; // 테스트용 예시 API 응답에만 사용. 화면 환산에는 사용하지 않는다.

  /// "¥1,200"
  String formatForeign(num amount) =>
      '$symbol${formatNumber(amount.truncate())}';
}

/// 통화 코드("JPY") -> Country. Firestore 에는 코드만 저장한다.
Country? countryByCode(String code) {
  for (final c in kPrimaryCountries) {
    if (c.currency == code) return c;
  }
  for (final c in kMoreCountries) {
    if (c.currency == code) return c;
  }
  return null;
}

/// 02 화면에 기본 노출되는 7개국 (마지막 칸은 "더보기")
const kPrimaryCountries = <Country>[
  Country(
      flag: '🇺🇸',
      name: '미국',
      currency: 'USD',
      symbol: '\$',
      unitLabel: '달러',
      unitAmount: 1,
      krwPerUnit: 1350),
  Country(
      flag: '🇯🇵',
      name: '일본',
      currency: 'JPY',
      symbol: '¥',
      unitLabel: '엔',
      unitAmount: 100,
      krwPerUnit: 950),
  Country(
      flag: '🇪🇺',
      name: '유럽',
      currency: 'EUR',
      symbol: '€',
      unitLabel: '유로',
      unitAmount: 1,
      krwPerUnit: 1460),
  Country(
      flag: '🇨🇳',
      name: '중국',
      currency: 'CNY',
      symbol: '¥',
      unitLabel: '위안',
      unitAmount: 1,
      krwPerUnit: 188),
  Country(
      flag: '🇻🇳',
      name: '베트남',
      currency: 'VND',
      symbol: '₫',
      unitLabel: '동',
      unitAmount: 1000,
      krwPerUnit: 55),
  Country(
      flag: '🇹🇭',
      name: '태국',
      currency: 'THB',
      symbol: '฿',
      unitLabel: '바트',
      unitAmount: 1,
      krwPerUnit: 39),
  Country(
      flag: '🇵🇭',
      name: '필리핀',
      currency: 'PHP',
      symbol: '₱',
      unitLabel: '페소',
      unitAmount: 1,
      krwPerUnit: 24),
];

/// 04 "국가 더보기" 시트에 들어가는 12개국
const kMoreCountries = <Country>[
  Country(
      flag: '🇭🇰',
      name: '홍콩',
      currency: 'HKD',
      symbol: 'HK\$',
      unitLabel: '홍콩달러',
      unitAmount: 1,
      krwPerUnit: 173),
  Country(
      flag: '🇸🇬',
      name: '싱가포르',
      currency: 'SGD',
      symbol: 'S\$',
      unitLabel: '싱가포르달러',
      unitAmount: 1,
      krwPerUnit: 1010),
  Country(
      flag: '🇮🇩',
      name: '인도네시아',
      currency: 'IDR',
      symbol: 'Rp',
      unitLabel: '루피아',
      unitAmount: 1000,
      krwPerUnit: 85),
  Country(
      flag: '🇲🇾',
      name: '말레이시아',
      currency: 'MYR',
      symbol: 'RM',
      unitLabel: '링깃',
      unitAmount: 1,
      krwPerUnit: 305),
  Country(
      flag: '🇦🇺',
      name: '호주',
      currency: 'AUD',
      symbol: 'A\$',
      unitLabel: '호주달러',
      unitAmount: 1,
      krwPerUnit: 890),
  Country(
      flag: '🇬🇧',
      name: '영국',
      currency: 'GBP',
      symbol: '£',
      unitLabel: '파운드',
      unitAmount: 1,
      krwPerUnit: 1720),
  Country(
      flag: '🇨🇭',
      name: '스위스',
      currency: 'CHF',
      symbol: 'CHF',
      unitLabel: '프랑',
      unitAmount: 1,
      krwPerUnit: 1560),
  Country(
      flag: '🇮🇳',
      name: '인도',
      currency: 'INR',
      symbol: '₹',
      unitLabel: '루피',
      unitAmount: 1,
      krwPerUnit: 16),
  Country(
      flag: '🇨🇦',
      name: '캐나다',
      currency: 'CAD',
      symbol: 'C\$',
      unitLabel: '캐나다달러',
      unitAmount: 1,
      krwPerUnit: 985),
  Country(
      flag: '🇳🇿',
      name: '뉴질랜드',
      currency: 'NZD',
      symbol: 'NZ\$',
      unitLabel: '뉴질랜드달러',
      unitAmount: 1,
      krwPerUnit: 820),
  Country(
      flag: '🇹🇼',
      name: '대만',
      currency: 'TWD',
      symbol: 'NT\$',
      unitLabel: '대만달러',
      unitAmount: 1,
      krwPerUnit: 42),
  Country(
      flag: '🇲🇴',
      name: '마카오',
      currency: 'MOP',
      symbol: 'MOP\$',
      unitLabel: '파타카',
      unitAmount: 1,
      krwPerUnit: 168),
];
